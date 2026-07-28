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
        name = opts.Name or opts.Title or "NierUI",
        current = false,
        visible = true,
        -- Точка последнего нажатия. MouseButton1Click координат не несёт, а
        -- отличать нажатие по строке от нажатия внутри её раскрытой панели
        -- необходимо: раскрытая панель лежит ВНУТРИ строки, и щелчок по
        -- палитре доходил до строки и схлопывал её.
        lastPress = Vector2.zero,
        toggleKey = opts.ToggleKey or Enum.KeyCode.Delete,
    }, Window)

    local width = opts.Width or THEME.WindowWidth
    local height = opts.Height or THEME.WindowHeight

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
end

function Window:Destroy()
    -- Всплывающие окна и уведомления живут своей жизнью на ScreenGui, гасим их
    -- первыми: у уведомлений вдобавок висят отложенные задержки, которым иначе
    -- достались бы уже уничтоженные объекты.
    if self.ClosePopups then self:ClosePopups() end
    if self.ClearNotifications then self:ClearNotifications() end

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
