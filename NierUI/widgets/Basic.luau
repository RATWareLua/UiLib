--!nocheck
--=============================================================================
-- Toggle, Button, Label, Divider
--=============================================================================

local THEME = NierUI.Theme
local U = NierUI.util

--== переключатель ===========================================================

NierUI.widget("Toggle", function(tab, opts)
    local row, _, value, _, _, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)
    local state = opts.Default and true or false

    -- Привязки-взаимодействия. Заводятся ниже, но гасить их надо отсюда, а
    -- объявление в Lua наверх не смотрит.
    local gated = {}

    local function render()
        value.Text = state and "[ ON ]" or "[ OFF ]"
    end
    render()

    local function set(on, silent)
        state = on and true or false
        render()

        -- ВОРОТА ЗАКРЫЛИСЬ -- ВСЁ, ЧТО ЗА НИМИ, ГАСНЕТ БЕЗУСЛОВНО.
        --
        -- Строка -- мастер-свитч: выключили функцию, значит взаимодействия с
        -- ней не просто перестают слушать клавишу, а уходят в OFF. Оставить их
        -- включёнными значило бы оставить включённым то, до чего больше не
        -- дотянуться ничем.
        --
        -- ДО обратного вызова: вызывающий в нём сворачивает саму функцию, и
        -- узнать о том, что взаимодействия погасли, он должен раньше, а не
        -- после того, как сворачивать уже нечего.
        if not state then
            for _, bind in ipairs(gated) do bind:Shut() end
        end

        NierUI.fire(opts, silent, state)

        -- СООБЩАЕМ ПОСЛЕ ОБРАТНОГО ВЫЗОВА, А НЕ ДО.
        --
        -- Обратный вызов -- часть применения смены: именно в нём вызывающий
        -- дописывает то, что от неё зависит. Сообщи мы раньше -- подписчик
        -- увидел бы промежуточное состояние и отстал ровно на одно действие.
        --
        -- Поймано на менеджере привязок: тумблер «показывать» ставит свой
        -- признак в Callback, а список перерисовывался до этого -- и прятал
        -- строку только со второго щелчка.
        --
        -- Сообщаем и при silent: он гасит обратный вызов ВЫЗЫВАЮЩЕГО, а не
        -- осведомлённость самого меню. Иначе загрузка профиля меняла бы всё
        -- молча, и список привязок врал бы до первого щелчка руками.
        NierUI.stateChanged(tab.window)
    end

    NierUI.connect(tab, row.MouseButton1Click, rowApi.gate(function()
        set(not state)
    end))

    --== ПРИВЯЗКИ ============================================================
    --
    --     Bind  = true | Enum.KeyCode.F      РУБИЛЬНИК: переключает эту строку
    --     Binds = { {...}, {...} }           ВЗАИМОДЕЙСТВИЯ: работают с функцией
    --
    -- Разные поля, потому что разные цели, а не потому что разное количество.
    -- Рубильник один и целится в строку; взаимодействий сколько угодно, и строка
    -- для них -- ворота. См. шапку Binds.
    local all = {}

    if opts.Bind ~= nil or opts.Binds then
        if opts.Settings then
            error(("[NierUI] у строки «%s» и привязка, и Settings: правая "
                .. "кнопка одна, а открывать пришлось бы двоих. Переложите "
                .. "настройки в Menu -- там доступны все виджеты.")
                :format(tostring(opts.Text or "?")), 0)
        end
    end

    if opts.Bind ~= nil then
        -- Состояния ядру НЕ ОТДАЁМ -- отдаём пару функций до него. set здесь тот
        -- же самый, что зовёт щелчок мышью, поэтому нажатие клавиши и щелчок по
        -- строке буквально неразличимы: один код, одно уведомление, одна правда.
        all[#all + 1] = tab.window.binds:Add({
            Flag = opts.Flag, Kind = opts.Kind, Enabled = opts.Enabled,
            ChangeModeInGame = opts.ChangeModeInGame,
            Key = typeof(opts.Bind) == "EnumItem" and opts.Bind or nil,
            row = row, rowTitle = opts.Text,
            get = function() return state end,
            set = function(on) set(on) end,
        })
    end

    --== СПИСКА ПОЛЕЙ ЗДЕСЬ БОЛЬШЕ НЕТ =======================================
    --
    -- Стояло переписывание по именам: Text, Flag, Key, Kind, Enabled, Toggle,
    -- Action, ChangeModeInGame. То есть ровно тот слой перевода, которого, как
    -- сказано в шапке Binds, «нет нигде», -- и вёл он себя как положено слою
    -- перевода: новое поле ядра надо было не забыть дописать сюда.
    --
    -- Забыли на первом же. State доезжал через win:Bind и терялся МОЛЧА у
    -- привязки, объявленной на строке: ядро не видело его вовсе и заводило
    -- привязке своё состояние. Внешне -- та самая ложь, ради которой State и
    -- заводился: [ON] при пустом захвате.
    --
    -- Копия, а не сама spec: таблицу дал вызывающий, и дописывать в неё своё
    -- значит однажды вернуть ему её изменённой.
    for _, spec in ipairs(opts.Binds or {}) do
        local decl = table.clone(spec)
        -- Подпись собирается из двух: строчной и своей. Своей нет -- останется
        -- строчная, и это верно: одна привязка на строке и есть эта строка.
        decl.row, decl.rowTitle = row, opts.Text
        -- ВОРОТА -- состояние строки, читается КАЖДЫЙ раз. Копией здесь была бы
        -- вторая правда о том же факте.
        decl.gate = function() return state end

        local extra = tab.window.binds:Add(decl)
        all[#all + 1] = extra
        gated[#gated + 1] = extra
    end

    -- Своё меню строим САМИ и одним построителем: редакторы ядра сверху, то,
    -- что дописал вызывающий, -- под ними. См. makeRow.
    if #all > 0 then
        rowApi.menu(tab, opts.MenuTitle or opts.Text, function(menu)
            NierUI.bindRows(menu, all)
            if opts.Menu then
                menu:Divider()
                opts.Menu(menu)
            end
        end, opts.MenuWidth)
    end

    -- Настройки по правой кнопке подключает КАРКАС, а пару Get/SetSetting
    -- дописывает воронка в containerIndex. Переключателю для этого не надо
    -- делать ничего -- как и любой другой строке, чего от него и добивались.
    return NierUI.bind(tab, opts, {
        -- Клавиши, режимы и подписи уезжают в профиль вместе со значением
        -- строки, а не отдельными флагами: это настройки ОДНОГО пункта меню.
        binds = all,

        Set = function(_, on, silent) set(on, silent) end,
        Get = function(_) return state end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Недоступная строка не должна отзываться и на клавишу: иначе она
            -- выглядит выключенной, а работает. Касается ВСЕХ её привязок --
            -- и рубильника, и взаимодействий.
            for _, b in ipairs(all) do b:SetEnabled(on) end
        end,
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
    local row, label, value, _, _, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)
    value.Text = opts.Value or ">"

    NierUI.connect(tab, row.MouseButton1Click, rowApi.gate(function()
        NierUI.fire(opts, false)
    end))

    -- ПРИВЯЗКА У КНОПКИ -- ДЕЙСТВИЕ. Состояния у неё нет и быть не может:
    -- нажали -- сработало, удерживать и переключать нечего. В списке привязок
    -- у такой написано [BUTTON], а не [OFF] -- отключённой она не бывает.
    local bind
    if opts.Bind ~= nil then
        bind = tab.window.binds:Add({
            Flag = opts.Flag, Enabled = opts.Enabled, row = row,
            rowTitle = opts.Text,
            Key = typeof(opts.Bind) == "EnumItem" and opts.Bind or nil,
            Action = opts.Callback,
        })
        rowApi.menu(tab, opts.MenuTitle or opts.Text, function(menu)
            NierUI.bindRows(menu, { bind })
            if opts.Menu then
                menu:Divider()
                opts.Menu(menu)
            end
        end, opts.MenuWidth)
    end

    return NierUI.bind(tab, opts, {
        binds = bind and { bind } or nil,

        -- Единственный примитив показа: что писать в поле -- дело вызывающего.
        SetValue = function(_, text) value.Text = tostring(text) end,
        -- Подпись меняется наравне со значением: полезно там, где строка
        -- показывает что-то, что может смениться на ходу.
        SetText = function(_, text) label.Text = tostring(text) end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Недоступная строка не должна отзываться и на клавишу: иначе она
            -- выглядит выключенной, а работает.
            if bind then bind:SetEnabled(on) end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
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
        -- Подписи каркас строки не касается вовсе, поэтому доступность у неё
        -- своя и делает единственное, что для подписи осмысленно, -- бледнеет.
        -- Пара всё равно нужна: она обещана всем обработчикам, и тот, кто гасит
        -- группу строк разом, не должен разбирать, что среди них подпись.
        SetEnabled = function(_, on)
            label.TextColor3 = on ~= false and THEME.InkSoft or THEME.Disabled
        end,
        IsEnabled = function(_) return label.TextColor3 ~= THEME.Disabled end,
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
