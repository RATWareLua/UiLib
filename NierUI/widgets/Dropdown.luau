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

    -- SET ОБЯЗАН СООБЩИТЬ О СМЕНЕ, как это делают все остальные элементы.
    --
    -- Список был единственным, кто молчал, и стоило это вот чего: загрузка
    -- профиля расставляла галочки, а тот, кто на них подписан, о смене не
    -- узнавал. В меню отмечено, на деле выключено -- расхождение, которое
    -- глазами не поймать, потому что интерфейс показывает правду о себе и
    -- неправду о происходящем.
    --
    -- Тишина по-прежнему доступна вторым аргументом -- ею пользуются, когда
    -- значение ставят изнутри и обработчик уже отработал.
    local function notify(value, silent)
        if silent or not opts.Callback then return end
        local ok, err = pcall(opts.Callback, value)
        if not ok then warn("[NierUI] " .. tostring(opts.Text) .. ": " .. tostring(err)) end
    end

    if multi then
        api.Get = function(_) return picked() end
        api.Set = function(_, values, silent)
            table.clear(chosen)
            for _, v in ipairs(values or {}) do chosen[v] = true end
            render()
            -- Наружу отдаём picked(), а не values: он идёт в порядке пунктов и
            -- не содержит ключей, которых в наборе нет.
            notify(picked(), silent)
        end
        api.Has = function(_, key) return chosen[key] == true end
    else
        api.Get = function(_) return picked()[1] end
        api.Set = function(_, v, silent)
            table.clear(chosen)
            if v ~= nil then chosen[v] = true end
            render()
            notify(v, silent)
        end
    end

    -- Настройки пунктов уезжают в конфиг вместе со значением: без них
    -- сохранённый белый список вернулся бы без цветов.
    api.SettingsMap = function(_) return settings end

    return NierUI.bind(tab, opts, api)
end

NierUI.widget("Dropdown", function(tab, opts) return build(tab, opts, false) end)
NierUI.widget("MultiDropdown", function(tab, opts) return build(tab, opts, true) end)
