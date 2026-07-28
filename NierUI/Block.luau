--!nocheck
--=============================================================================
-- Block -- деление вкладки на ячейки 2x2
--=============================================================================
--
--     tab:Block("Left", "Up", "COMBAT")   левая верхняя клетка, с заголовком
--     tab:Block("Right")                  вся правая полоса
--     tab:Block("Down")                   вся нижняя полоса
--     tab:Block()                         единственный, на всю страницу
--
-- Порядок аргументов свободный: ось узнаётся по самому слову, а не по месту.
-- Left/Right -- ось X, Up/Down -- ось Y, любая другая строка -- заголовок.
-- Поэтому tab:Block("Up") работает так же, как tab:Block(nil, "Up").
--
-- Блок -- такой же КОНТЕЙНЕР, что и вкладка (см. Window.containerIndex): у него
-- есть .page, .rows и .window, и виджеты не отличают его от вкладки. Ни один
-- виджет ради блоков править не пришлось.
--
--
--=============================================================================
-- ПРАВИЛО РАЗМЕЩЕНИЯ
--=============================================================================
--
-- Разрешение идёт ПО КОНКРЕТНОСТИ, а не по порядку объявления. Блок,
-- объявленный двухсотым, получит ровно то же, что получил бы первым.
--
--   1. Кто назвал ОБЕ оси -- получает ровно свою клетку. Только её: блок
--      Left+Up никогда не претендует на Left+Down.
--   2. Кто назвал ОДНУ ось -- берёт всю свою полосу, но только из того, что
--      осталось свободным после шага 1. Заявивший права на конкретную клетку
--      её и получает, не заявлявший -- уступает.
--   3. Кто не назвал ничего -- занимает страницу целиком, но только если он
--      один. Вместе с любым другим блоком -- ошибка.
--
-- ЯВНАЯ ОШИБКА, А НЕ РАЗМЕЩЕНИЕ НАУГАД, во всех спорных случаях:
--   * две клетки с одинаковыми полными координатами;
--   * два односторонних на одной и той же стороне (Up и Up);
--   * два односторонних на РАЗНЫХ осях, спорящих за одну свободную клетку
--     (Left и Up): прав на неё не заявлял ни один, отдавать некому;
--   * односторонний, которому не осталось ни одной свободной клетки;
--   * безпараметрный рядом с кем угодно.

local THEME = NierUI.Theme
local U = NierUI.util
local Tab = NierUI.TabClass

local X_WORDS = { left = "Left", right = "Right" }
local Y_WORDS = { up = "Up", down = "Down" }

local Block = {}
Block.__index = NierUI.containerIndex(Block)

--=============================================================================
-- Разбор аргументов
--=============================================================================

local function parseArgs(...)
    local x, y, title, extra
    for index = 1, select("#", ...) do
        local arg = select(index, ...)
        if type(arg) == "table" then
            extra = arg
        elseif type(arg) == "string" then
            local word = arg:lower()
            if X_WORDS[word] then
                if x then
                    error(("[NierUI] Block: ось X задана дважды (%s и %s)")
                        :format(x, X_WORDS[word]), 3)
                end
                x = X_WORDS[word]
            elseif Y_WORDS[word] then
                if y then
                    error(("[NierUI] Block: ось Y задана дважды (%s и %s)")
                        :format(y, Y_WORDS[word]), 3)
                end
                y = Y_WORDS[word]
            elseif title == nil then
                title = arg
            end
        end
    end
    return x, y, title, extra
end

local function describe(block)
    local parts = {}
    if block.x then parts[#parts + 1] = block.x end
    if block.y then parts[#parts + 1] = block.y end
    if #parts == 0 then parts[1] = "без параметров" end
    local name = block.title and (" «" .. block.title .. "»") or ""
    return table.concat(parts, "+") .. name
end

--=============================================================================
-- Раскладка
--=============================================================================

local function cellKey(x, y) return x .. "|" .. y end

local function bandOf(block)
    if block.x and not block.y then
        return { cellKey(block.x, "Up"), cellKey(block.x, "Down") }
    end
    return { cellKey("Left", block.y), cellKey("Right", block.y) }
end

-- Доля и отступ по одной оси. Две колонки с зазором G между ними: каждая
-- шириной (W-G)/2, то есть 0.5 доли минус половина зазора.
local function span(index, cells, gap)
    if cells == 2 then
        return UDim.new(0, 0), UDim.new(1, 0)
    end
    if index == 0 then
        return UDim.new(0, 0), UDim.new(0.5, -gap / 2)
    end
    return UDim.new(0.5, gap / 2), UDim.new(0.5, -gap / 2)
end

local function place(block, col, row, wide, tall)
    local gap = THEME.BlockGap
    local px, pw = span(col, wide, gap)
    local py, ph = span(row, tall, gap)
    block.frame.Position = UDim2.new(px.Scale, px.Offset, py.Scale, py.Offset)
    block.frame.Size = UDim2.new(pw.Scale, pw.Offset, ph.Scale, ph.Offset)
end

local function rectOf(cells)
    local minC, maxC, minR, maxR = 2, -1, 2, -1
    for _, key in ipairs(cells) do
        local cx, cy = key:match("^(%a+)|(%a+)$")
        local col = cx == "Left" and 0 or 1
        local rowIndex = cy == "Up" and 0 or 1
        minC, maxC = math.min(minC, col), math.max(maxC, col)
        minR, maxR = math.min(minR, rowIndex), math.max(maxR, rowIndex)
    end
    return minC, minR, maxC - minC + 1, maxR - minR + 1
end

--=============================================================================
-- РАЗДЕЛИТЕЛИ РИСУЮТСЯ ПО ГРАНИЦАМ, А НЕ ПО ВСЕЙ СЕТКЕ
--=============================================================================
--
-- Сначала линии были сплошные: есть где-то деление по X -- вертикаль во всю
-- высоту, есть по Y -- горизонталь во всю ширину. При раскладке Left+Up плюс
-- Right это резало правый блок пополам: он занимает обе правые клетки, границы
-- внутри него нет, а линия через него всё равно шла.
--
-- Линия существует там, где встречаются ДВА РАЗНЫХ блока. Поэтому вертикаль
-- считается отдельно для верхней и нижней строки, горизонталь -- отдельно для
-- левой и правой колонки. Пустая клетка линии не даёт: отделять блок от
-- пустоты незачем.

-- РАЗДЕЛИТЕЛИ СТАВЯТСЯ В ЦЕЛЫХ ПИКСЕЛЯХ, А НЕ ДОЛЯМИ.
--
-- Доля 0.5 на нечётной стороне даёт половину пикселя: при сетке 479x374 центр
-- по Y приходился на 186.5, и однопиксельная линия размазывалась между двумя
-- рядами -- горизонталь выглядела заметно толще и мягче вертикали. Замеры при
-- этом показывали честную единицу у обеих.
--
-- Поэтому положение считается от абсолютного размера сетки с округлением вниз,
-- и пересчитывается при её изменении. Обе половины каждой оси упираются в одну
-- и ту же целую координату центра, так что узел смыкается точно.

local function layoutSeparators(tab)
    local size = tab.grid.AbsoluteSize
    local w, h = math.floor(size.X), math.floor(size.Y)
    local cx, cy = math.floor(w / 2), math.floor(h / 2)

    for _, spec in ipairs(tab.separators) do
        if spec.vertical then
            local from = spec.second and cy or 0
            local to = spec.second and h or cy
            spec.frame.Position = UDim2.fromOffset(cx, from)
            spec.frame.Size = UDim2.fromOffset(1, to - from)
        else
            local from = spec.second and cx or 0
            local to = spec.second and w or cx
            spec.frame.Position = UDim2.fromOffset(from, cy)
            spec.frame.Size = UDim2.fromOffset(to - from, 1)
        end
    end
end

local function edge(tab, vertical, second)
    tab.separators[#tab.separators + 1] = {
        vertical = vertical, second = second,
        frame = U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
            BackgroundTransparency = 0.65, ZIndex = 5,
        }, tab.grid),
    }
end

local ROWS = { "Up", "Down" }
local COLS = { "Left", "Right" }

-- ОТРЕЗКИ ИДУТ ОТ КРАЯ СЕТКИ ДО ЕЁ ЦЕНТРА, а не до края клетки.
--
-- Первая версия обрывала их по границе клетки, и линии не смыкались: горизонталь
-- заканчивалась на 236, вертикаль стояла на 240 -- четыре пикселя зазора между
-- ними, ровно в узле. Половинки одной оси при этом тоже не сходились.
--
-- Все разделители лежат на двух центральных осях, поэтому соседние по одной оси
-- сливаются в сплошную линию, а перпендикулярные пересекаются в центре. Узел
-- замкнут по построению, а не подгонкой.
local function drawSeparators(tab, final)
    for _, spec in ipairs(tab.separators) do
        pcall(function() spec.frame:Destroy() end)
    end
    table.clear(tab.separators)
    if not THEME.BlockSeparators then return end

    -- вертикальные: по строке, если слева и справа разные блоки
    for index, yWord in ipairs(ROWS) do
        local left = final[cellKey("Left", yWord)]
        local right = final[cellKey("Right", yWord)]
        if left and right and left ~= right then
            edge(tab, true, index == 2)
        end
    end

    -- горизонтальные: по колонке, если сверху и снизу разные блоки
    for index, xWord in ipairs(COLS) do
        local up = final[cellKey(xWord, "Up")]
        local down = final[cellKey(xWord, "Down")]
        if up and down and up ~= down then
            edge(tab, false, index == 2)
        end
    end

    layoutSeparators(tab)
end

local function resolve(tab)
    local blocks = tab.blocks
    if #blocks == 0 then return end

    --== без параметров ======================================================

    for _, block in ipairs(blocks) do
        if not block.x and not block.y then
            if #blocks > 1 then
                error(("[NierUI] блок без параметров занимает всю страницу и не "
                    .. "уживается с другими; рядом объявлено ещё %d")
                    :format(#blocks - 1), 0)
            end
            place(block, 0, 0, 2, 2)
            drawSeparators(tab, {})
            return
        end
    end

    --== шаг 1: полные координаты ============================================

    local owner = {}
    for _, block in ipairs(blocks) do
        if block.x and block.y then
            local key = cellKey(block.x, block.y)
            if owner[key] then
                error(("[NierUI] две клетки с одинаковыми координатами: %s и %s")
                    :format(describe(owner[key]), describe(block)), 0)
            end
            owner[key] = block
            block.cells = { key }
        end
    end

    --== шаг 2: одна ось =====================================================
    --
    -- Свободные клетки считаются ПОСЛЕ шага 1 и независимо от того, в каком
    -- порядке блоки объявлены. Спор двух односторонних за одну и ту же
    -- свободную клетку разрешать нечем -- прав на неё не заявлял ни один.

    local wants = {}
    for _, block in ipairs(blocks) do
        if (block.x and not block.y) or (block.y and not block.x) then
            local free = {}
            for _, key in ipairs(bandOf(block)) do
                if not owner[key] then
                    free[#free + 1] = key
                    local other = wants[key]
                    if other then
                        error(("[NierUI] %s и %s спорят за свободную клетку %s; "
                            .. "уточните вторую ось хотя бы одному")
                            :format(describe(other), describe(block), key), 0)
                    end
                    wants[key] = block
                end
            end
            if #free == 0 then
                error(("[NierUI] %s: свободных клеток в его полосе не осталось")
                    :format(describe(block)), 0)
            end
            block.cells = free
        end
    end

    --== геометрия ===========================================================

    -- Итоговая карта «клетка -> хозяин»: полные блоки из шага 1 плюс то, что
    -- разобрали односторонние. По ней и считаются границы.
    local final = {}
    for key, block in pairs(owner) do final[key] = block end
    for key, block in pairs(wants) do final[key] = block end

    for _, block in ipairs(blocks) do
        place(block, rectOf(block.cells))
    end
    drawSeparators(tab, final)
end

-- Геометрия считается ОТЛОЖЕННО: односторонний блок обязан ужаться под полный
-- независимо от того, кто объявлен раньше, а значит решать можно только когда
-- объявлены все.
local function schedule(tab)
    if tab.layoutQueued then return end
    tab.layoutQueued = true
    task.defer(function()
        tab.layoutQueued = false
        resolve(tab)
    end)
end

--=============================================================================
-- Сетка вкладки
--=============================================================================

local function ensureGrid(tab)
    if tab.grid then return tab.grid end

    -- Строки и блоки в одной вкладке несовместимы: страница раскладывает детей
    -- списком сверху вниз, и сетка встала бы в этот же поток, ниже строк, с
    -- непредсказуемой высотой. Лучше сказать об этом сразу.
    if tab.rows > 0 then
        error("[NierUI] во вкладке уже есть строки; блоки и строки в одной "
            .. "вкладке несовместимы -- положите строки внутрь блока", 3)
    end

    -- Страница вкладки раскладывает строки списком сверху вниз и растит
    -- полотно под них. Для блоков это не нужно: они позиционируются сами, а
    -- прокрутка живёт внутри каждого. Автополотно выключаем, иначе сетка
    -- высотой в долю от страницы и растущее под неё полотно тянули бы друг
    -- друга по кругу.
    tab.page.AutomaticCanvasSize = Enum.AutomaticSize.None
    tab.page.CanvasSize = UDim2.new()

    tab.grid = U.new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
    }, tab.page)
    tab.blocks = {}

    -- Разделители стоят в целых пикселях, значит зависят от размера сетки:
    -- меняется окно -- пересчитываем, иначе линии разъедутся от центра.
    table.insert(tab.window.conns,
        tab.grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            layoutSeparators(tab)
        end))

    return tab.grid
end

--=============================================================================

function Tab:Block(...)
    local x, y, title, extra = parseArgs(...)

    -- Нормализуем СРАЗУ, до всех сравнений. В блоке отсутствие оси хранится
    -- как false, и сравнение сырого nil с сохранённым false ложно -- на этом
    -- молча не срабатывала проверка «две одинаковые полосы»: Up и Up
    -- проходили без ошибки.
    x, y, title = x or false, y or false, title or false

    local grid = ensureGrid(self)

    --== проверки, которые можно сделать сразу ===============================
    --
    -- Здесь ловится всё, что не зависит от ещё не объявленных блоков: так
    -- ошибка указывает на нужную строку. Спор за свободную клетку сюда не
    -- относится -- он зависит от полных блоков, которые могут появиться позже.

    for _, other in ipairs(self.blocks) do
        if (not other.x and not other.y) or (not x and not y) then
            error("[NierUI] блок без параметров занимает всю страницу и не "
                .. "уживается с другими", 2)
        end
        if x and y and other.x == x and other.y == y then
            error(("[NierUI] клетка %s+%s уже занята"):format(x, y), 2)
        end
        if not (x and y) and not (other.x and other.y)
            and other.x == x and other.y == y then
            error(("[NierUI] две одинаковые полосы: %s"):format(describe(other)), 2)
        end
    end

    --== сам блок ============================================================

    -- Отсутствие оси -- false, а НЕ nil: диспетчер контейнера ругается на
    -- любое отсутствующее поле, и `if block.x then` обязано читать
    -- существующее значение.
    local block = setmetatable({
        window = self.window, rows = 0,
        x = x, y = y, title = title,
        cells = false,
    }, Block)

    block.frame = U.new("Frame", {
        BackgroundColor3 = THEME.BgSunk, BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 0), ClipsDescendants = true,
    }, grid)

    local top = 0
    if title then
        U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = title, TextColor3 = THEME.InkSoft, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(10, 5),
            Size = UDim2.new(1, -20, 0, 12), ZIndex = 2,
        }, block.frame)
        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
            BackgroundTransparency = 0.65,
            Position = UDim2.fromOffset(0, THEME.BlockTitleHeight),
            Size = UDim2.new(1, 0, 0, 1), ZIndex = 2,
        }, block.frame)
        top = THEME.BlockTitleHeight + 1
    end

    -- Своя прокрутка: содержимое длиннее ячейки не обрезается, а листается.
    -- Раскрытый список внутри блока тоже уезжает сюда, поэтому высота ячейки
    -- ему не помеха.
    block.page = U.new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, top),
        Size = UDim2.new(1, 0, 1, -top),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = THEME.Ink,
        ScrollBarImageTransparency = 0.4,
    }, block.frame)
    U.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, block.page)
    U.new("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6),
    }, block.page)

    table.insert(self.blocks, block)
    schedule(self)
    return block
end
