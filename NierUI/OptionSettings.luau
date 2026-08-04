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
--     Settings = { ["ЗНАЧЕНИЕ"] = { Type = "Slider", Default = 1000,
--                                   Min = 1, Max = 999999, Step = 1 } }
--
-- Русское имя настройки -- ТОЛЬКО через ["..."]. Ключ без скобок разбирается как
-- идентификатор, а идентификаторы в Luau только из латиницы: { Цвет = ... } не
-- компилируется вовсе. Имя настройки человек видит в окошке, поэтому русские
-- имена тут дело обычное, и форма у них ровно такая.
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

-- ПАРАМЕТРЫ ТАБЛИЦЕЙ, А НЕ ПОЗИЦИЯМИ
--
-- Их стало восемь, и позиционный список из восьми штук читается только со
-- счётом на пальцах -- а впереди ещё расширение меню правой кнопки, где их
-- станет больше. Вызывающих всего двое, переучивать некого.
--
--   Anchor   -- от какого элемента отсчитывать положение
--   Title    -- заголовок окошка
--   Spec     -- ключ -> значение по умолчанию
--   State    -- ключ -> текущее значение (меняется на месте)
--   OnChange -- function(key, value)
--   OnClose  -- зовётся, когда окно закрылось ЛЮБЫМ путём: щелчком мимо,
--               Escape, повторной правой кнопкой или ClosePopups. Без него тот,
--               кто держит ссылку на окно, считал бы его открытым вечно.
--   Place    -- ключ памяти положения. ДОЛЖЕН ПЕРЕЖИВАТЬ САМ ЭЛЕМЕНТ: пункты
--               списка пересобираются на каждую букву в поиске, и ключом по
--               кнопке память терялась бы ровно тогда, когда она нужна.
function NierUI.optionSettings(window, opts)
    local spec, state = opts.Spec, opts.State
    local anchor = opts.Anchor
    local onChange = opts.OnChange

    local keys = {}
    for key in pairs(spec) do keys[#keys + 1] = key end
    table.sort(keys)
    if #keys == 0 then return end

    -- ВЫСОТА ЗАЖИМАЕТСЯ ПО ЭКРАНУ, ОСТАЛЬНОЕ УХОДИТ В ПРОКРУТКУ.
    --
    -- Раньше она считалась как TOP + числом настроек, и только. Popup держит в
    -- пределах экрана ПОЛОЖЕНИЕ, но не размер, поэтому два десятка настроек
    -- давали окно выше экрана: нижние строки просто негде было показать, и
    -- добраться до них было нечем.
    local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        or Vector2.new(1920, 1080)

    local content = #keys * ROW + 8
    local room = math.max(ROW * 3, view.Y - 40 - TOP)
    local height = TOP + math.min(content, room)

    -- Взведённые захваты клавиши этого окна: строка -> чем отпустить.
    --
    -- Нужны здесь, а не в самой строке, потому что окно могут закрыть ПРЯМО ВО
    -- ВРЕМЯ ожидания -- щелчком мимо, Escape, закрытием родителя. Подписки
    -- строки уходят вместе с окном, и отпустить захват стало бы некому: признак
    -- остался бы взведённым навсегда, а с ним перестали бы работать и клавиша
    -- открытия меню, и все привязки разом.
    local grabs = {}

    local panel, close, conns, z, entry = window:Popup({
        Title = opts.Title,
        Width = WIDTH,
        Height = height,
        X = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + 6,
        Y = anchor.AbsolutePosition.Y,
        OnClose = function()
            for _, release in pairs(grabs) do release() end
            table.clear(grabs)
            if opts.OnClose then opts.OnClose() end
        end,
        Place = opts.Place,
    })

    -- Строки лежат в прокрутке, а не в самой панели: полоса заголовка обязана
    -- остаться на месте, за неё окно таскают.
    local body = U.new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Active = true,
        Position = UDim2.fromOffset(0, TOP),
        Size = UDim2.new(1, 0, 1, -TOP),
        CanvasSize = UDim2.fromOffset(0, content),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = THEME.Ink,
        ScrollBarImageTransparency = 0.4,
        ZIndex = z,
    }, panel)

    for index, key in ipairs(keys) do
        local y = (index - 1) * ROW

        local rowBtn = U.new("TextButton", {
            BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false, Text = "",
            Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, ROW),
            ZIndex = z,
        }, body)

        local label = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = tostring(key), TextColor3 = THEME.Ink,
            TextSize = THEME.TextSize, TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -110, 1, 0),
            ZIndex = z + 1,
        }, rowBtn)

        local descriptor = spec[key]
        local isSlider = type(descriptor) == "table" and descriptor.Type == "Slider"

        -- ВИД СТРОКИ РЕШАЕТ ОБЪЯВЛЕНИЕ, А НЕ ТЕКУЩЕЕ ЗНАЧЕНИЕ.
        --
        -- Раньше ветка выбиралась по тому, что лежит в состоянии, -- и стоило
        -- клавише оттуда пропасть, как настройка меняла тип на глазах: снятая
        -- клавиша (false) превращала строку в переключатель. Тип объявлен один
        -- раз и не меняется, значит и спрашивать надо объявление.
        local declared = NierUI.settingDefault(descriptor)

        local current = state[key]
        if current == nil then current = declared end

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

        elseif typeof(declared) == "Color3" then
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
                    -- Палитра -- РЕБЁНОК этих настроек, и это не украшение:
                    -- по родству решается, что закрывать щелчком. Щелчок в
                    -- настройках убирает палитру, но не их самих; щелчок в
                    -- палитре не трогает ничего; настройки соседнего пункта не
                    -- задеваются ни тем ни другим.
                    Owner = panel,
                    -- Палитре память положения нужна ровно как и самим
                    -- настройкам: её тоже отодвигают, чтобы видеть строку,
                    -- которую красят. Ключ -- от родителя плюс имя поля, чтобы
                    -- две палитры одного окна не делили одно место на двоих.
                    Place = opts.Place and (opts.Place .. "\0c\0" .. tostring(key)) or nil,
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

        elseif typeof(declared) == "EnumItem" then
            -- СНЯТАЯ КЛАВИША ХРАНИТСЯ КАК false, А НЕ КАК nil.
            --
            -- nil означает «не задано», и такую настройку в профиле нечем
            -- отличить от несохранённой: кодек её просто не увидит, а при
            -- загрузке вернётся объявленное умолчание -- то есть снятая клавиша
            -- воскресала бы на каждом запуске. false -- обычное значение, оно
            -- переживает и JSON, и загрузку. Тот же приём, что и во всём
            -- остальном состоянии библиотеки.
            local function keyName()
                local v = state[key]
                return typeof(v) == "EnumItem" and v.Name or "NONE"
            end

            -- Захват клавиши. Пока ждём нажатие, строка помечена и подсвечена:
            -- иначе непонятно, что окно чего-то ждёт.
            local value = U.new("TextLabel", {
                BackgroundTransparency = 1, Font = THEME.Font,
                Text = keyName(), TextColor3 = THEME.InkSoft,
                TextSize = THEME.TextSize,
                TextXAlignment = Enum.TextXAlignment.Right,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -10, 0, 0),
                Size = UDim2.fromOffset(110, ROW), ZIndex = z + 1,
            }, rowBtn)

            -- Чем отпустить ожидание. false -- не ждём ничего.
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

            -- ЖДЁМ НАЖАТИЕ ЧУЖИМИ РУКАМИ.
            --
            -- Здесь стояла вторая копия этого танца -- взвести захват,
            -- дождаться клавиши, отменить по Escape, применить со следующего
            -- кадра, -- и она успела разойтись с первой: принимала только
            -- Enum.KeyCode (то есть мышиную настройку молча превращала в
            -- клавиатурную) и снимать привязку не умела вовсе.
            --
            -- Теперь ожидание одно на всю библиотеку и живёт в ядре (см. Binds).
            -- Оттуда же пришло то, чего не было ни в одной копии: ждущий ВСЕГДА
            -- ОДИН. Открыл настройки двух пунктов, щёлкнул клавишу в обоих --
            -- прежнее ожидание отменяется, а не назначается вместе с новым.
            table.insert(conns, rowBtn.MouseButton1Click:Connect(function()
                if listening then return end
                -- Пока ждём клавишу, Escape принадлежит НАМ: им отменяют
                -- назначение. Без этой пометки одно нажатие делало две работы
                -- разом -- отменяло захват и закрывало окно, -- и увидеть, что
                -- отмена сработала, было уже негде.
                entry.holdEscape = true

                listening = window.binds:Capture(function(captured)
                    listening = false
                    grabs[rowBtn] = nil
                    -- Отпускаем Escape СО СЛЕДУЮЩЕГО КАДРА: порядок обработчиков
                    -- одного события в Roblox не определён, и сними мы пометку
                    -- здесь, сторож окна прочитал бы её уже снятой и закрылся
                    -- от того же самого нажатия.
                    task.defer(function() entry.holdEscape = false end)

                    -- Backspace приходит сюда как nil -- клавиши нет. Отмена по
                    -- Escape сюда не доходит вовсе (см. Core.Capture), поэтому
                    -- nil означает ровно снятие и ничего больше.
                    --
                    -- Раньше здесь стояло «применяем, только если не nil»: снять
                    -- настройку было нельзя ничем, кроме правки кода, при том что
                    -- Backspace честно обещал обратное.
                    state[key] = captured or false

                    value.Text = keyName()
                    paint()

                    if onChange then pcall(onChange, key, state[key]) end
                end)

                grabs[rowBtn] = listening
                value.Text = "[ ... ]"
                paint()
            end))

        elseif type(declared) == "boolean" then
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
