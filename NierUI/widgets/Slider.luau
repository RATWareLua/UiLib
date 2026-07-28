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
        Set = function(_, v, silent) set(v, silent) end,
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
