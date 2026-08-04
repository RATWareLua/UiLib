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

-- THEME здесь больше не нужен: вся геометрия дорожки -- в каркасе строки.
local U = NierUI.util

NierUI.widget("Slider", function(tab, opts)
    -- Значение сразу редактируемое: ползунком в 0.53 из 0.65 не попасть, при
    -- ста пикселях дорожки и диапазоне 0..1 один пиксель стоит целый сотый.
    local row, _, box, invert, _, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, "TextBox", opts)

    local min = opts.Min or 0
    local max = opts.Max or 100
    local step = opts.Step or 1
    local suffix = opts.Suffix or ""
    local current = math.clamp(opts.Default or min, min, max)

    -- Вырожденный диапазон -- не ошибка вызывающего, а обычное следствие
    -- данных: Min и Max нередко считаются из чего-то, что в этот момент пусто.
    -- Делить на него нельзя: (current-min)/(max-min) даёт nan, а nan в
    -- UDim2.fromScale роняет отрисовку. Полоса при этом честно стоит пустой.
    local span = (max > min) and (max - min) or 1

    -- Сколько знаков показывать -- выводим из шага, а не из значения: иначе
    -- 0.30000000000000004 попадало бы в подпись как есть.
    local decimals = 0
    if step < 1 then
        decimals = math.max(0, math.ceil(-math.log(step, 10)))
    end
    local format = "%." .. decimals .. "f"

    -- Дорожка слева от числа. Геометрия, ограничитель и инверсия -- в каркасе
    -- (см. NierUI.makeTrack): полоса выполнения строит ровно то же самое, и две
    -- копии этих долей однажды разъехались бы. Своего здесь только толщина и то,
    -- что под курсором дорожка светлеет: её, в отличие от полосы, тянут.
    local track, fill = NierUI.makeTrack(row, invert, 2, 0.75, 0.55)

    local editing = false

    local function render()
        if not editing then
            box.Text = format:format(current) .. suffix
        end
        fill.Size = UDim2.fromScale((current - min) / span, 1)
    end

    local function commit(v, silent)
        current = v
        render()
        NierUI.fire(opts, silent, current)
    end

    -- Перетаскивание: притягиваем к шагу. Дорожка -- это сто пикселей, точнее
    -- шага по ней всё равно не попасть.
    --
    -- СЕТКА ОТСЧИТЫВАЕТСЯ ОТ MIN, А НЕ ОТ НУЛЯ.
    --
    -- Раньше было floor(v/step + 0.5)*step -- сетка от нуля, независимо от
    -- диапазона. При Min = 5, Step = 10 она давала 0, 10, 20: само значение 5,
    -- с которого ползунок начинается, перетаскиванием было недостижимо, а левый
    -- край дорожки после зажима прилипал к 5 и не двигался до середины. Любой
    -- диапазон, чей Min не кратен шагу, вёл себя так же.
    local function set(v, silent)
        commit(math.clamp(
            min + math.floor((v - min) / step + 0.5) * step, min, max), silent)
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
    local function setTyped(v, silent)
        local clamped = math.clamp(v, min, max)
        commit(math.floor(clamped * roundTo + 0.5) / roundTo, silent)
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

    NierUI.connect(tab, box:GetPropertyChangedSignal("Text"), function()
        if not editing then return end
        local clean = sanitize(box.Text)
        if clean ~= box.Text then box.Text = clean end
    end)

    NierUI.connect(tab, box.Focused, function()
        editing = true
        -- на время правки суффикс убираем: "0.65x" числом не разбирается
        box.Text = format:format(current)
    end)

    NierUI.connect(tab, box.FocusLost, function()
        editing = false
        local typed = tonumber(box.Text)
        if typed then
            setTyped(typed)
        else
            render()   -- пусто или мусор -- возвращаем прежнее
        end
    end)

    render()

    local sliding = false

    NierUI.connect(tab, row.InputBegan, rowApi.gate(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        -- Тянем, только если попали по дорожке. Иначе клик по названию строки
        -- швырял значение в минимум -- строка-то во всю ширину.
        local x = input.Position.X
        local left = track.AbsolutePosition.X - 8
        local right = left + track.AbsoluteSize.X + 16
        if x < left or x > right then return end

        sliding = true
        set(min + span * U.alongX(track, x))
    end))

    NierUI.connect(tab, UserInputService.InputChanged, function(input)
        if not sliding then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        set(min + span * U.alongX(track, input.Position.X))
    end)

    NierUI.connect(tab, UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)

    return NierUI.bind(tab, opts, {
        -- Set НЕ ПРИТЯГИВАЕТ К ШАГУ, как и набор руками.
        --
        -- Шаг существует ради перетаскивания: по стопиксельной дорожке точнее
        -- всё равно не попасть. Но программная установка и загрузка профиля --
        -- не перетаскивание, и притягивание там теряет данные: при шаге 1000
        -- сохранённые 65 возвращались как 0, а 500 -- как 1000. Значение,
        -- которое положили в профиль, обязано вернуться тем же.
        --
        -- Тишина уходит вторым аргументом в тот же setTyped. Здесь стояла её
        -- отдельная ветка -- зажать, округлить, перерисовать, -- то есть второй
        -- путь к тому же самому: разойтись двум округлениям достаточно одной
        -- правки в одном из них.
        Set = function(_, v, silent) setTyped(tonumber(v) or min, silent) end,
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
