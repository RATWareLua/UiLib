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

    -- ПРАВОЙ КНОПКИ У НЕГО НЕТ, И ЭТО НЕ УПУЩЕНИЕ.
    --
    -- Radio -- не строка, а НЕСКОЛЬКО строк плюс подпись над ними, и вешать
    -- меню не на что: на подпись -- она не строка вовсе, на каждый вариант --
    -- получится по меню на вариант, чего никто не просил. Сказать об этом
    -- вслух надо потому, что молча поля Menu и Settings просто не делали
    -- ничего, а понять это можно было только по тому, что ничего не
    -- происходит. Нужны настройки при выборе из немногих -- Segmented: он
    -- занимает ровно одну строку, и правая кнопка у него своя.
    if opts.Menu or opts.Settings then
        error(("[NierUI] «%s»: у Radio нет правой кнопки -- он занимает "
            .. "несколько строк, и вешать меню не на что. Возьмите Segmented "
            .. "или Dropdown."):format(tostring(opts.Text or "?")), 0)
    end

    if opts.Text then tab:Label({ Text = opts.Text }) end

    local rows, painters = {}, {}

    local function render(silent)
        for _, paint in ipairs(painters) do paint() end
        NierUI.fire(opts, silent, current)
    end

    for _, option in ipairs(options) do
        local row, _, value, _, _, rowApi =
            NierUI.makeRow(tab, tostring(option), opts.Desc)

        painters[#painters + 1] = function()
            value.Text = current == option and "[ o ]" or "[   ]"
        end

        NierUI.connect(tab, row.MouseButton1Click, rowApi.gate(function()
            if current == option then return end
            current = option
            render()
        end))

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
    local row, _, value, _, _, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)
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
        NierUI.fire(opts, silent, current)
    end

    -- Строка перерисовалась -- перерисовываем сегменты, и ничего больше:
    -- render(true) -- это ровно «пройтись по художникам молча». Свой цикл здесь
    -- был вторым путём к тому же самому.
    rowApi.onPaint(function(hot)
        rowHot = hot
        render(true)
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

        NierUI.connect(tab, segment.MouseButton1Click, rowApi.gate(function()
            if current == option then return end
            current = option
            render()
        end))
    end

    render(true)

    return NierUI.bind(tab, opts, {
        Get = function(_) return current end,
        Set = function(_, v, silent) current = v render(silent) end,
        SetEnabled = function(_, on) rowApi.setEnabled(on) end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)
