--!nocheck
-- NierUI. Собрано lib\build.ps1, правки вносить в lib\NierUI\.

local NierUI = {}

--============================ NierUI/Theme.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Theme -- палитра, шрифт, размеры
--=============================================================================
--
-- Получает общий NierUI параметром, см. build.ps1.
--
-- Меняется ДО создания окна: значения читаются в момент постройки элементов,
-- задним числом уже ничего не перекрасится.

-- Шрифт NieR -- квадратная антиква. Ближайшее из встроенного -- Merriweather:
-- Bodoni точнее по контрасту, но на четырнадцати пикселях его волосяные линии
-- рассыпаются. Кириллицы ни у того ни у другого нет, это осознанный размен --
-- нужна кириллица, ставь Enum.Font.RobotoMono.
--
-- Подбор идёт с откатом: если шрифта в клиенте нет, спускаемся по списку, а не
-- падаем с ошибкой.
local function pickFont(...)
    for _, name in ipairs({ ... }) do
        local ok, font = pcall(function() return Enum.Font[name] end)
        if ok and font then return font end
    end
    return Enum.Font.SourceSans
end

NierUI.Theme = {
    Bg       = Color3.fromRGB(207, 201, 176),   -- песочный
    BgSunk   = Color3.fromRGB(193, 187, 163),   -- утопленный: раскрытые блоки
    Ink      = Color3.fromRGB(69, 65, 56),      -- чернила
    InkSoft  = Color3.fromRGB(126, 120, 103),   -- второстепенный текст
    Disabled = Color3.fromRGB(163, 158, 140),   -- недоступное: бледнее второстепенного

    Font     = pickFont("Merriweather", "Bodoni", "Garamond", "SourceSans"),

    --== размеры окна ========================================================
    --
    -- Вынесены сюда, чтобы окно можно было менять одним числом, а не искать
    -- 560 и 420 по коду. Высота шапки, ширина колонки вкладок и высота нижней
    -- панели заданы в пикселях намеренно: они не должны расти вместе с окном,
    -- иначе на большом меню шапка становится вывеской.
    WindowWidth = 644,
    WindowHeight = 483,
    HeaderHeight = 52,
    TabColumnWidth = 140,
    HintHeight = 40,
    PopupTitleHeight = 22,

    RowHeight = 26,
    TextSize = 14,
    TitleSize = 20,

    --== раскладка строки ====================================================
    --
    -- Всё, что стоит в строке справа, задаётся ДОЛЯМИ ширины, а не пикселями.
    -- Раньше это были жёсткие отступы от правого края (значение -110, дорожка
    -- ползунка -218, образец цвета -108). При полной ширине страницы в 395
    -- пикселей они работали, но в половинной ячейке блока (~190) отступ в 218
    -- уходит за левый край, и дорожка легла бы поверх подписи.
    --
    -- Доли рассчитаны так, чтобы зоны не пересекались ни при 395, ни при 190:
    --     подпись   14 .. 40%
    --     дорожка   правым краем на 70%, шириной 22%
    --     значение  правым краем на -10 px, шириной 24%
    LabelFrac = 0.40,
    TrackRight = 0.70,
    TrackFrac = 0.22,
    ValueFrac = 0.24,

    -- Сколько пунктов списка показывать разом. Дальше он прокручивается, а не
    -- растёт: двадцать пять вариантов дали бы 650 пикселей при высоте панели
    -- в 420, и нижние ушли бы за её край.
    DropdownMax = 6,

    --== блоки ===============================================================
    --
    -- Подложка и собственная прокрутка у блока обязательны. Заголовок задаётся
    -- у каждого блока отдельно, разделительные линии -- флагом здесь: это
    -- решение про весь вид меню, а не про отдельную ячейку.
    BlockGap = 8,
    BlockTitleHeight = 20,
    BlockSeparators = false,

    --== поверхность =========================================================
    --
    -- Скан-линии и зерно живут в одной процедурной текстуре (см. Texture).
    -- ScanAlpha -- прозрачность линии, Grain -- разброс альфы зерна между
    -- линиями в единицах 0..255. Ноль в обоих даёт чистую заливку.
    Scanlines = true,
    ScanStep = 4,
    ScanAlpha = 0.9,
    Grain = 7,

    -- Миллиметровка: в оригинале фон разлинован очень бледной мелкой сеткой,
    -- из-за неё он читается как бумага, а не как заливка. Альфа в единицах
    -- 0..255, ноль убирает сетку.
    GridStep = 8,
    GridAlpha = 5,

    -- Полосы-перфорации сверху и снизу окна.
    Band = true,
    BandHeight = 12,

    --== уведомления =========================================================
    NotifyWidth = 240,
    NotifyDuration = 4,
}

end)(NierUI)

--============================ NierUI/Util.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Util -- мелочи, которыми пользуются все части
--=============================================================================

local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local THEME = NierUI.Theme
local U = {}
NierUI.util = U

function U.new(class, props, parent)
    local inst = Instance.new(class)
    for key, value in pairs(props) do
        inst[key] = value
    end
    if parent then inst.Parent = parent end
    return inst
end

function U.randomName()
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local out = {}
    for _ = 1, 16 do
        local i = math.random(1, #chars)
        out[#out + 1] = chars:sub(i, i)
    end
    return table.concat(out)
end

-- Родитель GUI: CoreGui сервер не видит. Если исполнитель не даёт в него
-- писать, откатываемся в PlayerGui -- лучше видимое меню, чем никакого.
function U.guiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local ok = pcall(function() return CoreGui.Name end)
    if ok then return CoreGui end
    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
function U.tween(inst, props)
    TweenService:Create(inst, TWEEN, props):Play()
end

function U.stroke(parent, thickness, color, transparency)
    return U.new("UIStroke", {
        Thickness = thickness or 1,
        Color = color or THEME.Ink,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

-- Уголковые скобки по краям панели -- та самая рамка из оригинала.
function U.corners(parent, size, thick)
    size, thick = size or 10, thick or 2
    local spots = {
        { UDim2.fromScale(0, 0), Vector2.new(0, 0) },
        { UDim2.fromScale(1, 0), Vector2.new(1, 0) },
        { UDim2.fromScale(0, 1), Vector2.new(0, 1) },
        { UDim2.fromScale(1, 1), Vector2.new(1, 1) },
    }
    for _, spot in ipairs(spots) do
        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
            Position = spot[1], AnchorPoint = spot[2],
            Size = UDim2.fromOffset(size, thick), ZIndex = 20,
        }, parent)
        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
            Position = spot[1], AnchorPoint = spot[2],
            Size = UDim2.fromOffset(thick, size), ZIndex = 20,
        }, parent)
    end
end

-- Скан-линии. Строятся ОДИН раз и больше не трогаются: это статика, а не
-- анимация. Active = false обязателен -- иначе накрыло бы собой все кнопки.
function U.scanlines(parent, height)
    if not THEME.Scanlines then return end
    local holder = U.new("Frame", {
        BackgroundTransparency = 1, Active = false,
        Size = UDim2.fromScale(1, 1), ZIndex = 15,
        ClipsDescendants = true,
    }, parent)

    for y = 0, height, THEME.ScanStep do
        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
            BackgroundTransparency = THEME.ScanAlpha,
            Position = UDim2.fromOffset(0, y),
            Size = UDim2.new(1, 0, 0, 1), ZIndex = 15,
        }, holder)
    end
    return holder
end

-- Доля вдоль объекта по координате мыши: пригодится и ползунку, и палитре.
function U.alongX(inst, x)
    return math.clamp((x - inst.AbsolutePosition.X) / math.max(inst.AbsoluteSize.X, 1), 0, 1)
end

function U.alongY(inst, y)
    return math.clamp((y - inst.AbsolutePosition.Y) / math.max(inst.AbsoluteSize.Y, 1), 0, 1)
end

-- Попадает ли точка в прямоугольник элемента. Нужно там, где событие щелчка
-- само по себе не говорит, где он случился: MouseButton1Click координат не
-- несёт, а отличать «нажали по строке» от «нажали внутри раскрытой панели»
-- как-то надо.
function U.inside(frame, position)
    local p, s = frame.AbsolutePosition, frame.AbsoluteSize
    return position.X >= p.X and position.X <= p.X + s.X
       and position.Y >= p.Y and position.Y <= p.Y + s.Y
end

function U.hex(color)
    return ("#%02X%02X%02X"):format(
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5))
end

--=============================================================================
-- ПОИСК: НЕ ОТБОР, А РАНЖИРОВАНИЕ
--=============================================================================
--
-- Первая версия была обычным поиском подстроки: совпадает где угодно внутри
-- слова -- показываем. Формально верно, а на деле странно: на «ni» выпадали
-- DENNIS, UNICORN и NIGEL вперемешку, потому что все три подстроку содержат.
-- Плохо было не то, что находилось лишнее, а то, что НИЧЕГО НЕ БЫЛО УПОРЯДОЧЕНО
-- -- совпадение в начале строки стояло наравне с совпадением в середине слова.
--
-- Поэтому не отбор, а оценка. Возвращает разряд и позицию:
--
--   0  строка целиком начинается с запроса   NI -> NIGEL
--   1  с запроса начинается какое-то слово   WO -> DENNIS / WOLF
--   2  подстрока где угодно                  NI -> DENNIS
--   3  подпоследовательность, буквы по порядку но не подряд   dnw -> DENNIS / WOLF
--
-- Разряд 3 по умолчанию выключен: он находит слишком многое и удивляет сильнее,
-- чем помогает. Включается режимом "fuzzy".
--
-- nil означает «не подходит вовсе».

function U.matchScore(text, query)
    if query == "" then return 0, 1 end

    local haystack, needle = tostring(text):lower(), tostring(query):lower()
    local length = #needle

    if haystack:sub(1, length) == needle then return 0, 1 end

    -- начало любого слова: границей считается всё, что не буква и не цифра
    local pos = 1
    while true do
        local from, to = haystack:find("%w+", pos)
        if not from then break end
        if haystack:sub(from, from + length - 1) == needle then return 1, from end
        pos = to + 1
    end

    local at = haystack:find(needle, 1, true)
    if at then return 2, at end

    local cursor, first = 1, nil
    for index = 1, length do
        local found = haystack:find(needle:sub(index, index), cursor, true)
        if not found then return nil end
        first = first or found
        cursor = found + 1
    end
    return 3, first or 1
end

-- Разбор жил в двух местах сразу: в палитре и в кодеке конфига. Две копии
-- одного разбора -- это две разные трактовки короткой записи через месяц.
--
-- Принимаем #RRGGBB, RRGGBB и #RGB: короткая форма встречается в чужих
-- конфигах, и разворачивать её руками -- лишний повод ошибиться.
function U.fromHex(text)
    local hex = tostring(text):gsub("#", "")
    if #hex == 3 then
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
    end
    if #hex ~= 6 then return nil end

    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return Color3.fromRGB(r, g, b)
end

end)(NierUI)

--============================ NierUI/Texture.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Texture -- процедурные текстуры вместо декораций из фреймов
--=============================================================================
--
-- ЗАЧЕМ
--
-- Скан-линии рисовались фреймами: по одному на каждую линию. Замер на живом
-- меню -- 122 фрейма из 856 в иерархии, то есть СЕДЬМАЯ ЧАСТЬ всего меню
-- уходила на декорацию, нарисованную самым дорогим из возможных способов. И
-- потолок там жёсткий: зерно, дизеринг и любой попиксельный узор фреймами не
-- сделать в принципе -- это тысячи инстансов на панель.
--
-- EditableImage позволяет собрать текстуру попиксельно прямо в рантайме и
-- положить её ОДНИМ ImageLabel с тайлингом. Замерено в этом клиенте:
--     CreateEditableImage  есть
--     WritePixelsBuffer    есть   (старого WritePixels уже нет)
--     Content.fromObject   есть
--     ImageLabel.ImageContent есть
--
-- Ассет при этом не нужен: ничего не грузится, не модерируется и не может
-- однажды перестать открываться. Ровно тот же довод, по которому палитра
-- собрана из градиентов, а не из картинки.
--
--
-- ПОЧЕМУ ТАЙЛ, А НЕ ТЕКСТУРА ПО РАЗМЕРУ ОКНА
--
-- Текстура на всё окно -- это 644x483 пикселя, 1.2 МБ буфера, и пересборка при
-- каждом изменении размера. Тайл 64x64 -- 16 КБ, строится один раз и повторяется
-- движком. Шаг скан-линий (4) делит 64 нацело, поэтому стык невидим.
--
--
-- ЕСЛИ EditableImage НЕДОСТУПЕН
--
-- В другом клиенте его может не быть. Тогда откатываемся на прежние фреймы --
-- меню должно выглядеть хуже, но не ломаться.

local AssetService = game:GetService("AssetService")

local THEME = NierUI.Theme
local U = NierUI.util

local T = {}
NierUI.texture = T

local TILE = 64

--=============================================================================
-- Сборка тайла
--=============================================================================
--
-- Один проход по пикселям. Цвет всюду чернильный, различие только в альфе:
-- на строках скан-линий она заметная, между ними -- случайное зерно в
-- несколько единиц. Именно зерно даёт бумажность, из-за которой песочный фон
-- в оригинале не выглядит заливкой.

local function inkBytes()
    local ink = THEME.Ink
    return math.floor(ink.R * 255 + 0.5),
           math.floor(ink.G * 255 + 0.5),
           math.floor(ink.B * 255 + 0.5)
end

-- Три слоя в один проход, по убыванию заметности: скан-линии, миллиметровка,
-- зерно. Порядок проверок и есть приоритет -- на строке скан-линии сетку не
-- рисуем, иначе она бы её только грязнила.
local function buildTile()
    local buf = buffer.create(TILE * TILE * 4)
    local r, g, b = inkBytes()

    -- В теме прозрачность, в текстуре альфа -- величины обратные.
    local lineAlpha = math.floor((1 - THEME.ScanAlpha) * 255 + 0.5)
    local grain = THEME.Grain
    local step = math.max(1, THEME.ScanStep)
    local gridStep = THEME.GridStep
    local gridAlpha = THEME.GridAlpha

    for y = 0, TILE - 1 do
        local onLine = THEME.Scanlines and (y % step) == 0
        local onGridRow = gridStep > 0 and (y % gridStep) == 0
        local rowBase = y * TILE * 4

        for x = 0, TILE - 1 do
            local i = rowBase + x * 4
            local alpha
            if onLine then
                alpha = lineAlpha
            elseif onGridRow or (gridStep > 0 and (x % gridStep) == 0) then
                alpha = gridAlpha
            else
                alpha = grain > 0 and math.random(0, grain) or 0
            end
            buffer.writeu8(buf, i, r)
            buffer.writeu8(buf, i + 1, g)
            buffer.writeu8(buf, i + 2, b)
            buffer.writeu8(buf, i + 3, alpha)
        end
    end

    return buf
end

--=============================================================================
-- Полоса-перфорация
--=============================================================================
--
-- МОТИВ: штрих ВВЕРХУ, за ним три точки «галочкой» -- крайние выше, средняя
-- ниже. Это и есть весь период, дальше он просто повторяется.
--
-- Первая версия была снята с общих кадров на глаз и оказалась не тем: там были
-- разрозненные точки на двух уровнях с редким штрихом, без «галочки» и без
-- привязки штриха к верху. Рисунок читается только по крупному плану.
--
-- Таблица прямоугольников, а не процедура: подправить мотив -- значит
-- поправить числа. Координаты внутри тайла: x, y, ширина, высота.

-- СИММЕТРИЯ ЗДЕСЬ -- ИНВАРИАНТ, А НЕ ПОЖЕЛАНИЕ. Держатся три равенства:
--
--   нижняя точка стоит РОВНО посередине между верхними
--       левая 14..15 (центр 14.5), нижняя 18..19 (18.5),
--       правая 22..23 (22.5) -- шаг 4 между всеми тремя;
--   зазоры между точками одинаковые -- по два пикселя (15|18 и 19|22);
--   шаг между штрихом и треугольником равен шагу до следующего мотива
--       центр штриха 5, центр треугольника 18.5, следующий штрих 33 --
--       13.5 и 14.5 от центра к центру.
--
-- ШТРИХ ЦЕНТРИРОВАН В СВОЁМ МЕСТЕ, А НЕ ПРИЖАТ К КРАЮ. Поэтому его длину можно
-- менять, не сдвигая ничего остального: укоротили вдвое (11 -> 5) -- центр как
-- стоял на 5, так и остался, а освободившееся место само разошлось поровну
-- влево и вправо. Прижми штрих к нулю -- и любая правка длины поедет узором.
--
-- Точки 2x2, а не 3x3: на пиксельной сетке это ближайший шаг вниз, он же
-- минус треть. Промежуточного размера не существует -- за ним пришлось бы
-- увеличивать весь мотив целиком.
--
-- По высоте мотив занимает 2..9 из 12, то есть отбит сверху и снизу поровну.

local BAND_W, BAND_H = 28, 12

local BAND_MARKS = {
    { 3, 2, 5, 2 },     -- штрих, верхний уровень; центр на 5
    { 14, 5, 2, 2 },    -- левая верхняя
    { 18, 8, 2, 2 },    -- нижняя, посередине
    { 22, 5, 2, 2 },    -- правая верхняя
}

local BAND_ALPHA = 150

local function buildBand()
    local buf = buffer.create(BAND_W * BAND_H * 4)
    local r, g, b = inkBytes()

    -- Прозрачный фон: полоса ложится поверх подложки окна.
    for i = 0, BAND_W * BAND_H - 1 do
        buffer.writeu8(buf, i * 4, r)
        buffer.writeu8(buf, i * 4 + 1, g)
        buffer.writeu8(buf, i * 4 + 2, b)
        buffer.writeu8(buf, i * 4 + 3, 0)
    end

    for _, mark in ipairs(BAND_MARKS) do
        local mx, my, mw, mh = mark[1], mark[2], mark[3], mark[4]
        for y = my, math.min(my + mh - 1, BAND_H - 1) do
            for x = mx, math.min(mx + mw - 1, BAND_W - 1) do
                buffer.writeu8(buf, (y * BAND_W + x) * 4 + 3, BAND_ALPHA)
            end
        end
    end

    return buf
end

--=============================================================================
-- Поверхность
--=============================================================================

-- parent -- на что натянуть, обычно корень окна или подложка блока.
-- Возвращает созданный слой либо nil, если не получилось.
function T.surface(parent)
    if not THEME.Scanlines and THEME.Grain <= 0 then return nil end

    local ok, layer = pcall(function()
        local image = AssetService:CreateEditableImage({ Size = Vector2.new(TILE, TILE) })
        image:WritePixelsBuffer(Vector2.zero, Vector2.new(TILE, TILE), buildTile())

        -- Active = false обязателен: слой лежит поверх всего, и без этого он
        -- накрыл бы собой каждую кнопку меню.
        return U.new("ImageLabel", {
            BackgroundTransparency = 1, Active = false,
            Size = UDim2.fromScale(1, 1), ZIndex = 15,
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(TILE, TILE),
            ImageContent = Content.fromObject(image),
        }, parent)
    end)

    return ok and layer or nil
end

-- Полоса-перфорация. y -- готовая координата в окне, полоса тянется во всю
-- ширину и повторяется по горизонтали.
function T.band(parent, y)
    if not THEME.Band then return nil end

    local ok, layer = pcall(function()
        local image = AssetService:CreateEditableImage({
            Size = Vector2.new(BAND_W, BAND_H),
        })
        image:WritePixelsBuffer(Vector2.zero, Vector2.new(BAND_W, BAND_H), buildBand())

        return U.new("ImageLabel", {
            BackgroundTransparency = 1, Active = false,
            Position = UDim2.fromOffset(0, y),
            Size = UDim2.new(1, 0, 0, THEME.BandHeight),
            ZIndex = 14,
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(BAND_W, BAND_H),
            ImageContent = Content.fromObject(image),
        }, parent)
    end)

    return ok and layer or nil
end

-- Единая точка для окна: текстура, а если её собрать не вышло -- прежние
-- фреймы. Вызывающему знать, что именно получилось, не нужно.
function T.apply(parent, height)
    local layer = T.surface(parent)
    if layer then return layer end
    return U.scanlines(parent, height)
end

end)(NierUI)

--============================ NierUI/ColorControl.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- ColorControl -- сам выбор цвета, без привязки к строке
--=============================================================================
--
-- Вынесен отдельно, потому что мест, где он нужен, стало два: строка-палитра
-- в меню и всплывающее окно у пункта списка. Держать две копии этой геометрии
-- -- гарантированно получить две разные палитры через месяц.
--
--
-- БЕЗ ЕДИНОГО АССЕТА
--
-- Квадрат насыщенности -- три слоя, а не картинка: снизу чистый тон, поверх
-- белый с горизонтальным градиентом прозрачности (насыщенность), поверх чёрный
-- с вертикальным (яркость). Полоса тона -- один Frame с UIGradient на семь
-- опорных цветов.
--
-- Это не эстетство: загруженная картинка -- это ассет, который надо где-то
-- держать, который модерируется и который может однажды перестать грузиться.
-- Здесь всё рисует движок.
--
--
-- sink -- КУДА СКЛАДЫВАТЬ КОННЕКТЫ
--
-- Контрол слушает мышь глобально (иначе перетаскивание рвётся, стоит курсору
-- уйти за пределы квадрата), поэтому обязан уметь отключаться. Владелец
-- передаёт свой список: строка -- window.conns на всю жизнь окна, всплывающее
-- окно -- свой, который гаснет при закрытии.

local UserInputService = game:GetService("UserInputService")

local THEME = NierUI.Theme
local U = NierUI.util

local HUE_STOPS = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
})

-- parent  -- куда встроить
-- opts    -- Position (UDim2), Width, Height, Color, Callback, sink, ZIndex
-- Высота HEX-строки под квадратом. Отдаётся наружу, чтобы вызывающие
-- резервировали место числом отсюда, а не подгоняли на глаз.
local HEX_H = 22
NierUI.colorControlExtra = HEX_H

function NierUI.colorControl(parent, opts)
    local z = opts.ZIndex or 30
    local fieldHeight = opts.Height or 100
    local sink = opts.sink or {}

    local h, s, v = Color3.toHSV(opts.Color or Color3.fromRGB(255, 40, 40))

    local holder = U.new("Frame", {
        BackgroundTransparency = 1,
        Position = opts.Position or UDim2.fromOffset(0, 0),
        Size = UDim2.new(opts.Width and 0 or 1, opts.Width or 0, 0, fieldHeight + HEX_H),
        ZIndex = z,
    }, parent)

    -- ACTIVE = TRUE ОБЯЗАТЕЛЕН, И ЭТО НЕ МЕЛОЧЬ.
    --
    -- Frame с Active = false щелчок не перехватывает -- он проваливается
    -- насквозь к тому, что лежит ниже. В строке под палитрой ничего не было, и
    -- это сходило с рук. Во всплывающем окне ниже лежит фон-перехватчик во весь
    -- экран, и щелчок по квадрату уходил в него: окно закрывалось раньше, чем
    -- начиналось перетаскивание, выбрать цвет было невозможно в принципе.
    --
    -- То же будет с любым будущим контролом внутри всплывающего окна: не
    -- поглощаешь щелчок -- закрываешь окно вместо работы.
    local field = U.new("Frame", {
        BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0,
        Active = true, Size = UDim2.new(1, -24, 0, fieldHeight), ZIndex = z,
    }, holder)

    local white = U.new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Active = false, Size = UDim2.fromScale(1, 1), ZIndex = z + 1,
    }, field)
    U.new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, white)

    local black = U.new("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
        Active = false, Size = UDim2.fromScale(1, 1), ZIndex = z + 2,
    }, field)
    U.new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, black)

    local fieldDot = U.new("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7),
        ZIndex = z + 4,
    }, field)
    U.stroke(fieldDot, 1, Color3.new(1, 1, 1))

    local hueBar = U.new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Active = true,   -- см. field: без этого щелчок уходит в фон окна
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 14, 0, fieldHeight), ZIndex = z,
    }, holder)
    U.new("UIGradient", { Rotation = 90, Color = HUE_STOPS }, hueBar)

    local hueDot = U.new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Active = false, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 4, 0, 2),
        ZIndex = z + 4,
    }, hueBar)

    --== HEX ==================================================================
    --
    -- Мышью в конкретный цвет не попасть -- это две координаты по сотне
    -- пикселей плюс тон. Поэтому цвет можно вписать кодом, и это тот же
    -- контрол, что стоит и в строке меню, и во всплывающем окне у пункта
    -- списка: пишется один раз, работает в обоих местах.

    -- Поле шириной РОВНО ПО КОДУ, а не во всю ширину контрола. Растянутое на
    -- всю строку, оно ловило щелчки далеко правее самого текста -- по пустому
    -- месту под квадратом.
    --
    -- Растёт вправо от левого края, поэтому код стоит на месте. Нижний предел
    -- нужен пустому полю: без него в него нечем попасть.
    local hexBox = U.new("TextBox", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = "", TextColor3 = THEME.Ink, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextEditable = true, ClearTextOnFocus = false,
        Position = UDim2.new(0, 0, 0, fieldHeight + 4),
        Size = UDim2.fromOffset(0, HEX_H - 4),
        AutomaticSize = Enum.AutomaticSize.X, ZIndex = z,
    }, holder)
    U.new("UISizeConstraint", { MinSize = Vector2.new(48, HEX_H - 4) }, hexBox)

    local editing = false

    -- Разрешаем решётку первым символом и до шести шестнадцатеричных цифр.
    -- Фильтруем по ходу набора: иначе набранные буквы видны, а на выходе молча
    -- превращаются в прежний цвет -- выглядит как проглоченный ввод.
    local function sanitizeHex(text)
        local out, digits = {}, 0
        for i = 1, #text do
            local ch = text:sub(i, i)
            if ch == "#" and #out == 0 then
                out[#out + 1] = ch
            elseif ch:match("[0-9a-fA-F]") and digits < 6 then
                digits = digits + 1
                out[#out + 1] = ch:upper()
            end
        end
        return table.concat(out)
    end

    -- Разбор -- в Util: тот же нужен кодеку конфига, и двух копий быть не должно.

    --=========================================================================

    local api = {}

    local function color()
        return Color3.fromHSV(h, s, v)
    end

    local function render(silent)
        field.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        fieldDot.Position = UDim2.fromScale(s, 1 - v)
        hueDot.Position = UDim2.fromScale(0.5, h)
        if not editing then hexBox.Text = U.hex(color()) end
        if silent or not opts.Callback then return end
        pcall(opts.Callback, color())
    end
    render(true)

    table.insert(sink, hexBox:GetPropertyChangedSignal("Text"):Connect(function()
        if not editing then return end
        local clean = sanitizeHex(hexBox.Text)
        if clean ~= hexBox.Text then hexBox.Text = clean end
    end))

    table.insert(sink, hexBox.Focused:Connect(function()
        editing = true
    end))

    table.insert(sink, hexBox.FocusLost:Connect(function()
        editing = false
        local parsed = U.fromHex(hexBox.Text)
        if parsed then
            h, s, v = Color3.toHSV(parsed)
        end
        -- не разобралось -- render вернёт прежний код обратно в поле
        render()
    end))

    -- Одна переменная с именем активной области, а не два независимых флага:
    -- иначе нажатие в квадрате и увод курсора на полосу тянуло бы обе сразу.
    local dragging = nil

    local function applyField(x, y)
        s = U.alongX(field, x)
        v = 1 - U.alongY(field, y)
        render()
    end

    local function applyHue(y)
        h = U.alongY(hueBar, y)
        render()
    end

    table.insert(sink, field.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = "field"
        applyField(input.Position.X, input.Position.Y)
    end))

    table.insert(sink, hueBar.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = "hue"
        applyHue(input.Position.Y)
    end))

    table.insert(sink, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if dragging == "field" then
            applyField(input.Position.X, input.Position.Y)
        else
            applyHue(input.Position.Y)
        end
    end))

    table.insert(sink, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = nil end
    end))

    -- Внутренний контрол, не виджет: вызывается точкой, без self. Виджеты
    -- наружу отдают двоеточные Get/Set -- смешивать соглашения в одном файле
    -- нельзя, а разводить их по слоям можно и нужно.
    function api.Get() return color() end
    function api.Set(c, silent)
        h, s, v = Color3.toHSV(c)
        render(silent)
    end
    api.instance = holder

    return api
end

end)(NierUI)

--============================ NierUI/Row.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Row -- общий каркас строки
--=============================================================================
--
-- Всё, что есть у любого элемента: фон подсветки, маркер, подпись, значение,
-- разделитель и механизм инверсии. Виджеты берут это готовым и дописывают
-- сверху только своё.
--
--
-- ВСЁ СОДЕРЖИМОЕ ПРИБИТО К ПЕРВОЙ СТРОКЕ, А НЕ РАСТЯНУТО ПО ВЫСОТЕ
--
-- Строка может вырасти -- так раскрываются списки и палитра. Подпись когда-то
-- была высотой во всю строку и центрировалась по РАСКРЫТОЙ высоте: текст
-- уезжал вниз и прятался под раскрытым блоком. Значение выживало случайно --
-- у него высота была задана в пикселях. Теперь фиксированы все.
--
-- Заливка подсветки тоже вынесена в отдельный фон фиксированной высоты, а не
-- висит на самой строке: иначе при раскрытии подсвечивался бы весь блок.
--
--
-- ПОДСВЕТКА -- ЭТО СОСТОЯНИЕ, А НЕ РЕАКЦИЯ НА КУРСОР
--
-- Раньше она была намертво привязана к MouseEnter/MouseLeave, и раскрытый
-- блок это ломало: увёл мышь -- шапка гасла, а раскрытое висело само по себе,
-- без начала. Теперь поводов два -- курсор и удержание, -- а рисуется одно и
-- то же. setHeld отдаётся виджету, он и держит.
--
--
-- ИНВЕРСИЯ -- ОБЩИЙ МЕХАНИЗМ, А НЕ ДВЕ ЗАХАРДКОЖЕННЫЕ ПОДПИСИ
--
-- Под курсором строка заливается чернилами, значит ВСЁ, что нарисовано
-- чернилами, обязано стать песочным, иначе просто исчезнет. На этом уже
-- попались: дорожка ползунка была того же цвета, что и фон под курсором, и
-- наведение делало ползунок невидимым. Любой элемент подписывает любое своё
-- свойство через invert().

local THEME = NierUI.Theme
local U = NierUI.util

-- valueClass -- "TextLabel" (по умолчанию) или "TextBox" для редактируемого
-- значения. Раньше ползунок получал подпись, гасил её и рисовал поле рядом
-- сам: в строке оставался мёртвый объект, а зарегистрированная на него
-- инверсия работала вхолостую. Теперь каркас сразу отдаёт нужный тип.
--
-- Поле НЕ ставится по умолчанию намеренно: TextBox перехватывает щелчки, и у
-- переключателя нажатие по «[ ON ]» перестало бы переключать строку.
function NierUI.makeRow(tab, text, desc, valueClass)
    tab.rows = tab.rows + 1

    local row = U.new("TextButton", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "",
        Size = UDim2.new(1, 0, 0, THEME.RowHeight),
        LayoutOrder = tab.rows,
    }, tab.page)

    local bg = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
        BorderSizePixel = 0, Active = false,
        Size = UDim2.new(1, 0, 0, THEME.RowHeight), ZIndex = 1,
    }, row)

    local marker = U.new("Frame", {
        BackgroundColor3 = THEME.Bg, BorderSizePixel = 0,
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.fromOffset(4, 4), ZIndex = 3,
    }, row)

    local label = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = text or "", TextColor3 = THEME.Ink, TextSize = THEME.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(THEME.LabelFrac, 0, 0, THEME.RowHeight), ZIndex = 3,
    }, row)

    local value
    if valueClass == "TextBox" then
        -- Ширина РОВНО ПО ТЕКСТУ: растянутое на всю колонку поле ловило бы
        -- щелчки далеко левее видимого числа, в том числе те, что метят в
        -- дорожку ползунка. Растёт от правого края влево, поэтому число стоит
        -- на месте и не съезжает при наборе длинного значения. Нижний предел --
        -- чтобы в пустое поле было чем попасть.
        value = U.new("TextBox", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = "", TextColor3 = THEME.InkSoft, TextSize = THEME.TextSize,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextEditable = true, ClearTextOnFocus = false,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 0),
            Size = UDim2.fromOffset(0, THEME.RowHeight),
            AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3,
        }, row)
        U.new("UISizeConstraint", { MinSize = Vector2.new(22, THEME.RowHeight) }, value)
    else
        value = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = "", TextColor3 = THEME.InkSoft, TextSize = THEME.TextSize,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 0),
            Size = UDim2.new(THEME.ValueFrac, 0, 0, THEME.RowHeight), ZIndex = 3,
        }, row)
    end

    -- Тонкая черта под строкой: в оригинале списки разлинованы. Тоже по первой
    -- строке, а не по низу блока -- иначе у раскрытого она убегала бы вниз.
    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        BackgroundTransparency = 0.85,
        Position = UDim2.new(0, 0, 0, THEME.RowHeight - 1),
        Size = UDim2.new(1, 0, 0, 1), ZIndex = 2,
    }, row)

    local inverts = {}
    local function invert(inst, prop, hovered, normal)
        inverts[#inverts + 1] = { inst = inst, prop = prop, on = hovered, off = normal }
    end

    invert(label, "TextColor3", THEME.Bg, THEME.Ink)
    invert(value, "TextColor3", THEME.Bg, THEME.InkSoft)

    local hovered, held, enabled = false, false, true

    --== недоступное состояние ===============================================
    --
    -- Недоступная строка НЕ ПРЯЧЕТСЯ и не перестаёт показывать своё значение --
    -- она бледнеет и перестаёт отзываться. Скрывать нельзя: человек ищет
    -- знакомый пункт глазами, а его нет, и непонятно, исчез он или не существует.
    --
    -- Подсветка при этом гасится совсем, а не просто не включается: курсор над
    -- недоступной строкой не должен обещать, что по ней можно щёлкнуть.

    -- ПОДПИСКА НА ПЕРЕРИСОВКУ, помимо простой инверсии.
    --
    -- invert годится там, где у элемента ровно два вида: обычный и под
    -- курсором. Но у сегментного переключателя вид зависит ещё и от того,
    -- выбран ли он, -- четыре сочетания вместо двух, и подстановкой пары
    -- значений это не описать. Такому элементу нужно знать, что строка
    -- перерисовалась, и решать самому.
    local painters = {}

    local function paintRow()
        local on = enabled and (hovered or held)
        U.tween(bg, { BackgroundTransparency = on and 0 or 1 })
        for _, e in ipairs(inverts) do e.inst[e.prop] = on and e.on or e.off end
        marker.BackgroundTransparency = on and 0 or 1

        if not enabled then
            label.TextColor3 = THEME.Disabled
            value.TextColor3 = THEME.Disabled
        end

        for _, paint in ipairs(painters) do paint(on, enabled) end
    end

    local window = tab.window
    table.insert(window.conns, row.MouseEnter:Connect(function()
        hovered = true
        paintRow()
        if desc then window:Hint(desc) end
    end))
    table.insert(window.conns, row.MouseLeave:Connect(function()
        hovered = false
        paintRow()
    end))

    local function setHeld(state)
        held = state and true or false
        paintRow()
    end

    -- ВОРОТА ВМЕСТО ПРОВЕРКИ В КАЖДОМ ОБРАБОТЧИКЕ.
    --
    -- Виджет оборачивает свои подписки в gate, и недоступность работает сама.
    -- Иначе пришлось бы дописывать `if not enabled then return end` в каждый
    -- обработчик каждого виджета -- а забыть один из них ничего не стоит, и
    -- получилась бы строка, которая выглядит выключенной, но щёлкается.
    local function gate(fn)
        return function(...)
            if not enabled then return end
            return fn(...)
        end
    end

    local rowApi = {}

    function rowApi.gate(fn) return gate(fn) end
    function rowApi.isEnabled() return enabled end

    -- fn(подсвечена, доступна) -- зовётся при каждой перерисовке строки.
    function rowApi.onPaint(fn)
        painters[#painters + 1] = fn
        fn(false, enabled)
    end

    --== настройки строки по правой кнопке ===================================
    --
    -- Тот же механизм, что у пунктов списка, но для ЛЮБОЙ строки. Раньше
    -- настройки были привилегией пунктов, хотя причина этому была только
    -- историческая: строке они нужны ничуть не реже -- клавиша активации,
    -- дополнительный цвет, режим.
    --
    -- Строка с настройками помечается точкой справа: без метки правая кнопка --
    -- знание, которое неоткуда взять.
    function rowApi.settings(window, title, spec, state, onChange)
        if not spec or next(spec) == nil then return end

        local dot = U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BackgroundTransparency = 0.4,
            BorderSizePixel = 0, Active = false,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -2, 0, math.floor(THEME.RowHeight / 2)),
            Size = UDim2.fromOffset(4, 4), ZIndex = 3,
        }, row)

        -- Точка нарисована чернилами, а под курсором строка заливается ими же --
        -- метка сливалась с подложкой и пропадала ровно там, где нужна. Это тот
        -- самый случай, для которого инверсия и заведена: два вида, обычный и
        -- под курсором, подписываем свойство и забываем.
        invert(dot, "BackgroundColor3", THEME.Bg, THEME.Ink)
        paintRow()

        table.insert(window.conns, row.MouseButton2Click:Connect(gate(function()
            NierUI.optionSettings(window, row, title, spec, state, onChange)
        end)))
    end

    function rowApi.setEnabled(state)
        enabled = state ~= false
        -- Поле ввода надо гасить отдельно: оно принимает фокус само, минуя
        -- обработчики, и осталось бы редактируемым.
        if value:IsA("TextBox") then
            value.TextEditable = enabled
            if not enabled then value:ReleaseFocus() end
        end
        hovered = false
        paintRow()
    end

    return row, label, value, invert, setHeld, rowApi
end

--=============================================================================
-- Раскрывающийся блок под строкой
--=============================================================================
--
-- Общий и для списков, и для палитры.
--
-- БЛОК ВЫДЕЛЯЕТСЯ ТОНОМ, А НЕ БОКОВЫМИ ЛИНИЯМИ. Здесь по очереди перепробованы
-- и отброшены два подхода на волосяных линиях по краям:
--
--   UIStroke -- рисуется по ВНЕШНЕМУ краю. Совпал по ширине со строкой --
--     вылез на пиксель влево, вправо и вниз; вдвинул объект -- обводка встала
--     на место, но по краям открылась щель в фон. Третьего у него нет.
--
--   Свои линии в крайних колонках -- геометрия становится симметричной
--     (замерено: слева x=553 w=1, справа x=947 w=1, обе непрозрачные,
--     координаты целые), а выглядят они всё равно по-разному: однопиксельная
--     линия на самом краю читается вместе с тем, что нарисовано впритык, а
--     слева и справа это разные вещи.
--
-- Поэтому боковых линий нет вовсе. Тон фона не зависит ни от разрешения, ни от
-- округления, ни от соседей. Снизу одна линия, чтобы блок был закрыт; сверху
-- её роль играет разделитель под строкой.

function NierUI.makePanel(row, height)
    -- Active = true: раскрытый блок ПОГЛОЩАЕТ щелчки. Без этого нажатие по его
    -- пустому месту -- по полям вокруг палитры, по краю списка -- проваливалось
    -- в строку под ним и схлопывало блок прямо во время работы с ним.
    local panel = U.new("Frame", {
        BackgroundColor3 = THEME.BgSunk, BorderSizePixel = 0, Active = true,
        Position = UDim2.new(0, 0, 0, THEME.RowHeight),
        Size = UDim2.new(1, 0, 0, 0), Visible = false,
        ZIndex = 30, ClipsDescendants = true,
    }, row)

    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 1), ZIndex = 32,
    }, panel)

    -- Высота хранится в состоянии, а не защёлкивается при создании: у
    -- динамического списка она меняется вместе с числом пунктов, и пересоздавать
    -- ради этого всю панель было бы нелепо.
    local current, isOpen = height or 0, false

    local function apply()
        local h = isOpen and current or 0
        panel.Size = UDim2.new(1, 0, 0, h)
        -- строка растёт вместе с блоком, иначе соседние строки его перекроют
        row.Size = UDim2.new(1, 0, 0, THEME.RowHeight + h)
    end

    local function setOpen(state)
        isOpen = state
        panel.Visible = state
        apply()
    end

    local function setHeight(h)
        current = h
        apply()
    end

    return panel, setOpen, setHeight
end

end)(NierUI)

--============================ NierUI/Window.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Window -- окно, вкладки и реестр виджетов
--=============================================================================
--
-- ЗДЕСЬ НЕТ НИ ОДНОГО ЦИКЛА И НИ ОДНОГО task.spawn. Всё на событиях, анимация
-- на TweenService. Каждый коннект пишется в window.conns, Destroy гасит все и
-- уничтожает ScreenGui -- после него не остаётся ничего.
--
-- Это прямой ответ на то, чем болел CompKiller: одиннадцать вечных
-- `while true do task.wait() end` переживали снос интерфейса, и каждая
-- пересборка добавляла около тринадцати тысяч таблиц и двух с половиной тысяч
-- функций, а один из потоков создавал Tween каждый кадр -- по разу на каждый
-- мёртвый экземпляр.

local UserInputService = game:GetService("UserInputService")

local THEME = NierUI.Theme
local U = NierUI.util

--=============================================================================
-- Реестр виджетов
--=============================================================================
--
-- Файл виджета вызывает NierUI.widget("Toggle", builder), и метод tab:Toggle()
-- появляется сам. Добавление элемента -- это ровно один новый файл, ничего
-- редактировать не нужно.

NierUI.widgets = {}

function NierUI.widget(name, builder)
    NierUI.widgets[name] = builder
end

--=============================================================================
-- ПРИВЯЗКА К КОНФИГУ
--=============================================================================
--
-- Виджет с полем Flag попадает в реестр окна и начинает сохраняться. Без
-- Flag он остаётся безымянным и в конфиг не идёт -- разметку и кнопки хранить
-- незачем.
--
-- Реестр держит ИМЕННО handle виджета, а не значение: сохранение спрашивает
-- Get, загрузка зовёт Set. Значит любой новый виджет становится сохраняемым
-- сам по себе, если умеет эту пару, и ничего дописывать в кодек не нужно.
--
-- Повторный Flag -- ошибка, а не тихая замена: два элемента под одним именем
-- means один затрёт другой при загрузке, и найти это потом почти невозможно.

--=============================================================================
-- ИМЯ И СОХРАНЕНИЕ -- РАЗНЫЕ ВЕЩИ
--=============================================================================
--
-- Сперва Flag делал две работы разом: служил именем для поиска
-- (win.flags.profileName:Get()) и одновременно означал «сохраняй меня». Развести
-- их было нечем, и получались нелепости: поле с именем профиля попадало в
-- каждый профиль, счётчик нажатий ехал в набор настроек.
--
-- Теперь Flag -- это только ИМЯ. Сохранением управляет Save:
--
--     Flag = "walkSpeed"                  именуется и сохраняется
--     Flag = "clickCount", Save = false    именуется, но в профиль не идёт
--     без Flag                             ни того, ни другого
--
-- Умолчание -- сохранять: настроек в меню несравнимо больше, чем счётчиков.

function NierUI.bindFlag(window, flag, handle, level, save)
    if not flag or not handle then return handle end
    if window.flags[flag] then
        error(("[NierUI] Flag «%s» уже занят другим элементом"):format(tostring(flag)),
            level or 3)
    end
    window.flags[flag] = handle
    if save == false then window.noSave[flag] = true end
    return handle
end

function NierUI.bind(container, opts, handle)
    if not opts then return handle end
    return NierUI.bindFlag(container.window, opts.Flag, handle, 4, opts.Save)
end

--=============================================================================

local Window = {}
Window.__index = Window

-- Класс отдаётся наружу под ОТДЕЛЬНЫМ именем: NierUI.Window -- это
-- конструктор, вызываемый через двоеточие, и положить туда же таблицу класса
-- значило бы сломать сам вызов.
NierUI.WindowClass = Window

local Tab = {}

--=============================================================================
-- КОНТЕЙНЕР
--=============================================================================
--
-- Виджеты НЕ ЗНАЮТ, что такое вкладка. Каждый работает с чем угодно, у чего
-- есть .page (куда класть строки), .rows (счётчик порядка) и .window (куда
-- складывать коннекты). Вкладка -- контейнер, блок -- тоже контейнер, и это
-- единственная причина, по которой блоки не потребовали править ни один
-- виджет.
--
-- На неизвестное имя ругаемся ВНЯТНО. Молчаливый nil давал «attempt to call a
-- nil value» без намёка, где именно опечатка, -- а имена виджетов строковые.

-- Методы, общие для всех контейнеров: секции, колонки и прочее, что не
-- является ни виджетом, ни особенностью вкладки или блока. Лежат отдельно,
-- чтобы не дублировать их в каждом классе контейнера.
NierUI.containerMethods = {}

function NierUI.containerIndex(class)
    return function(self, key)
        local own = rawget(class, key)
        if own then return own end

        local shared = NierUI.containerMethods[key]
        if shared then return shared end

        local builder = NierUI.widgets[key]
        if builder then
            return function(_, opts) return builder(self, opts or {}) end
        end

        -- Ругаться можно БЕЗУСЛОВНО, потому что контейнер не читает полей,
        -- которых у него нет: всё внутреннее состояние заводится при создании,
        -- отсутствие оси -- это false, а не nil.
        --
        -- Первая версия ругани ломала раскладку блоков ровно на этом: __index
        -- срабатывает на любое отсутствующее поле, а `if tab.grid then` до
        -- первого присваивания читало честный nil. Затыкать это проверкой «имя
        -- с большой буквы» значило бы держать соглашение об именах вместо
        -- инварианта. Инвариант надёжнее.
        local known = {}
        for name in pairs(NierUI.widgets) do known[#known + 1] = name end
        table.sort(known)
        error(("[NierUI] нет такого элемента: %s. Есть: %s")
            :format(tostring(key), table.concat(known, ", ")), 2)
    end
end

Tab.__index = NierUI.containerIndex(Tab)
NierUI.TabClass = Tab

--=============================================================================
-- Окно
--=============================================================================

function NierUI:Window(opts)
    opts = opts or {}

    -- Состояние заводится ЦЕЛИКОМ здесь. Ни одно поле не появляется по ходу
    -- дела: диспетчер контейнера ругается на любое отсутствующее, и «ещё не
    -- присвоено» от «опечатка» иначе не отличить.
    local self = setmetatable({
        tabs = {},
        conns = {},
        popups = {},
        flags = {},
        noSave = {},
        triggers = {},
        notifyLayer = false,
        notifications = {},
        triggerSeq = 0,
        -- Папку конфигов задаёт ТОЛЬКО вызывающий. Выводить её из заголовка
        -- окна нельзя: заголовок меняется по вкусу, и каждая его правка
        -- оставляла бы на диске новую папку с осиротевшими профилями.
        configFolder = opts.ConfigFolder or false,

        -- Перехват ввода на время, пока меню открыто. По умолчанию включён:
        -- меню, по которому нельзя щёлкнуть в бою, бесполезно.
        captureInput = opts.CaptureInput ~= false,
        captured = false,
        capturePrev = false,
        captureConns = false,
        captureAction = false,

        -- Свой указатель вместо системного. См. Cursor: системный в бою не
        -- показывается, сколько его ни включай.
        drawCursor = opts.Cursor ~= false,
        cursor = false,
        cursorParts = false,
        cursorOn = false,
        cursorConns = false,
        current = false,
        visible = true,
        -- Точка последнего нажатия. MouseButton1Click координат не несёт, а
        -- отличать нажатие по строке от нажатия внутри её раскрытой панели
        -- необходимо: раскрытая панель лежит ВНУТРИ строки, и щелчок по
        -- палитре доходил до строки и схлопывал её.
        lastPress = Vector2.zero,
        toggleKey = opts.ToggleKey or Enum.KeyCode.Delete,
    }, Window)

    -- Размер зажимается по экрану. Умолчание в 644x483 рассчитано на монитор, а
    -- на телефоне в альбомной ориентации логическая высота бывает и 414 -- окно
    -- вылезло бы за край вместе с нижней панелью и кнопкой закрытия. Запас в 16
    -- пикселей, чтобы рамка не упиралась в самый край.
    local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        or Vector2.new(1920, 1080)
    local width = math.min(opts.Width or THEME.WindowWidth, view.X - 16)
    local height = math.min(opts.Height or THEME.WindowHeight, view.Y - 16)

    self.gui = U.new("ScreenGui", {
        Name = U.randomName(),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999,
        IgnoreGuiInset = true,
    }, U.guiParent())

    self.root = U.new("Frame", {
        BackgroundColor3 = THEME.Bg, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = opts.Position or UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(width, height),
        ClipsDescendants = true,
    }, self.gui)
    U.stroke(self.root, 2)

    --== шапка ===============================================================

    local headerH = THEME.HeaderHeight
    local hintH = THEME.HintHeight
    local colW = THEME.TabColumnWidth

    -- Полосы-перфорации съедают высоту у содержимого, поэтому границы области
    -- считаются от них, а не от шапки напрямую. Band = false -- и всё
    -- сходится обратно само, без отдельной ветки раскладки.
    local bandH = THEME.Band and THEME.BandHeight or 0
    local top = headerH + 1 + bandH
    local bottom = hintH + bandH

    local header = U.new("Frame", {
        BackgroundTransparency = 1, Active = true,
        Size = UDim2.new(1, 0, 0, headerH),
    }, self.root)

    U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = opts.Title or "NieR", TextColor3 = THEME.Ink,
        TextSize = THEME.TitleSize, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 22),
    }, header)

    U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = opts.Subtitle or "", TextColor3 = THEME.InkSoft,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(17, 33), Size = UDim2.new(1, -32, 0, 12),
    }, header)

    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, headerH), Size = UDim2.new(1, 0, 0, 1),
    }, self.root)

    --== колонка вкладок =====================================================

    local tabCol = U.new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, top),
        Size = UDim2.new(0, colW, 1, -top - bottom),
    }, self.root)
    U.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, tabCol)
    U.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8) }, tabCol)
    self.tabCol = tabCol

    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        BackgroundTransparency = 0.6,
        Position = UDim2.fromOffset(colW, top),
        Size = UDim2.new(0, 1, 1, -top - bottom),
    }, self.root)

    --== содержимое ==========================================================

    self.body = U.new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(colW + 1, top),
        Size = UDim2.new(1, -(colW + 1), 1, -top - bottom),
    }, self.root)

    --== панель описания =====================================================

    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        BackgroundTransparency = 0.6,
        Position = UDim2.new(0, 0, 1, -hintH), Size = UDim2.new(1, 0, 0, 1),
    }, self.root)

    -- Полосы по краям содержимого: одна сразу под чертой шапки, вторая над
    -- панелью описания.
    NierUI.texture.band(self.root, headerH + 1)
    NierUI.texture.band(self.root, height - hintH - bandH)

    self.desc = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = opts.Hint or "", TextColor3 = THEME.InkSoft,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Position = UDim2.new(0, 16, 1, -(hintH - 6)),
        Size = UDim2.new(1, -32, 0, hintH - 12),
    }, self.root)

    U.corners(self.root)
    NierUI.texture.apply(self.root, height)

    --== перетаскивание ======================================================
    --
    -- Через события, без покадрового опроса. Мышь опрашивается сотни раз в
    -- секунду, но пока не тянут -- обработчик выходит первой строкой.

    local dragging, dragStart, startPos = false, nil, nil

    table.insert(self.conns, header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging, dragStart, startPos = true, input.Position, self.root.Position
    end))

    table.insert(self.conns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = input.Position - dragStart
        -- Округляем: дробная позиция окна размазывает все однопиксельные линии
        -- между соседними пикселями, и рамки начинают выглядеть неровными.
        self.root.Position = UDim2.new(
            startPos.X.Scale, math.floor(startPos.X.Offset + delta.X + 0.5),
            startPos.Y.Scale, math.floor(startPos.Y.Offset + delta.Y + 0.5))
    end))

    table.insert(self.conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))

    --== клавиша открытия ====================================================

    table.insert(self.conns, UserInputService.InputBegan:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.lastPress = input.Position
        end
        if processed then return end
        if input.KeyCode == self.toggleKey then self:Toggle() end
    end))

    return self
end

function Window:Hint(text)
    self.desc.Text = text or ""
end

--=============================================================================
-- КЛАВИША ОТКРЫТИЯ
--=============================================================================
--
-- Меняется на лету и без переподписки: обработчик ввода один и сравнивает с
-- текущим значением при каждом нажатии. Пересоздавать подписку ради смены
-- клавиши значило бы получить окно, у которого на секунду нет ни старой
-- клавиши, ни новой.
--
-- Поле toggleKey намеренно не объявлено «внутренним»: менять его напрямую
-- сработает, но проверки типа не будет, а Enum.KeyCode легко перепутать с
-- Enum.UserInputType -- тогда меню просто перестанет открываться, молча.

function Window:SetToggleKey(key)
    if typeof(key) ~= "EnumItem" or key.EnumType ~= Enum.KeyCode then
        error("[NierUI] SetToggleKey ждёт Enum.KeyCode, получено: "
            .. typeof(key), 2)
    end
    self.toggleKey = key
    return key
end

function Window:GetToggleKey()
    return self.toggleKey
end

-- Прячем КОРЕНЬ окна, а не весь ScreenGui.
--
-- Раньше гасился gui целиком, и вместе с меню исчезали бы уведомления --
-- а они обязаны показываться при закрытом меню, иначе бесполезны. Всплывающие
-- окна при закрытии гасим явно: висеть поверх спрятанного меню им незачем.
function Window:Toggle(state)
    if state == nil then state = not self.visible end
    self.visible = state
    self.root.Visible = state
    if not state then self:ClosePopups() end

    -- Пока меню открыто, ввод принадлежит ему: курсор виден, щелчки и движение
    -- в игру не уходят. См. Capture.
    if not self.captureInput then return end
    if state then self:StartCapture() else self:StopCapture() end
end

function Window:Destroy()
    -- Всплывающие окна и уведомления живут своей жизнью на ScreenGui, гасим их
    -- первыми: у уведомлений вдобавок висят отложенные задержки, которым иначе
    -- достались бы уже уничтоженные объекты.
    if self.ClosePopups then self:ClosePopups() end
    if self.ClearNotifications then self:ClearNotifications() end
    -- Перехват ввода надо снять обязательно: он живёт в сервисах, а не в нашем
    -- дереве, и уничтожение ScreenGui его не отпустит -- курсор остался бы
    -- висеть, а управление в игре не вернулось бы вовсе.
    if self.StopCapture then self:StopCapture() end

    for _, conn in ipairs(self.conns) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(self.conns)
    pcall(function() self.gui:Destroy() end)
    self.tabs, self.current = {}, nil
end

--=============================================================================
-- Вкладки
--=============================================================================

function Window:Tab(name)
    -- Как и у окна: всё состояние заводится сразу. grid и blocks появляются
    -- только когда вкладку делят на блоки, но читаются раньше -- значит должны
    -- существовать со дня рождения.
    local tab = setmetatable({
        window = self, rows = 0,
        grid = false, blocks = false,
        layoutQueued = false, separators = {},
    }, Tab)

    tab.button = U.new("TextButton", {
        BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Font = THEME.Font, Text = "  " .. (name or "TAB"),
        TextColor3 = THEME.Ink, TextSize = THEME.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -8, 0, THEME.RowHeight),
        LayoutOrder = #self.tabs + 1,
    }, self.tabCol)

    tab.page = U.new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), Visible = false,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = THEME.Ink,
        ScrollBarImageTransparency = 0.4,
    }, self.body)
    U.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, tab.page)
    U.new("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8),
    }, tab.page)

    table.insert(self.conns, tab.button.MouseEnter:Connect(function()
        if self.current ~= tab then U.tween(tab.button, { BackgroundTransparency = 0.85 }) end
    end))
    table.insert(self.conns, tab.button.MouseLeave:Connect(function()
        if self.current ~= tab then U.tween(tab.button, { BackgroundTransparency = 1 }) end
    end))
    table.insert(self.conns, tab.button.MouseButton1Click:Connect(function()
        self:Select(tab)
    end))

    table.insert(self.tabs, tab)
    if not self.current then self:Select(tab) end
    return tab
end

function Window:Select(tab)
    for _, other in ipairs(self.tabs) do
        local on = other == tab
        other.page.Visible = on
        U.tween(other.button, { BackgroundTransparency = on and 0 or 1 })
        other.button.TextColor3 = on and THEME.Bg or THEME.Ink
    end
    self.current = tab
end

end)(NierUI)

--============================ NierUI/Block.luau ============================
;(function(NierUI)
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

end)(NierUI)

--============================ NierUI/Section.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Section и Split -- вложенные контейнеры
--=============================================================================
--
--     local group = tab:Section("PASSIVE")        складная группа
--     group:Toggle({ ... })
--
--     local left, right = tab:Split(2)            колонки в одной строке
--     left:Toggle({ ... })  right:Slider({ ... })
--
-- Оба возвращают КОНТЕЙНЕР -- то же, что вкладка и блок. Виджеты не заметят
-- разницы, потому что знают только про .page, .rows и .window.
--
--
-- ПОЧЕМУ SPLIT, А НЕ SameLine
--
-- В imgui несколько элементов в строке ставятся через SameLine -- пометку
-- «следующий рядом с предыдущим». Здесь это не годится: каждый виджет строит
-- СВОЮ строку во всю ширину и сам расставляет подпись, дорожку и значение по
-- долям. Чтобы SameLine заработал, пришлось бы вскрыть все виджеты и научить
-- их делить строку -- то есть переписать ровно то, что мы только что привели в
-- порядок.
--
-- Split решает ту же задачу снаружи: делит МЕСТО, а не строку. Виджеты внутри
-- колонки продолжают считать, что занимают всю ширину, потому что для них это
-- правда -- просто ширина теперь другая. Ни один виджет не тронут.

local THEME = NierUI.Theme
local U = NierUI.util
local C = NierUI.containerMethods

local Sub = {}
Sub.__index = NierUI.containerIndex(Sub)

local function makeSub(parent, page)
    return setmetatable({ window = parent.window, rows = 0, page = page }, Sub)
end

--=============================================================================
-- Секция
--=============================================================================

function C.Section(self, title, opts)
    opts = opts or {}
    self.rows = self.rows + 1

    local holder = U.new("Frame", {
        BackgroundTransparency = 1, ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, THEME.RowHeight),
        LayoutOrder = self.rows,
    }, self.page)

    local header = U.new("TextButton", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "",
        Size = UDim2.new(1, 0, 0, THEME.RowHeight),
    }, holder)

    -- Указатель состояния: заполненный квадрат -- раскрыто, пустой -- свёрнуто.
    -- Значок вместо стрелки, чтобы не заводить ещё один шрифт ради глифа.
    local mark = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.fromOffset(6, 6), ZIndex = 3,
    }, header)

    local label = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = tostring(title or ""), TextColor3 = THEME.InkSoft, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -26, 0, THEME.RowHeight), ZIndex = 3,
    }, header)

    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        BackgroundTransparency = 0.75,
        Position = UDim2.new(0, 0, 0, THEME.RowHeight - 1),
        Size = UDim2.new(1, 0, 0, 1), ZIndex = 2,
    }, header)

    local body = U.new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, THEME.RowHeight),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, holder)
    U.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    U.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, body)

    local open = opts.Open ~= false

    -- Высота держателя считается ЯВНО: свёрнутая секция должна занимать ровно
    -- заголовок, а AutomaticSize учитывает и невидимых детей, из-за чего
    -- свёрнутая группа продолжала бы раздвигать соседей.
    local function relayout()
        holder.Size = UDim2.new(1, 0, 0,
            THEME.RowHeight + (open and body.AbsoluteSize.Y or 0))
        mark.BackgroundTransparency = open and 0 or 0.6
        body.Visible = open
    end

    table.insert(self.window.conns,
        body:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout))

    table.insert(self.window.conns, header.MouseButton1Click:Connect(function()
        open = not open
        relayout()
    end))
    table.insert(self.window.conns, header.MouseEnter:Connect(function()
        label.TextColor3 = THEME.Ink
    end))
    table.insert(self.window.conns, header.MouseLeave:Connect(function()
        label.TextColor3 = THEME.InkSoft
    end))

    relayout()

    local sub = makeSub(self, body)
    sub.SetOpen = function(_, state) open = state ~= false relayout() end
    sub.IsOpen = function(_) return open end
    return sub
end

--=============================================================================
-- Колонки
--=============================================================================

function C.Split(self, count, opts)
    opts = opts or {}
    count = math.max(2, math.min(count or 2, 4))
    self.rows = self.rows + 1

    local gap = opts.Gap or 6

    local holder = U.new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self.rows,
    }, self.page)

    local columns = {}
    local share = 1 / count

    for index = 1, count do
        -- Ширина долей минус доля зазора: колонки складываются в единицу без
        -- переполнения при любом количестве.
        local column = U.new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(share * (index - 1), index > 1 and gap / 2 or 0, 0, 0),
            Size = UDim2.new(share, -gap * (count - 1) / count, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        }, holder)
        U.new("UIListLayout", {
            Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
        }, column)

        columns[index] = makeSub(self, column)
    end

    return table.unpack(columns)
end

end)(NierUI)

--============================ NierUI/Cursor.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Cursor -- собственный указатель
--=============================================================================
--
-- ПОЧЕМУ СВОЙ, А НЕ СИСТЕМНЫЙ
--
-- Перехват сначала просто включал MouseIconEnabled и возвращал его, когда игра
-- гасила. Проверено вживую: щелчки в меню доходят, а курсора нет. Игра прячет
-- его не одним этим свойством, и спор за него проигрывается молча -- то есть
-- худшим способом: меню работает, а куда нажимать, непонятно.
--
-- Поэтому системный указатель гасится намеренно, а свой рисуется поверх.
--
--
--=============================================================================
-- ГЕОМЕТРИЯ ЗАДАНА В ФИЗИЧЕСКИХ ПИКСЕЛЯХ. ЭТО ГЛАВНОЕ ЗДЕСЬ.
--=============================================================================
--
-- При дробном масштабе экрана Windows интерфейс рисуется в логических пикселях
-- и растягивается. Замерено: панель 1920x1080, масштаб 125%, ViewportSize
-- 1536x864 -- один логический пиксель это 1.25 физического.
--
-- Логическая сетка тут не спасает никак, и вот почему. Пусть весь указатель
-- симметричен и начало координат стоит на целом физическом пикселе. Возьмём
-- горизонтальную черту с оправой в два логических пикселя: по X её края лягут
-- как (0.5, 1, 1), а по Y -- как (1, 1, 0.5). Оправа вокруг ОДНОЙ И ТОЙ ЖЕ
-- черты получает разный вес сбоку и сверху. Это и читается как «съехала».
--
-- Ровно она ляжет, только если каждый край попадёт на целую границу
-- физического пикселя. В логических пикселях при 125% это кратность четырём,
-- то есть оправа в пять физических пикселей -- неприемлемо толсто.
--
-- Поэтому размеры здесь -- В ФИЗИЧЕСКИХ ПИКСЕЛЯХ, а в логические переводятся
-- дробью. Дробь ВЫЖИВАЕТ ТОЛЬКО В Scale: UDim.Offset сам отбрасывает дробную
-- часть (проверено -- fromOffset(100.4) даёт ровно 100), а у Scale она
-- сохраняется (AbsolutePosition показывает 100.400002). Отсюда весь указатель
-- на долях и ни одного Offset.
--
--
-- ОТКУДА БЕРЁТСЯ МАСШТАБ
--
-- Ниоткуда: Roblox физического разрешения не сообщает. GuiService при 125%
-- отдаёт 1536x806 -- тот же логический размер минус верхняя панель.
--
-- Зато его видно по мыши. GetMouseLocation отдаёт ДРОБНЫЕ координаты (замерено:
-- 268.800018, 330.399994 -- кратны 0.8, то есть 1/1.25): положение мыши всегда
-- соответствует целому физическому пикселю. Значит наименьший ненулевой сдвиг
-- между двумя её положениями и есть размер физического пикселя в логических.
--
-- Меряем по ходу дела. До первого замера считаем шаг равным единице -- при 100%
-- это и есть точный ответ, а при дробном первое же движение мыши его уточняет.
--
-- Берём НЕ минимум сдвигов, а их НОД, и это принципиально: минимум верен, лишь
-- когда мышь хоть раз сдвинули ровно на пиксель, а если ею возят рывками по
-- три-четыре, минимум так и застрянет на трёх. НОД же сходится к истинному
-- шагу с любых движений -- достаточно двух сдвигов во взаимно простое число
-- пикселей, а таких пар среди случайных движений подавляющее большинство.

local UserInputService = game:GetService("UserInputService")

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

-- Поверх всего своего: у окна ZIndexBehavior = Sibling, число сравнивается
-- глобально, и всплывающие окна с их сотнями сюда не дотягиваются.
local Z = 1000000

--== размеры, В ФИЗИЧЕСКИХ ПИКСЕЛЯХ ==========================================

local MARGIN = 1         -- оправа
local THICK = 2          -- толщина черты
local ARM = 8            -- её длина
local GAP = 4            -- от середины до черты
local CORE = 2           -- сторона сердцевины

-- Части указателя: прямоугольник ЧЕРТЫ относительно середины, оправа шире его
-- на MARGIN со всех сторон. Отсюда просвет между оправой черты и оправой
-- сердцевины: GAP - MARGIN - (CORE/2 + MARGIN) = 1 пиксель. Слипаться им
-- нельзя -- проверено увеличенным снимком, всё светлое тогда сливается в один
-- толстый крест.
local PARTS = {
    { x = -GAP - ARM, y = -THICK / 2, w = ARM, h = THICK },   -- слева
    { x = GAP, y = -THICK / 2, w = ARM, h = THICK },          -- справа
    { x = -THICK / 2, y = -GAP - ARM, w = THICK, h = ARM },   -- сверху
    { x = -THICK / 2, y = GAP, w = THICK, h = ARM },          -- снизу
    { x = -CORE / 2, y = -CORE / 2, w = CORE, h = CORE },     -- сердцевина
}

-- Размер физического пикселя в логических. Живёт на самой библиотеке, а не на
-- окне: библиотека кешируется в окружении, поэтому замер делается один раз за
-- сессию и переживает и пересоздание окна, и перезапуск скрипта. Единица --
-- честное значение для масштаба 100%.
NierUI.pixelStep = NierUI.pixelStep or 1

--=============================================================================

local function build(window)
    -- Контейнер во весь экран: доли его детей считаются от размера экрана, и
    -- никакой арифметики с верхней панелью не нужно -- GetMouseLocation живёт
    -- в той же системе отсчёта.
    local holder = U.new("Frame", {
        BackgroundTransparency = 1, Active = false, Visible = false,
        Size = UDim2.fromScale(1, 1), ZIndex = Z,
    }, window.gui)

    local parts = {}
    for _, spec in ipairs(PARTS) do
        -- Оправа. Active = false на всём: указатель лежит поверх меню и ловил
        -- бы своими краями щелчки, предназначенные строке под ним.
        local frame = U.new("Frame", {
            BackgroundColor3 = THEME.Bg, BorderSizePixel = 0, Active = false,
            ZIndex = Z,
        }, holder)

        -- Черта внутри оправы -- чистое отношение, масштаб ей не нужен.
        local wTotal = spec.w + MARGIN * 2
        local hTotal = spec.h + MARGIN * 2
        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
            Position = UDim2.fromScale(MARGIN / wTotal, MARGIN / hTotal),
            Size = UDim2.fromScale(spec.w / wTotal, spec.h / hTotal),
            ZIndex = Z + 1,
        }, frame)

        parts[#parts + 1] = {
            frame = frame,
            x = spec.x - MARGIN, y = spec.y - MARGIN,
            w = wTotal, h = hTotal,
        }
    end

    window.cursor = holder
    window.cursorParts = parts
    return holder
end

--=============================================================================

function Window:ShowCursor()
    if self.cursorOn then return end
    -- Мыши может не быть вовсе: телефон, планшет, консоль. Указатель за пальцем
    -- не ходит, а нарисованный посреди экрана крест только мешает.
    if not UserInputService.MouseEnabled then return end
    self.cursorOn = true

    local holder = self.cursor or build(self)
    local parts = self.cursorParts

    local step = NierUI.pixelStep
    local last = nil
    local moves = 0

    local function layout()
        local size = holder.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then return end
        for _, p in ipairs(parts) do
            p.frame.Size = UDim2.fromScale(
                p.w * step / size.X, p.h * step / size.Y)
        end
    end

    local function place(at)
        local size = holder.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then return end
        for _, p in ipairs(parts) do
            p.frame.Position = UDim2.fromScale(
                (at.X + p.x * step) / size.X,
                (at.Y + p.y * step) / size.Y)
        end
    end

    -- Евклид с допуском. Сдвиги кратны истинному шагу, поэтому остаток сходится
    -- к нему за считаные итерации; порог 0.05 гасит накопленную погрешность.
    local function fold(a, b)
        if b < 1e-4 then return a end
        if a == nil then return b end
        if a < b then a, b = b, a end
        for _ = 1, 40 do
            if b <= 0.05 then break end
            a, b = b, a - math.floor(a / b + 1e-6) * b
        end
        return a
    end

    -- Евклид на float32 копит погрешность: замер дал 0.799591 вместо 0.8, и
    -- края разъезжались на сотую пикселя. Но настоящий шаг -- всегда дробь с
    -- небольшим знаменателем (125% -> 4/5, 150% -> 2/3, 175% -> 4/7, 200% ->
    -- 1/2), поэтому подтягиваем измеренное к ближайшей такой дроби. Заодно это
    -- якорь: подтянутое значение идёт обратно в накопитель и не даёт ему
    -- уползать дальше.
    local function snap(x)
        local best, err = x, 0.01
        for q = 1, 16 do
            local p = math.floor(x * q + 0.5)
            if p >= 1 then
                local v, d = p / q, math.abs(p / q - x)
                if d < err then best, err = v, d end
            end
        end
        return best
    end

    -- ГРАНИЦЫ ДОВЕРИЯ.
    --
    -- Снизу 0.1 -- это масштаб 1000%, с запасом на телефоны с плотностью 3x и
    -- 4x. Сверху 4 -- на случай, когда логический экран КРУПНЕЕ физического
    -- (масштаб меньше 100%; через настройки Windows такого не выставить, но
    -- драйверы и правка реестра позволяют).
    --
    -- Шаг больше логического пикселя принимаем только после восьми движений, и
    -- это не перестраховка: НОД сходится СВЕРХУ, и на первых сдвигах он вполне
    -- может оказаться равным трём. Приняв это сразу, мы бы на секунду раздули
    -- указатель втрое. Значение меньше единицы такой опасности не несёт --
    -- крупнее, чем при масштабе 100%, он от него не станет.
    local acc = nil
    local function observe(at)
        if last then
            moves = moves + 1
            acc = fold(fold(acc, math.abs(at.X - last.X)), math.abs(at.Y - last.Y))
            local trusted = acc and acc >= 0.1
                and (acc <= 1 or (acc <= 4 and moves >= 8))
            if trusted then
                acc = snap(acc)
                if math.abs(acc - step) > 1e-4 then
                    step = acc
                    NierUI.pixelStep = step
                    layout()
                end
            end
        end
        last = at
    end

    layout()
    place(UserInputService:GetMouseLocation())
    holder.Visible = true

    self.cursorConns = {
        -- Движение -- СОБЫТИЕ, а не кадр: мышь стоит, и не тратится ничего.
        -- Постоянных потоков в библиотеке по-прежнему нет ни одного.
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local at = UserInputService:GetMouseLocation()
            observe(at)
            place(at)
        end),

        -- Размер экрана меняется чаще, чем кажется: окно тянут за угол,
        -- включают полноэкранный режим, поворачивают планшет, перетаскивают
        -- окно на монитор с другой плотностью. Положение считается от текущего
        -- размера при каждом движении, а вот РАЗМЕРЫ частей заданы долей и
        -- сами не пересчитаются.
        --
        -- Замер при этом сбрасываем: у другого монитора другой физический
        -- пиксель, а НОД умеет только уменьшаться и сам бы туда не вернулся.
        holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            acc, last, moves = nil, nil, 0
            step = 1
            NierUI.pixelStep = 1
            layout()
            place(UserInputService:GetMouseLocation())
        end),
    }
end

function Window:HideCursor()
    if not self.cursorOn then return end
    self.cursorOn = false

    for _, conn in ipairs(self.cursorConns or {}) do
        pcall(function() conn:Disconnect() end)
    end
    self.cursorConns = false

    if self.cursor then self.cursor.Visible = false end
end

end)(NierUI)

--============================ NierUI/Capture.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Capture -- меню забирает ввод себе, пока открыто
--=============================================================================
--
-- Открыл меню посреди боя -- курсор появился, щелчки идут в меню, а не в игру.
-- Закрыл -- всё вернулось ровно как было.
--
-- Выключается опцией окна: NierUI:Window({ CaptureInput = false }).
--
--
-- ПОЧЕМУ НЕ ПОКАДРОВОЕ УДЕРЖАНИЕ
--
-- Игра выставляет режим мыши своим кодом и делает это регулярно, поэтому
-- однократной записи мало. Напрашивается держать значение каждый кадр -- и это
-- был бы первый постоянный поток в библиотеке, ради того, что меняется раз в
-- десять минут.
--
-- Вместо этого подписка на изменение самого свойства: игра его переписала --
-- мы вернули. Пока никто не спорит, не тратится ничего.
--
-- Своя запись отличается флагом: без него мы отвечали бы на собственное
-- изменение и ушли бы в бесконечную взаимную правку.
--
--
-- ДЕРЖИМ ТОЛЬКО РЕЖИМ МЫШИ
--
-- Раньше здесь удерживался ещё и MouseIconEnabled -- и это не работало.
-- Проверено вживую: щелчки в меню доходят, курсора нет. Игра прячет указатель
-- не одним этим свойством, а проигранный спор выглядит как работающее меню,
-- по которому непонятно куда нажимать.
--
-- Поэтому системный указатель теперь ГАСИТСЯ, а вместо него рисуется свой
-- (см. Cursor). Режим мыши держать по-прежнему необходимо: в LockCenter
-- указатель прибит к середине экрана и ни до одной строки не доедет.
--
--
-- ЧТО ИМЕННО ПОГЛОЩАЕТСЯ
--
-- Кнопки мыши и клавиши движения -- то, чем в бою стреляют и ездят. Не вся
-- клавиатура: под перехватом остались бы и наши собственные поля ввода, и
-- набрать в них что-либо стало бы нельзя.
--
-- Приоритет заведомо выше игровых: у Roblox штатные привязки живут около
-- двух тысяч, берём с запасом.

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local U = NierUI.util
local Window = NierUI.WindowClass

local PRIORITY = 5000

local SINK = {
    Enum.UserInputType.MouseButton1,
    Enum.UserInputType.MouseButton2,
    Enum.UserInputType.MouseButton3,
    Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
    Enum.KeyCode.Q, Enum.KeyCode.E,
    Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.LeftControl,
}

--=============================================================================

function Window:StartCapture()
    if self.captured then return end

    -- БЕЗ МЫШИ ПЕРЕХВАТЫВАТЬ НЕЧЕГО. На телефоне, планшете и консоли касание и
    -- так достаётся тому, по чему нажали, а поглощать WASD и кнопки мыши там
    -- бессмысленно: экранные органы управления -- это тот же интерфейс, и в
    -- ContextActionService они не приходят.
    --
    -- Хуже того, режим мыши там трогать нельзя вовсе: на консоли Default
    -- отвяжет прицел от стика.
    if not UserInputService.MouseEnabled then return end

    self.captured = true

    -- Запоминаем ровно то, что было: вернуть надо не «как принято», а как
    -- стояло у этого человека в этой игре.
    self.capturePrev = {
        behavior = UserInputService.MouseBehavior,
        icon = UserInputService.MouseIconEnabled,
    }

    -- Свой указатель -- значит системный лишний: два курсора хуже, чем ни
    -- одного. Отказались от своего -- пробуем показать системный, больше нам
    -- предложить нечего.
    local icon = not self.drawCursor

    local ours = false
    local function assert()
        if ours then return end
        ours = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = icon
        ours = false
    end
    assert()

    self.captureConns = {
        UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
            if self.captured then assert() end
        end),
        UserInputService:GetPropertyChangedSignal("MouseIconEnabled"):Connect(function()
            if self.captured then assert() end
        end),
    }

    if self.drawCursor then self:ShowCursor() end

    self.captureAction = "NierUI_" .. U.randomName()
    ContextActionService:BindActionAtPriority(
        self.captureAction,
        function() return Enum.ContextActionResult.Sink end,
        false, PRIORITY, table.unpack(SINK))
end

function Window:StopCapture()
    if not self.captured then return end
    self.captured = false

    self:HideCursor()

    for _, conn in ipairs(self.captureConns or {}) do
        pcall(function() conn:Disconnect() end)
    end
    self.captureConns = false

    if self.captureAction then
        pcall(function() ContextActionService:UnbindAction(self.captureAction) end)
        self.captureAction = false
    end

    local prev = self.capturePrev
    if prev then
        UserInputService.MouseBehavior = prev.behavior
        UserInputService.MouseIconEnabled = prev.icon
        self.capturePrev = false
    end
end

end)(NierUI)

--============================ NierUI/Config.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Config -- сохранение и загрузка настроек
--=============================================================================
--
--     win:Save("default")      записать профиль
--     win:Load("default")      применить
--     win:Profiles()           список имён
--     win:DeleteProfile(name)
--
-- Сохраняются только элементы с полем Flag. Разметку, кнопки и подписи хранить
-- незачем, а безымянный элемент невозможно потом найти при загрузке.
--
--
-- ЧТО ИМЕННО СОХРАНЯЕТСЯ
--
-- Реестр окна держит handle виджета, а не значение. Сохранение спрашивает Get,
-- загрузка зовёт Set. Значит новый виджет становится сохраняемым сам по себе,
-- если умеет эту пару, и кодек трогать не нужно.
--
--
-- ПОЧЕМУ НУЖЕН КОДЕК
--
-- JSON знает числа, строки, булевы и таблицы -- и больше ничего. А у нас в
-- значениях лежат Color3 (палитра) и EnumItem (привязка клавиши). Отдать их в
-- JSONEncode как есть нельзя: Color3 превратился бы в пустой объект, EnumItem
-- уронил бы кодирование.
--
-- Поэтому каждое непростое значение заворачивается в пометку типа:
--     Color3        -> { __t = "c", v = "#RRGGBB" }
--     EnumItem      -> { __t = "k", v = "LeftShift" }
-- Разворачивается обратно по той же пометке. Обычные таблицы (набор
-- множественного выбора, настройки пунктов) проходят рекурсией как есть.
--
--
-- ЗАГРУЗКА ЗОВЁТ ОБРАТНЫЕ ВЫЗОВЫ, И ЭТО НАМЕРЕННО
--
-- Молча выставить значения означало бы, что меню показывает включённое, а
-- фичи выключены. Профиль должен ПРИМЕНЯТЬСЯ, а не только отображаться.

local HttpService = game:GetService("HttpService")

local U = NierUI.util
local Window = NierUI.WindowClass

local ROOT = "NierUI"

--=============================================================================
-- Файлы
--=============================================================================
--
-- Функции записи есть не у всякого исполнителя, поэтому каждая проверяется
-- отдельно. Нет их -- сохранение просто не работает, а не роняет меню.

local function canWrite()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function ensureFolder(path)
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return end
    if not isfolder(path) then makefolder(path) end
end

-- Папку задаёт вызывающий, и её отсутствие -- ОШИБКА, а не повод придумать
-- имя самому. Придуманное имя означает, что при первой же смене заголовка окна
-- профили окажутся в новой папке, а старые останутся лежать сиротами.
local function folderOf(window)
    local folder = window.configFolder
    if not folder or folder == "" then
        error("[NierUI] не задана папка конфигов -- "
            .. "NierUI:Window({ ConfigFolder = \"myscript\" })", 3)
    end

    -- Имя попадает в путь, поэтому чистим всё, что не годится в имя файла.
    local safe = tostring(folder):gsub("[^%w _%-]", "")
    if safe == "" then
        error(("[NierUI] в ConfigFolder «%s» не осталось ни одного пригодного символа")
            :format(tostring(folder)), 3)
    end
    return ROOT .. "/" .. safe
end

local function pathOf(window, profile)
    return folderOf(window) .. "/" .. tostring(profile) .. ".json"
end

--=============================================================================
-- Кодек
--=============================================================================

local function encode(value)
    local kind = typeof(value)

    if kind == "Color3" then
        return { __t = "c", v = U.hex(value) }
    elseif kind == "EnumItem" then
        return { __t = "k", v = value.Name }
    elseif kind == "table" then
        local out = {}
        for k, v in pairs(value) do out[k] = encode(v) end
        return out
    end

    return value
end

local function decode(value)
    if type(value) ~= "table" then return value end

    if value.__t == "c" then
        return U.fromHex(value.v)
    end

    if value.__t == "k" then
        -- Клавиша могла исчезнуть между версиями движка -- pcall, а не вера.
        local ok, key = pcall(function() return Enum.KeyCode[value.v] end)
        return ok and key or nil
    end

    local out = {}
    for k, v in pairs(value) do out[k] = decode(v) end
    return out
end

--=============================================================================
-- Сбор и применение
--=============================================================================

local function collect(window)
    local data = {}
    for flag, handle in pairs(window.flags) do
        -- Помеченное Save = false именуется, но в профиль не идёт: счётчики,
        -- служебные поля и прочее состояние, которое настройкой не является.
        local ok, value = false, nil
        if not window.noSave[flag] then
            ok, value = pcall(handle.Get, handle)
        end
        if ok then
            local entry = { value = encode(value) }

            -- Настройки живут отдельно от значения: без них сохранённый набор
            -- вернулся бы без цветов, клавиш и флагов.
            --
            -- Форм две, и виджет сообщает свою сам. У списка настройки лежат по
            -- пунктам -- это два уровня; у строки уровень один. Догадываться по
            -- виду таблицы нельзя: настройка пункта сама может быть таблицей.
            if handle.SettingsMap then
                local okS, map = pcall(handle.SettingsMap, handle)
                if okS and next(map) ~= nil then
                    entry.settings = encode(map)
                    entry.flat = handle.SettingsFlat == true
                end
            end

            data[flag] = entry
        end
    end
    return data
end

local function apply(window, data)
    local applied, missing = 0, {}

    for flag, entry in pairs(data) do
        local handle = window.flags[flag]
        if not handle then
            -- Профиль от другой сборки меню: элемент исчез или переименован.
            missing[#missing + 1] = flag
        else
            if entry.settings and handle.SetSetting then
                local map = decode(entry.settings)
                if entry.flat then
                    for field, v in pairs(map) do
                        pcall(handle.SetSetting, handle, field, v)
                    end
                else
                    for key, fields in pairs(map) do
                        for name, v in pairs(fields) do
                            pcall(handle.SetSetting, handle, key, name, v)
                        end
                    end
                end
            end

            local value = decode(entry.value)
            if value ~= nil then
                local ok = pcall(handle.Set, handle, value)
                if ok then applied = applied + 1 end
            end
        end
    end

    return applied, missing
end

--=============================================================================
-- Наружу
--=============================================================================

function Window:Save(profile)
    if not canWrite() then
        return false, "исполнитель не умеет писать файлы"
    end

    ensureFolder(ROOT)
    ensureFolder(folderOf(self))

    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, collect(self))
    if not ok then return false, "не закодировалось: " .. tostring(encoded) end

    local okWrite, err = pcall(writefile, pathOf(self, profile or "default"), encoded)
    if not okWrite then return false, tostring(err) end
    return true
end

function Window:Load(profile)
    if not canWrite() then
        return false, "исполнитель не умеет читать файлы"
    end

    local path = pathOf(self, profile or "default")
    if type(isfile) == "function" and not isfile(path) then
        return false, "профиля нет"
    end

    local okRead, raw = pcall(readfile, path)
    if not okRead then return false, tostring(raw) end

    local okDecode, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not okDecode or type(data) ~= "table" then
        return false, "файл повреждён"
    end

    local applied, missing = apply(self, data)
    return true, applied, missing
end

function Window:Profiles()
    if type(listfiles) ~= "function" then return {} end

    local ok, files = pcall(listfiles, folderOf(self))
    if not ok then return {} end

    local out = {}
    for _, path in ipairs(files) do
        local name = tostring(path):match("([^/\\]+)%.json$")
        if name then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

function Window:DeleteProfile(profile)
    if type(delfile) ~= "function" then return false end
    local ok = pcall(delfile, pathOf(self, profile or "default"))
    return ok
end

end)(NierUI)

--============================ NierUI/Notify.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Notify -- всплывающие сообщения
--=============================================================================
--
--     win:Notify({ Text = "...", Title = "...", Duration = 6 })
--
-- Выезжают из-за правого края экрана, стопкой сверху вниз, снизу убывающая
-- полоска остатка времени. Duration задаёт срок жизни, по умолчанию берётся
-- Theme.NotifyDuration.
--
--
-- ЖИВУТ ОТДЕЛЬНО ОТ ОКНА
--
-- Сообщение о том, что кто-то зашёл на сервер, обязано показаться при ЗАКРЫТОМ
-- меню. Поэтому слой висит на ScreenGui рядом с окном, а Toggle прячет корень
-- окна, а не весь ScreenGui.
--
--
-- СТОПКА ВЕДЁТСЯ ВРУЧНУЮ, БЕЗ UIListLayout
--
-- Сначала карточки лежали в UIListLayout. Он САМ управляет позицией детей и
-- молча перезаписывал твин выезда -- анимации не было вовсе, карточка просто
-- возникала на месте. Разложить это на «слот от раскладки плюс карточка
-- внутри» тоже нельзя без второго слоя вложенности: по X двигается карточка,
-- по Y -- вся стопка, и обе координаты живут в одном свойстве Position.
--
-- Поэтому позиции считаются здесь: X отвечает за выезд и уход, Y -- за место в
-- стопке, пересчёт идёт при появлении, уходе и изменении высоты карточки.
--
--
-- ВЫСОТА ЗАДАЁТСЯ ЯВНО, А НЕ AutomaticSize
--
-- Полоска остатка прижата к низу карточки. С AutomaticSize по высоте это
-- замкнутая зависимость: высота считается по детям, а ребёнок стоит по высоте.
-- Поэтому высоту карточки выставляем сами по фактической высоте текста.
--
--
-- УНИЧТОЖЕНИЕ ГАРАНТИРОВАНО
--
-- Снос привязан к Completed твина ухода, а не к отдельной задержке: задержка
-- могла разъехаться с анимацией и оставить карточку висеть. Плюс защита от
-- повторного ухода и от сноса окна раньше срока -- в обоих случаях выходим
-- молча, ничего не оставляя.

local TweenService = game:GetService("TweenService")

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

local PAD = 10
local GAP = 6
local BAR = 2
local EDGE = 16          -- отступ стопки от края экрана

local MOVE = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EXIT = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

--=============================================================================

local function ensureLayer(window)
    if window.notifyLayer then return window.notifyLayer end

    window.notifyLayer = U.new("Frame", {
        BackgroundTransparency = 1, Active = false,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -EDGE, 0, EDGE),
        Size = UDim2.fromOffset(THEME.NotifyWidth, 0),
        ZIndex = 200,
    }, window.gui)

    return window.notifyLayer
end

-- Пересчёт стопки. X берётся у самой записи: за него отвечает выезд и уход, и
-- пересчёт не должен его затирать.
local function reflow(window)
    local y = 0
    for _, entry in ipairs(window.notifications) do
        if entry.card.Parent then
            TweenService:Create(entry.card, MOVE, {
                Position = UDim2.fromOffset(entry.x, y),
            }):Play()
            y = y + entry.card.AbsoluteSize.Y + GAP
        end
    end
end

--=============================================================================

function Window:Notify(opts)
    opts = opts or {}

    local width = THEME.NotifyWidth
    local duration = tonumber(opts.Duration) or THEME.NotifyDuration
    local layer = ensureLayer(self)

    -- Стартовая позиция -- за краем экрана: слой отбит от края на EDGE, значит
    -- сдвиг на ширину плюс этот отступ выводит карточку ровно за экран.
    local offscreen = width + EDGE

    local card = U.new("Frame", {
        BackgroundColor3 = THEME.Bg, BorderSizePixel = 0, Active = false,
        Position = UDim2.fromOffset(offscreen, 0),
        Size = UDim2.fromOffset(width, 0),
        ZIndex = 200, ClipsDescendants = true,
    }, layer)
    local line = U.stroke(card, 1)

    local top = PAD
    local titleLabel
    if opts.Title then
        titleLabel = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = tostring(opts.Title), TextColor3 = THEME.InkSoft, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(PAD, top),
            Size = UDim2.new(1, -PAD * 2, 0, 12), ZIndex = 201,
        }, card)
        top = top + 15
    end

    local body = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = tostring(opts.Text or ""), TextColor3 = THEME.Ink,
        TextSize = THEME.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(PAD, top),
        Size = UDim2.new(1, -PAD * 2, 0, 0), ZIndex = 201,
    }, card)

    -- Полоска остатка: живёт ровно duration и убывает линейно, поэтому по ней
    -- видно, сколько сообщение ещё провисит.
    local bar = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        BackgroundTransparency = 0.35,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, BAR), ZIndex = 202,
    }, card)

    local entry = { card = card, x = 0 }
    table.insert(self.notifications, entry)

    -- Высота карточки -- по фактической высоте текста. Пересчитывается по
    -- событию, потому что на кадре создания она ещё нулевая.
    local sizeConn
    sizeConn = body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if not card.Parent then return end
        card.Size = UDim2.fromOffset(width, top + body.AbsoluteSize.Y + PAD + BAR)
        reflow(self)
    end)

    card.Size = UDim2.fromOffset(width, top + body.TextBounds.Y + PAD + BAR)
    reflow(self)

    --== уход ================================================================
    --
    -- Гаснет ВСЁ разом и одним TweenInfo: подложка, рамка, обе подписи и
    -- полоска. Раньше гасились только подложка и текст -- рамка с заголовком
    -- оставались висеть в воздухе, пока карточка уезжала.

    local gone = false

    local function destroy()
        if sizeConn then
            sizeConn:Disconnect()
            sizeConn = nil
        end
        for i = #self.notifications, 1, -1 do
            if self.notifications[i] == entry then table.remove(self.notifications, i) end
        end
        if card.Parent then card:Destroy() end
        reflow(self)
    end

    local function dismiss()
        if gone then return end
        gone = true
        if not card.Parent then
            destroy()
            return
        end

        entry.x = offscreen
        TweenService:Create(line, EXIT, { Transparency = 1 }):Play()
        TweenService:Create(body, EXIT, { TextTransparency = 1 }):Play()
        TweenService:Create(bar, EXIT, { BackgroundTransparency = 1 }):Play()
        if titleLabel then
            TweenService:Create(titleLabel, EXIT, { TextTransparency = 1 }):Play()
        end

        local slide = TweenService:Create(card, EXIT, {
            Position = UDim2.fromOffset(offscreen, card.Position.Y.Offset),
            BackgroundTransparency = 1,
        })
        -- Снос по завершении анимации, а не по отдельной задержке: та могла
        -- разъехаться с ней и оставить карточку висеть.
        slide.Completed:Connect(destroy)
        slide:Play()
    end

    TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0, 0, 0, BAR) }):Play()

    task.delay(duration, dismiss)

    return { Dismiss = dismiss, instance = card }
end

-- Снять все разом. Нужно выгрузке окна: карточки висят на ScreenGui, и без
-- этого отложенные задержки достались бы уже уничтоженным объектам.
function Window:ClearNotifications()
    for i = #self.notifications, 1, -1 do
        local entry = self.notifications[i]
        if entry.card.Parent then entry.card:Destroy() end
        table.remove(self.notifications, i)
    end
end

end)(NierUI)

--============================ NierUI/Trigger.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Trigger -- условие снаружи, обработка внутри
--=============================================================================
--
--     win:Trigger({
--         Name = "join",
--         Signal = Players.PlayerAdded,          -- любой RBXScriptSignal
--         Filter = function(p) return p ~= me end,   -- условие пишет юзер
--         Message = function(p) return p.Name .. " зашёл" end,
--         Title = "PLAYER",
--         Action = function(p) list:Refresh(...) end,
--         Enabled = true,
--         Flag = "notifyJoin",
--     })
--
-- Возвращает handle: :Enable(), :Disable(), :IsEnabled(), :Fire(...).
--
--
-- ГДЕ ЗДЕСЬ ГРАНИЦА
--
-- Библиотека НЕ ЗНАЕТ, что такое игрок, вход и выход. Ей передают сигнал и
-- предикат -- она берёт на себя ровно три вещи, которые иначе пришлось бы
-- писать заново на каждый случай:
--
--   ВРЕМЯ ЖИЗНИ. Подписка живёт в окне и гаснет вместе с ним. Собственный
--     коннект пользователя пережил бы Destroy и остался бы висеть -- ровно тот
--     класс утечки, на котором мы горели трижды.
--
--   ВЫКЛЮЧАТЕЛЬ. У триггера есть состояние, которое можно завести на Flag и
--     тем самым сохранить в профиль. Выключенный триггер не отписывается, а
--     перестаёт срабатывать: переподписка на каждый щелчок тумблера -- лишний
--     способ потерять сигнал.
--
--   ПОКАЗ. Есть Message -- будет уведомление. Нет -- не будет. Пользователю не
--     нужно знать, как устроен слой сообщений.
--
-- Всё остальное -- откуда сигнал, что считать событием, что делать сверх
-- уведомления -- пишет тот, кто триггер объявляет.
--
--
-- ПОЧЕМУ ТОЛЬКО СИГНАЛЫ, А НЕ УСЛОВИЯ-ПРОВЕРКИ
--
-- Напрашивается Condition = function() return hp < 20 end с опросом каждый
-- кадр. Этого здесь нет намеренно: опрос -- это цикл, а библиотека держится на
-- том, что в ней нет ни одного постоянного потока. Нужен опрос -- заведите его
-- снаружи и дёргайте handle:Fire(), обработка та же.

local Window = NierUI.WindowClass

function Window:Trigger(opts)
    opts = opts or {}

    -- Имя по умолчанию берётся из СЧЁТЧИКА, а не из длины реестра: реестр --
    -- это отображение имя -> обработчик, у него нет числовой части, и # всегда
    -- давал ноль. Все безымянные триггеры получали одно и то же «trigger1» и
    -- молча вытесняли друг друга из реестра -- сигналы при этом работали, а
    -- найти триггер по имени было нельзя.
    self.triggerSeq = self.triggerSeq + 1

    local trigger = {
        name = opts.Name or ("trigger" .. self.triggerSeq),
        enabled = opts.Enabled ~= false,
    }

    -- Само срабатывание: сперва выключатель, потом условие, потом показ.
    -- Порядок важен -- выключенный триггер не должен даже вычислять предикат,
    -- он может быть дорогим.
    local function fire(...)
        if not trigger.enabled then return end

        if opts.Filter then
            local ok, pass = pcall(opts.Filter, ...)
            if not ok or not pass then return end
        end

        if opts.Message then
            local ok, text = pcall(opts.Message, ...)
            if ok and text ~= nil and text ~= "" then
                self:Notify({
                    Text = tostring(text),
                    Title = opts.Title,
                    Duration = opts.Duration,
                })
            end
        end

        if opts.Action then
            local ok, err = pcall(opts.Action, ...)
            if not ok then
                warn(("[NierUI] триггер %s: %s"):format(trigger.name, tostring(err)))
            end
        end
    end

    if opts.Signal then
        -- В window.conns, а не в собственный список: триггеры живут столько
        -- же, сколько окно, и гаснут одним махом в Destroy.
        table.insert(self.conns, opts.Signal:Connect(fire))
    end

    local handle = {
        Fire = function(_, ...) fire(...) end,
        Enable = function(_) trigger.enabled = true end,
        Disable = function(_) trigger.enabled = false end,
        IsEnabled = function(_) return trigger.enabled end,
        -- Пара Get/Set -- чтобы триггер сохранялся в профиль как обычный
        -- переключатель, без отдельной ветки в конфиге.
        Get = function(_) return trigger.enabled end,
        Set = function(_, on) trigger.enabled = on and true or false end,
    }

    self.triggers[trigger.name] = handle
    NierUI.bindFlag(self, opts.Flag, handle, 2, opts.Save)

    return handle
end

end)(NierUI)

--============================ NierUI/Popup.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Popup -- всплывающее окно поверх всего
--=============================================================================
--
-- ЗАЧЕМ ОТДЕЛЬНЫЙ СЛОЙ
--
-- Страница вкладки -- это ScrollingFrame, он обрезает всё, что выходит за его
-- границы. Раскрывающиеся блоки живут внутри строки и обрезаются вместе с ней:
-- правильно для списка, но не годится для окошка, которое должно вылезать за
-- пределы меню. Поэтому окна вешаются на сам ScreenGui и позиционируются в
-- экранных координатах.
--
--
--=============================================================================
-- ПОЧЕМУ ЗАКРЫТИЕ НЕ НА КНОПКЕ-ФОНЕ
--=============================================================================
--
-- Сначала под окном лежала прозрачная кнопка во весь экран с MouseButton1Click
-- на закрытие. Это оказалось неработоспособно, и по двум причинам сразу:
--
--   1. Click срабатывает на ОТПУСКАНИИ. Выбираешь цвет, ведёшь курсор, отпускаешь
--      чуть мимо панели -- окно закрывается прямо в момент выбора. Именно это и
--      ломало палитру: выбрать цвет было невозможно.
--
--   2. Окно создаётся В ОБРАБОТЧИКЕ Click, то есть на отпускании. Свежая кнопка
--      фона успевала получить то же самое отпускание и закрыть окно, едва оно
--      появилось.
--
-- Теперь закрытие -- по НАЖАТИЮ мимо панели, с собственной проверкой попадания,
-- и с явным взведением: пока кнопка мыши, которой окно открыли, ещё не
-- отпущена, окно закрыть нельзя. Проверяем состояние кнопки прямо при создании,
-- а не гадаем по таймеру.
--
-- Кнопка-фон осталась, но теперь у неё одна работа -- ПОГЛОЩАТЬ щелчки, чтобы
-- нажатие мимо окна не проваливалось в меню под ним.
--
-- Отзывается только ВЕРХНЕЕ окно: иначе щелчок внутри палитры закрывал бы
-- настройки под ней.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

local TITLE_H = THEME.PopupTitleHeight

function Window:Popup(opts)
    opts = opts or {}

    local depth = #self.popups
    local base = 100 + depth * 10

    local width = opts.Width or 200
    local height = opts.Height or 120

    -- ДВЕ СИСТЕМЫ ОТСЧЁТА -- ПОПРАВКА ЗДЕСЬ, А НЕ У ВЫЗЫВАЮЩИХ.
    --
    -- X и Y сюда приходят из AbsolutePosition якоря -- иначе и неоткуда, у
    -- строки другого адреса нет. Но у окна IgnoreGuiInset = true, и смещение в
    -- Position считается от НАСТОЯЩЕГО верха экрана, тогда как AbsolutePosition
    -- сообщается от границы под верхней панелью.
    --
    -- Замерено: панель 58 пикселей, и ровно на столько всплывающие окна вставали
    -- выше своей строки. Настройки тумблера ПОЛЁТ открывались над ним, а не
    -- рядом -- достаточно близко, чтобы полгода не вызывать вопросов.
    --
    -- Поправку делаем в одном месте: вызывающих у Popup много, и повторять её в
    -- каждом значит однажды забыть.
    local inset = GuiService:GetGuiInset()

    -- Держим окно в пределах экрана: открытое у нижнего края меню иначе
    -- уезжает за экран целиком.
    local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        or Vector2.new(1920, 1080)
    local x = math.clamp((opts.X or 0) + inset.X, 4, math.max(4, view.X - width - 4))
    local y = math.clamp((opts.Y or 0) + inset.Y, 4, math.max(4, view.Y - height - 4))

    local layer = U.new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        ZIndex = base, Name = U.randomName(),
    }, self.gui)

    -- Только поглотитель щелчков. Ничего не закрывает -- см. шапку.
    U.new("TextButton", {
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1), ZIndex = base,
    }, layer)

    -- Active = true: панель обязана поглощать щелчок, иначе нажатие по её
    -- пустому месту проваливается в меню под окном.
    local panel = U.new("Frame", {
        BackgroundColor3 = THEME.Bg, BorderSizePixel = 0, Active = true,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, height),
        ZIndex = base + 1, ClipsDescendants = true,
    }, layer)
    U.stroke(panel, 1)

    if opts.Title then
        U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = opts.Title, TextColor3 = THEME.InkSoft, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 12),
            ZIndex = base + 2,
        }, panel)
        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
            BackgroundTransparency = 0.65,
            Position = UDim2.fromOffset(0, TITLE_H), Size = UDim2.new(1, 0, 0, 1),
            ZIndex = base + 2,
        }, panel)
    end

    local conns = {}
    local closed = false

    local function close()
        if closed then return end
        closed = true
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        table.clear(conns)
        pcall(function() layer:Destroy() end)
        for i = #self.popups, 1, -1 do
            if self.popups[i].close == close then table.remove(self.popups, i) end
        end
    end

    local entry = { close = close, panel = panel }
    table.insert(self.popups, entry)

    --== закрытие ============================================================
    --
    -- Взводим сразу, если кнопка мыши уже отпущена; иначе -- по её отпусканию.
    -- Так окно не закроется тем же самым щелчком, которым его открыли, и при
    -- этом не нужен ни таймер, ни задержка.

    local armed = not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)

    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then armed = true end
    end))

    table.insert(conns, UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Escape then
            if self.popups[#self.popups] == entry then close() end
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not armed then return end
        -- отзывается только верхнее окно, иначе щелчок внутри палитры закрывал
        -- бы настройки под ней
        if self.popups[#self.popups] ~= entry then return end
        if U.inside(panel, input.Position) then return end
        close()
    end))

    --== перетаскивание ======================================================
    --
    -- За полосу заголовка. Ниже неё лежат строки настроек, и таскать за них
    -- значило бы мешать нажатиям.

    local dragging, dragStart, startPos = false, nil, nil

    table.insert(conns, panel.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if input.Position.Y > panel.AbsolutePosition.Y + TITLE_H then return end
        dragging, dragStart, startPos = true, input.Position, panel.Position
    end))

    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = input.Position - dragStart
        -- Округляем: дробная позиция размазывает однопиксельные линии между
        -- соседними пикселями, и рамка начинает выглядеть неровной.
        panel.Position = UDim2.fromOffset(
            math.floor(startPos.X.Offset + delta.X + 0.5),
            math.floor(startPos.Y.Offset + delta.Y + 0.5))
    end))

    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))

    return panel, close, conns, base + 2
end

function Window:ClosePopups()
    for i = #self.popups, 1, -1 do
        pcall(self.popups[i].close)
    end
    self.popups = {}
end

end)(NierUI)

--============================ NierUI/Modal.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Modal -- подтверждение
--=============================================================================
--
--     win:Confirm({
--         Title = "UNLOAD", Text = "Снять меню целиком?",
--         Confirm = "YES", Cancel = "NO",
--         OnConfirm = function() ... end,
--     })
--
-- Стоит на готовом механизме всплывающих окон: своя раскладка, чужие фон,
-- закрытие щелчком мимо, перетаскивание за заголовок и вложенность.
--
-- Единственное отличие от обычного всплывающего окна -- положение: модалка
-- встаёт по центру экрана, а не рядом с элементом. Подтверждение не привязано
-- к месту, откуда его вызвали, и искать его глазами в углу неправильно.

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

local WIDTH = 300
local BUTTON_H = 26

function Window:Confirm(opts)
    opts = opts or {}

    local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        or Vector2.new(1920, 1080)

    local text = tostring(opts.Text or "")
    -- Высоту прикидываем по длине текста: точную не узнать до отрисовки, а
    -- окно уже должно встать по центру.
    local lines = math.max(1, math.ceil(#text / 42))
    local height = THEME.PopupTitleHeight + 12 + lines * 16 + 12 + BUTTON_H + 12

    local panel, close, conns, z = self:Popup({
        Title = opts.Title or "CONFIRM",
        Width = WIDTH, Height = height,
        X = math.floor((view.X - WIDTH) / 2),
        Y = math.floor((view.Y - height) / 2),
    })

    U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = text, TextColor3 = THEME.Ink, TextSize = THEME.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Position = UDim2.fromOffset(12, THEME.PopupTitleHeight + 10),
        Size = UDim2.new(1, -24, 0, lines * 16), ZIndex = z,
    }, panel)

    local function button(label, x, width, action)
        local btn = U.new("TextButton", {
            BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false,
            Font = THEME.Font, Text = tostring(label),
            TextColor3 = THEME.Ink, TextSize = THEME.TextSize,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(x, 0, 1, -12),
            Size = UDim2.new(width, -6, 0, BUTTON_H), ZIndex = z,
        }, panel)
        local line = U.stroke(btn, 1)

        table.insert(conns, btn.MouseEnter:Connect(function()
            btn.BackgroundTransparency = 0
            btn.TextColor3 = THEME.Bg
            line.Transparency = 1
        end))
        table.insert(conns, btn.MouseLeave:Connect(function()
            btn.BackgroundTransparency = 1
            btn.TextColor3 = THEME.Ink
            line.Transparency = 0
        end))
        table.insert(conns, btn.MouseButton1Click:Connect(function()
            -- Закрываем ПЕРЕД действием: действие может открыть своё окно, и
            -- закрытие после него схлопнуло бы уже не нас.
            close()
            if action then pcall(action) end
        end))
    end

    button(opts.Cancel or "CANCEL", 0.04, 0.44, opts.OnCancel)
    button(opts.Confirm or "CONFIRM", 0.52, 0.44, opts.OnConfirm)

    return close
end

end)(NierUI)

--============================ NierUI/OptionSettings.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- OptionSettings -- окошко настроек у отдельного пункта
--=============================================================================
--
-- Открывается правой кнопкой по пункту списка. Внутри -- по строке на каждую
-- настройку; цвет открывает палитру ВТОРЫМ окном поверх.
--
--
-- ТИП ВЫВОДИТСЯ ИЗ ЗНАЧЕНИЯ ПО УМОЛЧАНИЮ, А НЕ ЗАДАЁТСЯ ОТДЕЛЬНО
--
--     Settings = { NAMES = { Color = Color3.fromRGB(255,255,255), Outline = true } }
--
-- Color3 -- образец с палитрой, boolean -- переключатель, EnumItem -- захват
-- клавиши. Описывать тип вручную значило бы держать его в двух местах и
-- однажды разойтись.
--
-- Исключение одно -- ползунок. По голому числу диапазон не угадать, поэтому
-- ему нужна форма описания:
--
--     Settings = { ЗНАЧЕНИЕ = { Type = "Slider", Default = 1000,
--                               Min = 1, Max = 999999, Step = 1 } }
--
-- В состоянии при этом лежит само число, а не описание: наружу и в профиль
-- уходит значение.
--
-- Порядок строк -- по алфавиту ключей. Порядок обхода хеша в Lua не определён,
-- и без сортировки настройки перемешивались бы при каждом открытии.

local UserInputService = game:GetService("UserInputService")

local THEME = NierUI.Theme
local U = NierUI.util

local ROW = THEME.RowHeight
local WIDTH = 220
-- Первая строка идёт под полосой заголовка всплывающего окна. Высоту полосы
-- берём у темы, а не повторяем числом: раньше здесь стояло 26 при полосе в 22,
-- и четыре пикселя расхождения существовали просто потому, что их никто не
-- сверял.
local TOP = THEME.PopupTitleHeight + 4

-- Начальное значение настройки. Для описания ползунка это его Default, для
-- всего остального -- само значение.
function NierUI.settingDefault(value)
    if type(value) == "table" and value.Type then return value.Default end
    return value
end

-- window   -- окно, которому принадлежит всплывающее
-- anchor   -- от какого элемента отсчитывать положение
-- title    -- заголовок окошка
-- spec     -- ключ -> значение по умолчанию
-- state    -- ключ -> текущее значение (меняется на месте)
-- onChange -- function(key, value)
function NierUI.optionSettings(window, anchor, title, spec, state, onChange)
    local keys = {}
    for key in pairs(spec) do keys[#keys + 1] = key end
    table.sort(keys)
    if #keys == 0 then return end

    local height = TOP + #keys * ROW + 8
    local panel, close, conns, z = window:Popup({
        Title = title,
        Width = WIDTH,
        Height = height,
        X = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + 6,
        Y = anchor.AbsolutePosition.Y,
    })

    for index, key in ipairs(keys) do
        local y = TOP + (index - 1) * ROW

        local rowBtn = U.new("TextButton", {
            BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false, Text = "",
            Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, ROW),
            ZIndex = z,
        }, panel)

        local label = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = tostring(key), TextColor3 = THEME.Ink,
            TextSize = THEME.TextSize, TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -110, 1, 0),
            ZIndex = z + 1,
        }, rowBtn)

        local descriptor = spec[key]
        local isSlider = type(descriptor) == "table" and descriptor.Type == "Slider"

        local current = state[key]
        if current == nil then current = NierUI.settingDefault(descriptor) end

        if isSlider then
            local min = descriptor.Min or 0
            local max = descriptor.Max or 100
            local stepSize = descriptor.Step or 1

            local span = (max > min) and (max - min) or 1

            local decimals = 0
            if stepSize < 1 then
                decimals = math.max(0, math.ceil(-math.log(stepSize, 10)))
            end
            local format = "%." .. decimals .. "f"
            local roundTo = 10 ^ decimals

            -- Строка тесная: название, дорожка и поле числа делят 220 пикселей.
            -- Название поэтому обрезается, а не растягивается под остальными.
            label.Size = UDim2.fromOffset(96, ROW)
            label.TextTruncate = Enum.TextTruncate.AtEnd

            local track = U.new("Frame", {
                BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
                BackgroundTransparency = 0.75, AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 112, 0, math.floor(ROW / 2)),
                Size = UDim2.fromOffset(50, 2), ZIndex = z + 1,
            }, rowBtn)
            local fill = U.new("Frame", {
                BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
                Size = UDim2.fromScale(0, 1),
            }, track)

            local box = U.new("TextBox", {
                BackgroundTransparency = 1, Font = THEME.Font,
                Text = "", TextColor3 = THEME.InkSoft, TextSize = THEME.TextSize,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextEditable = true, ClearTextOnFocus = false,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -10, 0, 0),
                Size = UDim2.fromOffset(0, ROW),
                AutomaticSize = Enum.AutomaticSize.X, ZIndex = z + 1,
            }, rowBtn)
            U.new("UISizeConstraint", { MinSize = Vector2.new(22, ROW) }, box)

            local editing = false

            local function render()
                local v = state[key] or min
                if not editing then box.Text = format:format(v) end
                fill.Size = UDim2.fromScale((v - min) / span, 1)
            end

            local function commit(v)
                state[key] = math.clamp(
                    math.floor(v * roundTo + 0.5) / roundTo, min, max)
                render()
                if onChange then pcall(onChange, key, state[key]) end
            end

            if state[key] == nil then state[key] = current or min end
            render()

            -- Тянуть можно только за дорожку. Строка занимает всю ширину окошка,
            -- и нажатие по названию швырнуло бы значение в минимум.
            local sliding = false
            table.insert(conns, rowBtn.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                local x = input.Position.X
                if x < track.AbsolutePosition.X - 6
                    or x > track.AbsolutePosition.X + track.AbsoluteSize.X + 6 then return end
                sliding = true
                commit(min + span * U.alongX(track, x))
            end))
            table.insert(conns, UserInputService.InputChanged:Connect(function(input)
                if not sliding then return end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                commit(min + span * U.alongX(track, input.Position.X))
            end))
            table.insert(conns, UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    sliding = false
                end
            end))

            -- Точное значение набирается руками: по дорожке в 56 пикселей в
            -- диапазон до миллиона не попасть.
            table.insert(conns, box.Focused:Connect(function() editing = true end))
            table.insert(conns, box.FocusLost:Connect(function()
                editing = false
                local typed = tonumber(box.Text)
                if typed then commit(typed) else render() end
            end))

            table.insert(conns, rowBtn.MouseEnter:Connect(function()
                rowBtn.BackgroundTransparency = 0
                label.TextColor3, box.TextColor3 = THEME.Bg, THEME.Bg
                track.BackgroundColor3, fill.BackgroundColor3 = THEME.Bg, THEME.Bg
            end))
            table.insert(conns, rowBtn.MouseLeave:Connect(function()
                rowBtn.BackgroundTransparency = 1
                label.TextColor3, box.TextColor3 = THEME.Ink, THEME.InkSoft
                track.BackgroundColor3, fill.BackgroundColor3 = THEME.Ink, THEME.Ink
            end))

        elseif typeof(current) == "Color3" then
            local swatch = U.new("Frame", {
                BackgroundColor3 = current, BorderSizePixel = 0,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(34, 12),
                ZIndex = z + 1,
            }, rowBtn)
            local line = U.stroke(swatch, 1)

            table.insert(conns, rowBtn.MouseEnter:Connect(function()
                rowBtn.BackgroundTransparency = 0
                label.TextColor3 = THEME.Bg
                line.Color = THEME.Bg
            end))
            table.insert(conns, rowBtn.MouseLeave:Connect(function()
                rowBtn.BackgroundTransparency = 1
                label.TextColor3 = THEME.Ink
                line.Color = THEME.Ink
            end))

            -- ЛКМ по цвету -- палитра ВТОРЫМ окном. Её фон перехватывает
            -- щелчок мимо первым, поэтому закрывается только она, а настройки
            -- остаются открытыми.
            table.insert(conns, rowBtn.MouseButton1Click:Connect(function()
                -- Открываем СПРАВА от окна настроек, а не под курсором: так
                -- палитра гарантированно не ложится поверх той строки, из
                -- которой её вызвали, и её видно целиком.
                local field = 100
                local pad = 12
                local pickPanel, _, pickConns, pickZ = window:Popup({
                    Title = tostring(key),
                    Width = WIDTH,
                    Height = TOP + pad + field + NierUI.colorControlExtra + pad,
                    X = panel.AbsolutePosition.X + panel.AbsoluteSize.X + 6,
                    Y = rowBtn.AbsolutePosition.Y - 24,
                })

                NierUI.colorControl(pickPanel, {
                    Position = UDim2.fromOffset(pad, TOP + pad),
                    Width = WIDTH - pad * 2, Height = field,
                    Color = state[key] or spec[key],
                    sink = pickConns,
                    ZIndex = pickZ,
                    Callback = function(c)
                        state[key] = c
                        swatch.BackgroundColor3 = c
                        if onChange then pcall(onChange, key, c) end
                    end,
                })
            end))

        elseif typeof(current) == "EnumItem" then
            -- Захват клавиши. Пока ждём нажатие, строка помечена и подсвечена:
            -- иначе непонятно, что окно чего-то ждёт.
            local value = U.new("TextLabel", {
                BackgroundTransparency = 1, Font = THEME.Font,
                Text = current.Name, TextColor3 = THEME.InkSoft,
                TextSize = THEME.TextSize,
                TextXAlignment = Enum.TextXAlignment.Right,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -10, 0, 0),
                Size = UDim2.fromOffset(110, ROW), ZIndex = z + 1,
            }, rowBtn)

            local listening = false

            local function paint()
                rowBtn.BackgroundTransparency = listening and 0 or 1
                label.TextColor3 = listening and THEME.Bg or THEME.Ink
                value.TextColor3 = listening and THEME.Bg or THEME.InkSoft
            end

            table.insert(conns, rowBtn.MouseEnter:Connect(function()
                if listening then return end
                rowBtn.BackgroundTransparency = 0
                label.TextColor3 = THEME.Bg
                value.TextColor3 = THEME.Bg
            end))
            table.insert(conns, rowBtn.MouseLeave:Connect(function()
                if listening then return end
                paint()
            end))

            table.insert(conns, rowBtn.MouseButton1Click:Connect(function()
                listening = true
                value.Text = "[ ... ]"
                paint()
            end))

            table.insert(conns, UserInputService.InputBegan:Connect(function(input, processed)
                if not listening then return end
                if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

                listening = false
                -- Escape отменяет назначение, а не назначает Escape.
                if input.KeyCode ~= Enum.KeyCode.Escape then
                    state[key] = input.KeyCode

                    -- НАЗНАЧЕНИЕ ВСТУПАЕТ В СИЛУ СО СЛЕДУЮЩЕГО КАДРА.
                    --
                    -- Нажатие, которым клавишу назначают, продолжает
                    -- расходиться по остальным подписчикам этого же события.
                    -- Сообщи мы о смене прямо здесь -- тот, кто на неё
                    -- настраивает привязку, успел бы записать новую клавишу,
                    -- и его собственный обработчик увидел бы совпадение с
                    -- только что нажатой: фича включалась бы в момент бинда.
                    --
                    -- Полагаться на порядок обработчиков нельзя, он в Roblox
                    -- не определён. Отложенный вызов снимает вопрос порядка
                    -- целиком: к следующему кадру событие уже отработало.
                    if onChange then
                        local captured = input.KeyCode
                        task.defer(function() pcall(onChange, key, captured) end)
                    end
                end
                value.Text = (state[key] or spec[key]).Name
                paint()
            end))

        elseif type(current) == "boolean" then
            local value = U.new("TextLabel", {
                BackgroundTransparency = 1, Font = THEME.Font,
                Text = current and "[ ON ]" or "[ OFF ]",
                TextColor3 = THEME.InkSoft, TextSize = THEME.TextSize,
                TextXAlignment = Enum.TextXAlignment.Right,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -10, 0, 0),
                Size = UDim2.fromOffset(80, ROW), ZIndex = z + 1,
            }, rowBtn)

            table.insert(conns, rowBtn.MouseEnter:Connect(function()
                rowBtn.BackgroundTransparency = 0
                label.TextColor3 = THEME.Bg
                value.TextColor3 = THEME.Bg
            end))
            table.insert(conns, rowBtn.MouseLeave:Connect(function()
                rowBtn.BackgroundTransparency = 1
                label.TextColor3 = THEME.Ink
                value.TextColor3 = THEME.InkSoft
            end))

            table.insert(conns, rowBtn.MouseButton1Click:Connect(function()
                local next_ = not state[key]
                state[key] = next_
                value.Text = next_ and "[ ON ]" or "[ OFF ]"
                if onChange then pcall(onChange, key, next_) end
            end))
        end
    end

    return close
end

end)(NierUI)

--============================ NierUI/widgets/Basic.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Toggle, Button, Label, Divider
--=============================================================================

local THEME = NierUI.Theme
local U = NierUI.util

--== переключатель ===========================================================

NierUI.widget("Toggle", function(tab, opts)
    local row, _, value, _, _, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc)
    local state = opts.Default and true or false

    local function render()
        value.Text = state and "[ ON ]" or "[ OFF ]"
    end
    render()

    local function set(on, silent)
        state = on and true or false
        render()
        if silent or not opts.Callback then return end
        local ok, err = pcall(opts.Callback, state)
        if not ok then warn("[NierUI] " .. tostring(opts.Text) .. ": " .. tostring(err)) end
    end

    table.insert(tab.window.conns, row.MouseButton1Click:Connect(rowApi.gate(function()
        set(not state)
    end)))

    if opts.Enabled == false then rowApi.setEnabled(false) end

    -- Свои настройки по правой кнопке. Значения по умолчанию копируются в
    -- собственное состояние: править переданный spec нельзя, он может быть
    -- общей таблицей.
    local settings
    if opts.Settings then
        settings = {}
        for key, default in pairs(opts.Settings) do
            settings[key] = NierUI.settingDefault(default)
        end
        rowApi.settings(tab.window, opts.Text or "", opts.Settings, settings, opts.OnSetting)
    end

    return NierUI.bind(tab, opts, {
        -- Настройки строки идут в профиль наравне со значением: клавиша,
        -- цвет и режим -- такие же настройки, как сам тумблер.
        --
        -- SettingsFlat говорит кодеку, что уровень тут один: у списка настройки
        -- разложены по пунктам, у строки -- нет.
        SettingsFlat = true,
        SettingsMap = function(_) return settings or {} end,

        GetSetting = function(_, key) return settings and settings[key] end,
        SetSetting = function(_, key, v)
            if not settings then return end
            settings[key] = v
            -- Загрузка профиля обязана ПРИМЕНИТЬ настройку, а не только
            -- запомнить: иначе меню показывает новую клавишу, а работает старая.
            if opts.OnSetting then pcall(opts.OnSetting, key, v) end
        end,

        Set = function(_, on, silent) set(on, silent) end,
        Get = function(_) return state end,
        SetEnabled = function(_, on) rowApi.setEnabled(on) end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)

--== кнопка ==================================================================

-- У кнопки НЕТ СОБСТВЕННОГО СОСТОЯНИЯ, и это намеренно.
--
-- Была версия со встроенным счётчиком нажатий: Counter = true, кнопка считала
-- сама и показывала число. Убрано -- счёт это прикладная логика, а не работа
-- элемента интерфейса. Сегодня счётчик нажатий, завтра таймер отката,
-- послезавтра «показывать только по чётным» -- и библиотека обрастает чужими
-- правилами, которых никто у неё не просил.
--
-- Кнопка умеет ровно две вещи: сообщить о нажатии и ПОКАЗАТЬ то, что ей дали.
-- Счётчик поверх этого пишется в три строки и остаётся там, где ему место:
--
--     local count = 0
--     local btn
--     btn = tab:Button({ Text = "CLICK", Callback = function()
--         count = count + 1
--         btn:SetValue(tostring(count))
--     end })
--
-- Сохранять такой счётчик или нет -- тоже решает вызывающий, своим Flag на том,
-- что действительно хранит значение.
NierUI.widget("Button", function(tab, opts)
    local row, _, value, _, _, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc)
    value.Text = opts.Value or ">"

    table.insert(tab.window.conns, row.MouseButton1Click:Connect(rowApi.gate(function()
        if not opts.Callback then return end
        local ok, err = pcall(opts.Callback)
        if not ok then warn("[NierUI] " .. tostring(opts.Text) .. ": " .. tostring(err)) end
    end)))

    if opts.Enabled == false then rowApi.setEnabled(false) end

    return {
        -- Единственный примитив показа: что писать в поле -- дело вызывающего.
        SetValue = function(_, text) value.Text = tostring(text) end,
        SetEnabled = function(_, on) rowApi.setEnabled(on) end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    }
end)

--== текст ===================================================================
--
-- Не строка в общем смысле: у него нет ни подсветки, ни значения, ни описания.
-- Поэтому makeRow тут не при чём, это просто подпись в потоке.

NierUI.widget("Label", function(tab, opts)
    tab.rows = tab.rows + 1
    local text = type(opts) == "table" and (opts.Text or "") or tostring(opts)

    local label = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = text, TextColor3 = THEME.InkSoft, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 18), LayoutOrder = tab.rows,
    }, tab.page)

    return {
        Set = function(_, v) label.Text = tostring(v) end,
        Get = function(_) return label.Text end,
    }
end)

NierUI.widget("Divider", function(tab)
    tab.rows = tab.rows + 1
    local holder = U.new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10),
        LayoutOrder = tab.rows,
    }, tab.page)
    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        BackgroundTransparency = 0.65, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1),
    }, holder)
    return holder
end)

end)(NierUI)

--============================ NierUI/widgets/Slider.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Slider -- число с дорожкой
--=============================================================================
--
-- Тянется мышью через события: нажали -- ведём, отпустили -- всё. Никакого
-- покадрового опроса, InputChanged приходит сам.
--
-- Дробные значения задаются через Step: Step = 0.05 даст два знака.

local UserInputService = game:GetService("UserInputService")

local THEME = NierUI.Theme
local U = NierUI.util

NierUI.widget("Slider", function(tab, opts)
    -- Значение сразу редактируемое: ползунком в 0.53 из 0.65 не попасть, при
    -- ста пикселях дорожки и диапазоне 0..1 один пиксель стоит целый сотый.
    local row, _, box, invert, _, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, "TextBox")

    local min = opts.Min or 0
    local max = opts.Max or 100
    local step = opts.Step or 1
    local suffix = opts.Suffix or ""
    local current = math.clamp(opts.Default or min, min, max)

    -- Сколько знаков показывать -- выводим из шага, а не из значения: иначе
    -- 0.30000000000000004 попадало бы в подпись как есть.
    local decimals = 0
    if step < 1 then
        decimals = math.max(0, math.ceil(-math.log(step, 10)))
    end
    local format = "%." .. decimals .. "f"

    -- Дорожка слева от числа, обе по центру ПЕРВОЙ строки: строка может
    -- вырасти, и центрирование по её высоте увело бы дорожку вниз.
    -- Дорожка задана долями (см. Theme): правым краем на TrackRight, шириной
    -- TrackFrac. Ограничитель держит её в разумных пределах -- на широкой
    -- странице она не растягивается бесконечно, на узкой не схлопывается в
    -- точку, по которой нечем попасть.
    local track = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        BackgroundTransparency = 0.75, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(THEME.TrackRight, 0, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.new(THEME.TrackFrac, 0, 0, 2), ZIndex = 3,
    }, row)
    U.new("UISizeConstraint", {
        MinSize = Vector2.new(36, 2), MaxSize = Vector2.new(110, 2),
    }, track)

    local fill = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
    }, track)

    -- Дорожка и заливка тоже чернильные, значит под курсором должны стать
    -- песочными -- иначе ползунок пропадает вместе с фоном строки.
    invert(track, "BackgroundColor3", THEME.Bg, THEME.Ink)
    invert(track, "BackgroundTransparency", 0.55, 0.75)
    invert(fill, "BackgroundColor3", THEME.Bg, THEME.Ink)

    local editing = false

    local function render()
        if not editing then
            box.Text = format:format(current) .. suffix
        end
        fill.Size = UDim2.fromScale((current - min) / (max - min), 1)
    end

    local function commit(v, silent)
        current = v
        render()
        if silent or not opts.Callback then return end
        pcall(opts.Callback, current)
    end

    -- Перетаскивание: притягиваем к шагу. Дорожка -- это сто пикселей, точнее
    -- шага по ней всё равно не попасть.
    local function set(v, silent)
        commit(math.clamp(math.floor(v / step + 0.5) * step, min, max), silent)
    end

    -- НАБОР РУКАМИ: зажим ТОЛЬКО по диапазону, к шагу НЕ притягиваем.
    --
    -- Иначе весь смысл теряется: при Step = 0.05 набранное 0.53 превращалось
    -- бы в 0.55 -- ровно то, ради чего поле и понадобилось, потому что
    -- ползунком в 0.53 не попасть.
    --
    -- Округляем до отображаемой точности, а не как попало: у целочисленного
    -- ползунка (Step = 1, знаков ноль) набранное 24.7 станет 25, а не осядет
    -- дробью там, где дробей быть не должно.
    local roundTo = 10 ^ decimals
    local function setTyped(v)
        local clamped = math.clamp(v, min, max)
        commit(math.floor(clamped * roundTo + 0.5) / roundTo)
    end

    --== приём только чисел ==================================================
    --
    -- Фильтруем ПО ХОДУ ввода, а не только при подтверждении: иначе человек
    -- набирает буквы, они видны, а на выходе молча превращаются в старое
    -- значение -- выглядит как проглоченный ввод.
    --
    -- Минус разрешаем только первым символом и только если диапазон вообще
    -- уходит в отрицательные; точку -- ровно одну.
    local allowNegative = min < 0

    local function sanitize(text)
        local out, dotSeen = {}, false
        for i = 1, #text do
            local ch = text:sub(i, i)
            if ch:match("%d") then
                out[#out + 1] = ch
            elseif ch == "." and not dotSeen then
                dotSeen = true
                out[#out + 1] = ch
            elseif ch == "-" and allowNegative and #out == 0 then
                out[#out + 1] = ch
            end
        end
        return table.concat(out)
    end

    table.insert(tab.window.conns, box:GetPropertyChangedSignal("Text"):Connect(function()
        if not editing then return end
        local clean = sanitize(box.Text)
        if clean ~= box.Text then box.Text = clean end
    end))

    table.insert(tab.window.conns, box.Focused:Connect(function()
        editing = true
        -- на время правки суффикс убираем: "0.65x" числом не разбирается
        box.Text = format:format(current)
    end))

    table.insert(tab.window.conns, box.FocusLost:Connect(function()
        editing = false
        local typed = tonumber(box.Text)
        if typed then
            setTyped(typed)
        else
            render()   -- пусто или мусор -- возвращаем прежнее
        end
    end))

    render()

    local sliding = false

    table.insert(tab.window.conns, row.InputBegan:Connect(rowApi.gate(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        -- Тянем, только если попали по дорожке. Иначе клик по названию строки
        -- швырял значение в минимум -- строка-то во всю ширину.
        local x = input.Position.X
        local left = track.AbsolutePosition.X - 8
        local right = left + track.AbsoluteSize.X + 16
        if x < left or x > right then return end

        sliding = true
        set(min + (max - min) * U.alongX(track, x))
    end)))

    table.insert(tab.window.conns, UserInputService.InputChanged:Connect(function(input)
        if not sliding then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        set(min + (max - min) * U.alongX(track, input.Position.X))
    end))

    table.insert(tab.window.conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end))

    if opts.Enabled == false then rowApi.setEnabled(false) end

    return NierUI.bind(tab, opts, {
        -- Set НЕ ПРИТЯГИВАЕТ К ШАГУ, как и набор руками.
        --
        -- Шаг существует ради перетаскивания: по стопиксельной дорожке точнее
        -- всё равно не попасть. Но программная установка и загрузка профиля --
        -- не перетаскивание, и притягивание там теряет данные: при шаге 1000
        -- сохранённые 65 возвращались как 0, а 500 -- как 1000. Значение,
        -- которое положили в профиль, обязано вернуться тем же.
        Set = function(_, v, silent)
            if silent then
                local clamped = math.clamp(tonumber(v) or min, min, max)
                current = math.floor(clamped * roundTo + 0.5) / roundTo
                render()
                return
            end
            setTyped(tonumber(v) or min)
        end,
        Get = function(_) return current end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Перетаскивание могло идти в момент выключения: без сброса
            -- ползунок продолжил бы ехать за мышью на недоступной строке.
            if not on then sliding = false end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)

end)(NierUI)

--============================ NierUI/widgets/Dropdown.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Dropdown и MultiDropdown
--=============================================================================
--
-- Одиночный и множественный отличаются ровно тремя вещами: что делает щелчок
-- по пункту, что написано в значении строки и закрывается ли список после
-- выбора. Всё остальное общее, поэтому конструктор ОДИН: две копии
-- разъехались бы на первой же правке.
--
--
-- ФОРМА ПУНКТА
--
--     "NAMES"                                     строка -- она же ключ и подпись
--     { Text = "Игрок", Key = 12345 }             подпись и ключ раздельно
--     { Text = ..., Key = ..., Settings = {...} } плюс свои настройки
--
-- Раздельные ключ и подпись нужны там, где подписи могут совпадать: два разных
-- объекта с одинаковым именем на строковом ключе склеились бы в один пункт.
--
--
-- ДИНАМИКА
--
--     dd:Refresh({ ... })   заменить набор пунктов целиком
--
-- Библиотека НЕ ЗНАЕТ, откуда берутся пункты и по какому поводу меняются. Кто
-- их поставляет, тот и решает, когда звать Refresh.
--
-- Выбор и настройки хранятся ПО КЛЮЧУ и переживают пересборку. Исчезнувший из
-- набора ключ не стирается: его просто некому показать, и в Get он не попадёт,
-- потому что Get идёт по текущим пунктам. Вернётся ключ -- вернётся и отметка.
-- Это осознанный выбор: стирать сразу значило бы терять настройку от любого
-- мигания источника. Кому нужна честная зачистка -- dd:Prune().
--
--
-- ЧЕКБОКСЫ -- ПРИЗНАК ТОЛЬКО МНОЖЕСТВЕННОГО. В одиночном выбран ровно один
-- пункт, и он написан в самой строке; ряд квадратиков там лишь притворялся бы,
-- что можно отметить несколько.

local THEME = NierUI.Theme
local U = NierUI.util

local function normalize(list)
    local entries = {}
    for _, item in ipairs(list or {}) do
        if type(item) == "table" then
            local key = item.Key
            if key == nil then key = item.Text end
            entries[#entries + 1] = {
                key = key,
                text = tostring(item.Text ~= nil and item.Text or key),
                settings = item.Settings,
            }
        else
            entries[#entries + 1] = { key = item, text = tostring(item) }
        end
    end
    return entries
end

local function build(tab, opts, multi)
    local row, _, value, _, setHeld, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc)
    local window = tab.window

    -- ДВА НАБОРА, И ЭТО ПРИНЦИПИАЛЬНО.
    --
    -- source -- всё, что есть; entries -- то, что сейчас видно после фильтра.
    -- Ответы Get и Prune идут ПО ПОЛНОМУ набору: иначе отфильтрованный список
    -- сообщал бы, что выбрано только видимое, а стоило стереть строку поиска --
    -- выбор «возвращался» бы. Выбор к фильтру отношения не имеет.
    local source = normalize(opts.Options)
    local entries = source
    local query = ""
    local open = false

    local chosen = {}
    local settings = {}

    local searchHeight = opts.Search and THEME.RowHeight or 0
    local panel, setPanel, setPanelHeight = NierUI.makePanel(row, 0)

    -- ШТАТНАЯ ПОЛОСА ПРОКРУТКИ ВЫКЛЮЧЕНА: она рисуется вплотную к правому краю
    -- и читалась заодно с границей блока. Нулевая толщина -- это нулевая ширина
    -- отрисовки, прокрутка при этом жива (ScrollingEnabled остаётся true, а
    -- VerticalScrollBarInset у нас None, колонка не резервируется).
    local list = U.new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, searchHeight),
        Size = UDim2.new(1, 0, 1, -1 - searchHeight),
        ZIndex = 30,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 0,
    }, panel)
    U.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)

    -- Указатель лежит в ПАНЕЛИ, а не в списке: дети списка едут вместе с
    -- содержимым, и он уезжал бы вместе с ними.
    local bar = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        BackgroundTransparency = 0.45, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(2, 0),
        ZIndex = 33, Visible = false,
    }, panel)

    --=========================================================================
    -- Состояние
    --=========================================================================

    -- Ответ всегда в порядке пунктов, а не в порядке щелчков: иначе один и тот
    -- же набор выглядел бы по-разному в зависимости от того, как его натыкали.
    local function picked()
        local out = {}
        for _, entry in ipairs(source) do
            if chosen[entry.key] then out[#out + 1] = entry.key end
        end
        return out
    end

    local function specFor(entry)
        if entry.settings then return entry.settings end
        return opts.Settings and opts.Settings[entry.key] or nil
    end

    -- Значения по умолчанию копируются в собственное хранилище: править сам
    -- spec нельзя, его может передать общая на несколько списков таблица.
    local function ensureSettings(entry)
        local spec = specFor(entry)
        if not spec then return nil end
        local store = settings[entry.key]
        if not store then
            store = {}
            settings[entry.key] = store
        end
        -- В состоянии лежит ЗНАЧЕНИЕ, а не описание: у ползунка описание
        -- содержит диапазон, а наружу и в профиль должно уходить число.
        for key, default in pairs(spec) do
            if store[key] == nil then store[key] = NierUI.settingDefault(default) end
        end
        return spec, store
    end

    local repaint = {}

    local function render()
        local sel = picked()
        if not multi then
            value.Text = sel[1] ~= nil and tostring(sel[1]) or "NONE"
        elseif #sel == 0 then
            value.Text = "NONE"
        elseif #sel == 1 then
            value.Text = tostring(sel[1])
        else
            -- Перечислять всё в стопиксельном поле бессмысленно, а рисовать
            -- обрезок с многоточием -- врать о содержимом. Число честнее.
            value.Text = ("%d SELECTED"):format(#sel)
        end
        for _, fn in ipairs(repaint) do fn() end
    end

    local function updateBar()
        local total = #entries * THEME.RowHeight
        if total == 0 then bar.Visible = false return end
        local view = list.AbsoluteSize.Y
        if view <= 0 or total <= view then
            bar.Visible = false
            return
        end
        bar.Visible = true

        local travel = view - 4
        local height = math.max(14, math.floor(travel * view / total))
        local maxScroll = total - view
        local progress = maxScroll > 0 and (list.CanvasPosition.Y / maxScroll) or 0
        bar.Size = UDim2.fromOffset(2, height)
        bar.Position = UDim2.new(1, -4, 0, 2 + math.floor((travel - height) * progress))
    end

    table.insert(window.conns,
        list:GetPropertyChangedSignal("CanvasPosition"):Connect(updateBar))

    local function setOpen(state)
        open = state
        setPanel(state)
        if not state then list.CanvasPosition = Vector2.zero end
        setHeld(state)          -- шапка подсвечена, пока блок раскрыт
        updateBar()
    end

    --=========================================================================
    -- Пункты
    --=========================================================================
    --
    -- КОННЕКТЫ ПУНКТОВ ЖИВУТ ОТДЕЛЬНО ОТ ОКОННЫХ, И ЭТО ГЛАВНОЕ ЗДЕСЬ.
    --
    -- Раньше каждый пункт складывал свои подписки в window.conns -- список на
    -- всё время жизни окна, который никогда не укорачивается. Для статичных
    -- двадцати пяти масок это незаметно. Для списка, который пересобирается на
    -- каждое изменение источника, это неограниченная утечка: за сессию набегут
    -- сотни коннектов, и каждый будет держать уничтоженную кнопку.
    --
    -- Ровно тот класс, на котором мы уже горели дважды. Поэтому свой список,
    -- и он гасится при каждой пересборке.

    local itemConns = {}

    local function clearItems()
        for _, c in ipairs(itemConns) do pcall(function() c:Disconnect() end) end
        table.clear(itemConns)
        table.clear(repaint)
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
    end

    local function makeItem(entry, index)
        local key = entry.key

        local item = U.new("TextButton", {
            BackgroundTransparency = 1, BorderSizePixel = 0,
            AutoButtonColor = false, Text = "",
            Size = UDim2.new(1, 0, 0, THEME.RowHeight),
            LayoutOrder = index, ZIndex = 31,
        }, list)

        local itemBg = U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
            BorderSizePixel = 0, Active = false,
            Size = UDim2.fromScale(1, 1), ZIndex = 31,
        }, item)

        local box, dot
        if multi then
            box = U.new("Frame", {
                BackgroundColor3 = THEME.Ink, BackgroundTransparency = 0.7,
                BorderSizePixel = 0, Active = false,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(9, 9),
                ZIndex = 33,
            }, item)
            dot = U.new("Frame", {
                BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
                BorderSizePixel = 0, Active = false,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(1, -4, 1, -4), ZIndex = 34,
            }, box)
        end

        local spec, store = ensureSettings(entry)

        -- Без квадратика текст начинается там же, где подписи строк, иначе
        -- одиночный список выглядел бы сдвинутым непонятно почему.
        local textX = multi and 24 or 10

        local text = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = entry.text, TextColor3 = THEME.Ink,
            TextSize = THEME.TextSize, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(textX, 0),
            Size = UDim2.new(1, -textX - (spec and 22 or 8), 1, 0), ZIndex = 33,
        }, item)

        -- Метка «у пункта есть настройки». Без неё правая кнопка -- знание,
        -- которое неоткуда взять: пункты выглядят одинаково.
        local gear
        if spec then
            gear = U.new("Frame", {
                BackgroundColor3 = THEME.Ink, BackgroundTransparency = 0.4,
                BorderSizePixel = 0, Active = false,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(5, 5),
                ZIndex = 33,
            }, item)
        end

        local hovered = false
        local function paint()
            local ink = hovered and THEME.Bg or THEME.Ink
            itemBg.BackgroundTransparency = hovered and 0 or 1
            text.TextColor3 = ink
            if gear then gear.BackgroundColor3 = ink end
            if box then
                box.BackgroundColor3 = ink
                dot.BackgroundColor3 = ink
                dot.BackgroundTransparency = chosen[key] and 0 or 1
            end
        end
        repaint[#repaint + 1] = paint

        table.insert(itemConns, item.MouseEnter:Connect(function()
            hovered = true
            paint()
        end))
        table.insert(itemConns, item.MouseLeave:Connect(function()
            hovered = false
            paint()
        end))

        table.insert(itemConns, item.MouseButton1Click:Connect(function()
            if multi then
                -- Список НЕ закрывается -- в этом весь смысл множественного:
                -- отметить пять штук, не открывая его пять раз.
                chosen[key] = (not chosen[key]) or nil
                render()
                if opts.Callback then pcall(opts.Callback, picked()) end
            else
                table.clear(chosen)
                chosen[key] = true
                render()
                setOpen(false)
                if opts.Callback then pcall(opts.Callback, key) end
            end
        end))

        if spec then
            table.insert(itemConns, item.MouseButton2Click:Connect(function()
                NierUI.optionSettings(window, item, entry.text, spec, store,
                    function(field, v)
                        if opts.OnSetting then pcall(opts.OnSetting, key, field, v) end
                    end)
            end))
        end
    end

    --=========================================================================
    -- Пересборка
    --=========================================================================

    local function layout()
        local visibleRows = math.min(#entries, opts.MaxVisible or THEME.DropdownMax)
        local total = #entries * THEME.RowHeight
        list.CanvasSize = UDim2.fromOffset(0, total)
        -- Строка поиска входит в высоту блока всегда, даже когда фильтр не
        -- нашёл ничего: иначе стереть запрос было бы негде.
        local body = visibleRows > 0 and (visibleRows * THEME.RowHeight + 1) or 0
        setPanelHeight(searchHeight + math.max(body, searchHeight > 0 and 1 or 0))
    end

    local function rebuild()
        local keepScroll = list.CanvasPosition
        clearItems()
        for index, entry in ipairs(entries) do makeItem(entry, index) end
        layout()
        render()
        -- Прокрутку возвращаем, но движок сам зажмёт её по новому полотну,
        -- если список стал короче.
        list.CanvasPosition = keepScroll
        updateBar()
    end

    --== поиск ===============================================================
    --
    -- Фильтр -- это пересборка подмножества, то есть тот же rebuild, что и у
    -- динамического списка. Отдельного механизма не понадобилось.

    -- Насколько далеко пускать: подпоследовательность («fuzzy») находит слишком
    -- многое, поэтому по умолчанию отрезаем на подстроке.
    local searchLimit = ({ prefix = 0, word = 1, substring = 2, fuzzy = 3 })[opts.Search] or 2

    local function refilter()
        if query == "" then
            entries = source
            rebuild()
            return
        end

        -- Сортируем находки, а не просто отбираем: совпадение в начале строки
        -- обязано стоять выше совпадения в середине слова, иначе список
        -- выглядит случайным. Порядок в source -- последний разделитель, чтобы
        -- одинаково хорошие находки не прыгали между наборами букв.
        local ranked = {}
        for index, entry in ipairs(source) do
            local score, at = U.matchScore(entry.text, query)
            if score and score <= searchLimit then
                ranked[#ranked + 1] = { entry = entry, score = score, at = at, order = index }
            end
        end

        table.sort(ranked, function(a, b)
            if a.score ~= b.score then return a.score < b.score end
            if a.at ~= b.at then return a.at < b.at end
            return a.order < b.order
        end)

        local found = {}
        for _, item in ipairs(ranked) do found[#found + 1] = item.entry end
        entries = found
        rebuild()
    end

    if opts.Search then
        local search = U.new("TextBox", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = "", PlaceholderText = "поиск",
            PlaceholderColor3 = THEME.Disabled,
            TextColor3 = THEME.Ink, TextSize = THEME.TextSize,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -20, 0, THEME.RowHeight), ZIndex = 31,
        }, panel)

        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
            BackgroundTransparency = 0.75,
            Position = UDim2.fromOffset(0, THEME.RowHeight - 1),
            Size = UDim2.new(1, 0, 0, 1), ZIndex = 31,
        }, panel)

        table.insert(window.conns, search:GetPropertyChangedSignal("Text"):Connect(function()
            query = search.Text
            refilter()
        end))

        -- Закрыли список -- сбрасываем запрос: иначе он откроется отфильтрованным
        -- и будет выглядеть наполовину пустым без видимой причины.
        table.insert(window.conns, panel:GetPropertyChangedSignal("Visible"):Connect(function()
            if panel.Visible or search.Text == "" then return end
            search.Text = ""
        end))
    end

    --== начальный выбор =====================================================

    if multi then
        for _, v in ipairs(opts.Default or {}) do chosen[v] = true end
    else
        local single = opts.Default
        if single == nil and entries[1] then single = entries[1].key end
        if single ~= nil then chosen[single] = true end
    end

    rebuild()

    -- Та же защита, что у палитры: раскрытая панель лежит ВНУТРИ строки, и
    -- щелчок по её пустому месту доходил бы до строки и схлопывал список.
    -- Пункты -- кнопки и щелчок съедают сами, а вот поля вокруг них нет.
    table.insert(window.conns, row.MouseButton1Click:Connect(rowApi.gate(function()
        if open and U.inside(panel, window.lastPress) then return end
        setOpen(not open)
    end)))

    --=========================================================================
    -- Наружу
    --=========================================================================

    local api = {
        Refresh = function(_, options)
            if options ~= nil then source = normalize(options) end
            refilter()
        end,

        Options = function(_)
            local out = {}
            for _, entry in ipairs(source) do out[#out + 1] = entry.key end
            return out
        end,

        -- Забыть выбор и настройки по ключам, которых больше нет в наборе.
        -- Отдельной командой, а не само: мигание источника не должно стирать
        -- то, что человек накрутил.
        Prune = function(_)
            local alive = {}
            for _, entry in ipairs(source) do alive[entry.key] = true end
            for key in pairs(chosen) do
                if not alive[key] then chosen[key] = nil end
            end
            for key in pairs(settings) do
                if not alive[key] then settings[key] = nil end
            end
            render()
        end,

        -- Через промежуточную переменную, а не `store and store[field] or nil`:
        -- у настроек бывают булевы значения, и false в такой записи молча
        -- превращается в nil. Выключенный флаг пункта читался как «нет такой
        -- настройки» -- и именно так он терялся после загрузки профиля.
        GetSetting = function(_, key, field)
            local store = settings[key]
            if not store then return nil end
            return store[field]
        end,
        SetSetting = function(_, key, field, v)
            local store = settings[key]
            if not store then return end
            store[field] = v
            -- Как и у строки: загрузка профиля применяет настройку, а не
            -- только запоминает.
            if opts.OnSetting then pcall(opts.OnSetting, key, field, v) end
        end,
        Settings = function(_, key)
            return settings[key]
        end,

        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Раскрытый список надо схлопнуть: иначе он останется висеть
            -- поверх соседних строк, а закрыть его будет уже нечем.
            if not on and open then setOpen(false) end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    }

    if multi then
        api.Get = function(_) return picked() end
        api.Set = function(_, values)
            table.clear(chosen)
            for _, v in ipairs(values or {}) do chosen[v] = true end
            render()
        end
        api.Has = function(_, key) return chosen[key] == true end
    else
        api.Get = function(_) return picked()[1] end
        api.Set = function(_, v)
            table.clear(chosen)
            if v ~= nil then chosen[v] = true end
            render()
        end
    end

    -- Настройки пунктов уезжают в конфиг вместе со значением: без них
    -- сохранённый белый список вернулся бы без цветов.
    api.SettingsMap = function(_) return settings end

    return NierUI.bind(tab, opts, api)
end

NierUI.widget("Dropdown", function(tab, opts) return build(tab, opts, false) end)
NierUI.widget("MultiDropdown", function(tab, opts) return build(tab, opts, true) end)

end)(NierUI)

--============================ NierUI/widgets/InputText.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- InputText -- строка ввода
--=============================================================================
--
--     tab:InputText({ Text = "WEBHOOK", Placeholder = "https://...",
--                     MaxLength = 200, Flag = "webhook",
--                     Callback = function(text) end,   -- по завершении ввода
--                     Changed  = function(text) end }) -- по ходу набора
--
-- Единственная дыра в наборе примитивов, которая оставалась: ввод у нас был,
-- но приколоченный -- числовой внутри ползунка и hex внутри палитры. Поле как
-- самостоятельный элемент отсутствовало, а без него не построить ничего, где
-- нужны ники, ссылки или произвольные имена.
--
--
-- ШИРИНА ФИКСИРОВАННАЯ, А НЕ ПО СОДЕРЖИМОМУ
--
-- У ползунка поле растёт по числу: там оно короткое и предсказуемое. Здесь
-- наоборот -- текст произвольной длины, и растущее поле уползло бы влево прямо
-- под подпись строки. Поэтому ширина задана долей, а лишнее обрезается
-- прокруткой самого TextBox.

local THEME = NierUI.Theme
local U = NierUI.util

NierUI.widget("InputText", function(tab, opts)
    local row, _, box, _, _, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc, "TextBox")

    box.AutomaticSize = Enum.AutomaticSize.None
    box.Size = UDim2.new(opts.Width or 0.42, 0, 0, THEME.RowHeight)
    box.ClearTextOnFocus = false
    box.Text = tostring(opts.Default or "")
    box.PlaceholderText = tostring(opts.Placeholder or "")
    box.PlaceholderColor3 = THEME.InkSoft

    -- Ограничитель ширины из каркаса рассчитан на короткое число; здесь он
    -- только мешал бы доле.
    local limit = box:FindFirstChildOfClass("UISizeConstraint")
    if limit then limit:Destroy() end

    local maxLength = opts.MaxLength
    local current = box.Text

    table.insert(tab.window.conns, box:GetPropertyChangedSignal("Text"):Connect(function()
        -- Обрезаем ПО ХОДУ набора, а не при завершении: иначе человек печатает,
        -- видит текст, а на выходе часть молча исчезает.
        if maxLength and #box.Text > maxLength then
            box.Text = box.Text:sub(1, maxLength)
            return
        end
        if box.Text == current then return end
        current = box.Text
        if opts.Changed then pcall(opts.Changed, current) end
    end))

    table.insert(tab.window.conns, box.FocusLost:Connect(function()
        current = box.Text
        if opts.Callback then pcall(opts.Callback, current) end
    end))

    if opts.Enabled == false then rowApi.setEnabled(false) end

    return NierUI.bind(tab, opts, {
        SetEnabled = function(_, on) rowApi.setEnabled(on) end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
        Get = function(_) return box.Text end,
        Set = function(_, text, silent)
            box.Text = tostring(text or "")
            current = box.Text
            if silent or not opts.Callback then return end
            pcall(opts.Callback, current)
        end,
    })
end)

end)(NierUI)

--============================ NierUI/widgets/Keybind.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Keybind -- привязка клавиши
--=============================================================================
--
-- Пока ждём нажатие, строка держится подсвеченной: иначе непонятно, что меню
-- вообще чего-то ждёт. Ровно тот же setHeld, что держит раскрытый список.

local UserInputService = game:GetService("UserInputService")

NierUI.widget("Keybind", function(tab, opts)
    local row, _, value, _, setHeld, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc)

    local key = opts.Default
    local listening = false

    local function render()
        value.Text = listening and "[ ... ]" or (key and key.Name or "NONE")
    end
    render()

    table.insert(tab.window.conns, row.MouseButton1Click:Connect(rowApi.gate(function()
        listening = true
        setHeld(true)
        render()
    end)))

    -- Глобальная подписка тоже под воротами: у выключенной привязки не должна
    -- срабатывать ни сама клавиша, ни ожидание новой.
    table.insert(tab.window.conns, UserInputService.InputBegan:Connect(rowApi.gate(function(input, processed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        if listening then
            listening = false
            setHeld(false)
            -- Escape отменяет назначение, а не назначает Escape.
            if input.KeyCode ~= Enum.KeyCode.Escape then
                key = input.KeyCode
                -- Со следующего кадра, а не сразу: нажатие, которым клавишу
                -- назначают, ещё расходится по остальным подписчикам этого же
                -- события, и настроенная прямо здесь привязка сработала бы от
                -- него же. Порядок обработчиков в Roblox не определён, поэтому
                -- вопрос снимается отложенным вызовом, а не расстановкой
                -- подписок.
                if opts.Changed then
                    local captured = key
                    task.defer(function() pcall(opts.Changed, captured) end)
                end
            end
            render()
            return
        end

        if processed or not key or input.KeyCode ~= key then return end
        if opts.Callback then pcall(opts.Callback, key) end
    end)))

    if opts.Enabled == false then rowApi.setEnabled(false) end

    return NierUI.bind(tab, opts, {
        -- Set ВЫЗЫВАЕТ Changed, иначе загрузка профиля показывала бы новую
        -- клавишу, а работала бы старая: тот, кто на Changed настраивает
        -- реальную привязку, о смене просто не узнал бы.
        Set = function(_, k, silent)
            key = k
            render()
            if silent or not opts.Changed then return end
            pcall(opts.Changed, key)
        end,
        Get = function(_) return key end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Ждали нажатие в момент выключения -- ожидание надо снять, иначе
            -- строка останется подсвеченной навсегда.
            if not on and listening then
                listening = false
                setHeld(false)
                render()
            end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)

end)(NierUI)

--============================ NierUI/widgets/Choice.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Radio и Segmented -- выбор без сворачивания в строку
--=============================================================================
--
--     tab:Radio({ Text = "MODE", Options = { "A", "B", "C" }, Default = "A" })
--     tab:Segmented({ Text = "SPEED", Options = { "LOW", "MID", "HIGH" } })
--
-- Оба про одно и то же -- выбрать один вариант из немногих, -- и различаются
-- только формой. Radio занимает строку на вариант и читается с одного взгляда;
-- Segmented умещается в одну строку и годится там, где места мало: в колонке
-- или в половинной ячейке блока.
--
-- Когда вариантов больше пяти-шести, оба проигрывают Dropdown: он сворачивается
-- и умеет прокрутку.

local THEME = NierUI.Theme
local U = NierUI.util

--=============================================================================
-- Radio
--=============================================================================

NierUI.widget("Radio", function(tab, opts)
    local options = opts.Options or {}
    local current = opts.Default
    if current == nil then current = options[1] end

    if opts.Text then tab:Label({ Text = opts.Text }) end

    local rows, painters = {}, {}

    local function render(silent)
        for _, paint in ipairs(painters) do paint() end
        if silent or not opts.Callback then return end
        pcall(opts.Callback, current)
    end

    for _, option in ipairs(options) do
        local row, _, value, _, _, rowApi =
            NierUI.makeRow(tab, tostring(option), opts.Desc)

        painters[#painters + 1] = function()
            value.Text = current == option and "[ o ]" or "[   ]"
        end

        table.insert(tab.window.conns, row.MouseButton1Click:Connect(rowApi.gate(function()
            if current == option then return end
            current = option
            render()
        end)))

        rows[#rows + 1] = rowApi
    end

    render(true)

    if opts.Enabled == false then
        for _, rowApi in ipairs(rows) do rowApi.setEnabled(false) end
    end

    return NierUI.bind(tab, opts, {
        Get = function(_) return current end,
        Set = function(_, v, silent) current = v render(silent) end,
        SetEnabled = function(_, on)
            for _, rowApi in ipairs(rows) do rowApi.setEnabled(on) end
        end,
        IsEnabled = function(_) return rows[1] and rows[1].isEnabled() or false end,
    })
end)

--=============================================================================
-- Segmented
--=============================================================================
--
-- Кнопки занимают правую часть строки -- от той же доли, где у ползунка
-- начинается дорожка, до правого края. Ширина делится поровну, поэтому
-- сегменты остаются одинаковыми и в узкой колонке.

NierUI.widget("Segmented", function(tab, opts)
    local row, _, value, _, _, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc)
    value.Text = ""

    local options = opts.Options or {}
    local current = opts.Default
    if current == nil then current = options[1] end

    local left = THEME.TrackRight - THEME.TrackFrac
    local span = 1 - left
    local count = math.max(#options, 1)
    local share = span / count

    -- ЧЕТЫРЕ СОЧЕТАНИЯ, А НЕ ДВА.
    --
    -- Вид сегмента зависит и от выбора, и от подсветки строки. Простой инверсии
    -- тут мало: она подставляет пару значений, а нам нужно решать. Без этого
    -- сегменты оставались чернильными на чернильном фоне подсвеченной строки и
    -- попросту сливались с ней.
    --
    --     не выбран, строка обычная   -- чернильный контур на песке
    --     не выбран, строка подсвечена-- песочный контур на чернилах
    --     выбран,   строка обычная    -- залит чернилами, текст песочный
    --     выбран,   строка подсвечена -- залит песком, текст чернильный
    local painters = {}
    local rowHot = false

    local function render(silent)
        for _, paint in ipairs(painters) do paint() end
        if silent or not opts.Callback then return end
        pcall(opts.Callback, current)
    end

    rowApi.onPaint(function(hot)
        rowHot = hot
        for _, paint in ipairs(painters) do paint() end
    end)

    for index, option in ipairs(options) do
        local segment = U.new("TextButton", {
            BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false,
            Font = THEME.Font, Text = tostring(option),
            TextColor3 = THEME.Ink, TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(left + share * (index - 1), 1,
                0, math.floor(THEME.RowHeight / 2)),
            Size = UDim2.new(share, -12, 0, THEME.RowHeight - 8),
            ZIndex = 3,
        }, row)
        local line = U.stroke(segment, 1)

        painters[#painters + 1] = function()
            local on = current == option
            -- Цвет «чернил» и «песка» меняются местами, когда строка подсвечена.
            local ink = rowHot and THEME.Bg or THEME.Ink
            local paper = rowHot and THEME.Ink or THEME.Bg

            segment.BackgroundColor3 = ink
            segment.BackgroundTransparency = on and 0 or 1
            segment.TextColor3 = on and paper or ink
            line.Color = ink
            line.Transparency = on and 1 or 0.5
        end

        table.insert(tab.window.conns, segment.MouseButton1Click:Connect(rowApi.gate(function()
            if current == option then return end
            current = option
            render()
        end)))
    end

    render(true)

    if opts.Enabled == false then rowApi.setEnabled(false) end

    return NierUI.bind(tab, opts, {
        Get = function(_) return current end,
        Set = function(_, v, silent) current = v render(silent) end,
        SetEnabled = function(_, on) rowApi.setEnabled(on) end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)

end)(NierUI)

--============================ NierUI/widgets/Progress.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Progress -- полоса выполнения
--=============================================================================
--
--     local bar = tab:Progress({ Text = "LOADING", Default = 0 })
--     bar:Set(0.42)                 доля от нуля до единицы
--     bar:Set(0.42, "42 / 100")     своя подпись вместо процентов
--
-- Только показывает. Ничего не считает и ни на что не подписывается: чем
-- заполнять -- дело вызывающего. Это осознанно, иначе полосе пришлось бы знать
-- про источник данных, а библиотека такого не знает нигде.

local THEME = NierUI.Theme
local U = NierUI.util

NierUI.widget("Progress", function(tab, opts)
    local row, _, value, invert = NierUI.makeRow(tab, opts.Text, opts.Desc)

    -- Геометрия как у дорожки ползунка -- те же доли, поэтому полоса и ползунок
    -- в соседних строках стоят вровень.
    local track = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        BackgroundTransparency = 0.8, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(THEME.TrackRight, 0, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.new(THEME.TrackFrac, 0, 0, 4), ZIndex = 3,
    }, row)
    U.new("UISizeConstraint", {
        MinSize = Vector2.new(36, 4), MaxSize = Vector2.new(110, 4),
    }, track)

    local fill = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
    }, track)

    invert(track, "BackgroundColor3", THEME.Bg, THEME.Ink)
    invert(fill, "BackgroundColor3", THEME.Bg, THEME.Ink)

    local current = math.clamp(tonumber(opts.Default) or 0, 0, 1)
    local caption = nil

    local function render()
        fill.Size = UDim2.fromScale(current, 1)
        value.Text = caption or ("%d%%"):format(math.floor(current * 100 + 0.5))
    end
    render()

    return NierUI.bind(tab, opts, {
        Get = function(_) return current end,
        Set = function(_, fraction, text)
            current = math.clamp(tonumber(fraction) or 0, 0, 1)
            caption = text
            render()
        end,
    })
end)

end)(NierUI)

--============================ NierUI/widgets/ColorPicker.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- ColorPicker -- строка с палитрой
--=============================================================================
--
-- Сама палитра живёт в NierUI.colorControl и здесь только встраивается: тот же
-- контрол используется во всплывающем окне настроек пункта списка. Держать две
-- копии этой геометрии значило бы получить через месяц две разные палитры.

local THEME = NierUI.Theme
local U = NierUI.util

local FIELD_HEIGHT = 100
-- место под HEX-строку берём у самого контрола, а не подгоняем числом
local PANEL_HEIGHT = FIELD_HEIGHT + NierUI.colorControlExtra + 20

NierUI.widget("ColorPicker", function(tab, opts)
    local row, _, value, invert, setHeld, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc)
    local window = tab.window

    -- Образец встаёт по той же доле, что и дорожка ползунка (см. Theme):
    -- жёсткий отступ от правого края не пережил бы половинной ширины ячейки.
    local swatch = U.new("Frame", {
        BackgroundColor3 = opts.Default or Color3.fromRGB(255, 40, 40),
        BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(THEME.TrackRight, 0, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.fromOffset(28, 12), ZIndex = 3,
    }, row)
    local swatchLine = U.stroke(swatch, 1)
    -- Обводка образца обязана инвертироваться: чернильная рамка на чернильном
    -- фоне под курсором исчезла бы, и образец повис бы в воздухе.
    invert(swatchLine, "Color", THEME.Bg, THEME.Ink)

    local panel, setPanel = NierUI.makePanel(row, PANEL_HEIGHT)

    local control = NierUI.colorControl(panel, {
        Position = UDim2.fromOffset(12, 10),
        Width = 0, Height = FIELD_HEIGHT,
        Color = opts.Default,
        sink = window.conns,
        ZIndex = 30,
        Callback = function(c)
            swatch.BackgroundColor3 = c
            value.Text = U.hex(c)
            if opts.Callback then pcall(opts.Callback, c) end
        end,
    })
    -- ширину контрол берёт от родителя, оставляем поля по краям; высоту не
    -- трогаем -- он сам знает про свою HEX-строку
    control.instance.Size = UDim2.new(1, -24, 0, FIELD_HEIGHT + NierUI.colorControlExtra)

    value.Text = U.hex(control.Get())

    -- ЩЕЛЧОК ВНУТРИ РАСКРЫТОЙ ПАНЕЛИ НЕ ЗАКРЫВАЕТ СТРОКУ.
    --
    -- Active = true на панели и на квадрате оказалось НЕ достаточно: панель
    -- лежит внутри самой строки, а не поверх неё, и нажатие по палитре всё
    -- равно доходило до строки-кнопки. Выбор цвета схлопывал палитру на
    -- отпускании -- ровно то, что уже чинили однажды сторожем «сейчас тянем».
    --
    -- Тот сторож я потом убрал, посчитав мёртвым по рассуждению, а не по
    -- замеру, -- и вернул поломку. Теперь проверка не про перетаскивание, а
    -- про место: MouseButton1Click координат не несёт, поэтому окно помнит
    -- точку последнего нажатия. Это ловит и простой щелчок без движения, чего
    -- прежний сторож не умел.
    local open = false
    table.insert(window.conns, row.MouseButton1Click:Connect(rowApi.gate(function()
        if open and U.inside(panel, window.lastPress) then return end
        open = not open
        setPanel(open)
        setHeld(open)
    end)))

    if opts.Enabled == false then rowApi.setEnabled(false) end

    return NierUI.bind(tab, opts, {
        Get = function(_) return control.Get() end,
        Set = function(_, c, silent) control.Set(c, silent) end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Образец цвета гасим вручную: он не текст, и общее приглушение
            -- подписей до него не достаёт.
            swatch.BackgroundTransparency = on and 0 or 0.6
            if not on and open then
                open = false
                setPanel(false)
                setHeld(false)
            end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)

end)(NierUI)

return NierUI
