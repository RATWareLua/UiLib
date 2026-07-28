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
