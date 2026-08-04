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
-- значат, что один затрёт другой при загрузке, а найти это потом почти нечем.

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
-- `or {}`, а не пустая таблица: методы сюда кладут и части, загруженные РАНЬШЕ
-- окна (ядро привязок с его менеджером). Присвоение пустой затирало бы их
-- молча, и метод просто не находился бы -- при том, что файл на месте.
NierUI.containerMethods = NierUI.containerMethods or {}

--=============================================================================
-- СТОК КОННЕКТОВ -- У КОНТЕЙНЕРА, А НЕ У ОКНА
--=============================================================================
--
-- Виджеты писали подписки прямо в window.conns. Для вкладки это верно: она
-- живёт столько же, сколько окно, и гаснет вместе с ним в Destroy.
--
-- Но список этот НИКОГДА НЕ УКОРАЧИВАЕТСЯ, и стоит контейнеру стать временным,
-- как это перестаёт быть верным. Список пунктов уже наступил на это
-- однажды: он пересобирается на каждое изменение источника, и его подписки
-- пришлось уводить в собственный itemConns -- вручную, отдельным механизмом,
-- потому что общего не было.
--
-- Меню правой кнопки наступит на это второй раз и куда сильнее: ползунок кладёт
-- туда три подписки, палитра две, и каждое открытие меню добавляло бы их
-- заново, навсегда, вместе со ссылками на уничтоженные объекты.
--
-- Поэтому у контейнера есть свой сток. Нет своего -- берётся у окна, и для
-- вкладки, блока и секции ничего не меняется. Появился временный контейнер --
-- он заводит свой список и гасит его при закрытии, а виджеты об этом не знают
-- вовсе: они и так не знают, куда их кладут.

function NierUI.sink(container)
    return container.conns or container.window.conns
end

function NierUI.connect(container, signal, fn)
    local conn = signal:Connect(fn)
    table.insert(NierUI.sink(container), conn)
    return conn
end

--=============================================================================
-- «У МЕНЯ ИЗМЕНИЛОСЬ» -- СООБЩАЕТ ТОТ, У КОГО ИЗМЕНИЛОСЬ
--=============================================================================
--
-- Список привязок показывает чужое состояние: включён ли тумблер, которому
-- принадлежит клавиша. Узнать о его смене можно двумя способами, и один из них
-- негодный.
--
-- Негодный -- спрашивать по таймеру. Он был здесь написан, и это прямое
-- нарушение того, на чём стоит вся библиотека: ничего не работает, пока ничего
-- не происходит. Опрос работает ВСЕГДА, в том числе когда не меняется ничего,
-- и ради одной строки на экране заводит постоянную нагрузку.
--
-- Годный -- сообщать. Тумблер и так знает момент, когда его переключили: он
-- ровно там зовёт свой Callback. Пусть заодно скажет и окну.
--
-- Подписчиков немного и живут они столько же, сколько окно, поэтому список
-- простой.


function NierUI.onStateChange(window, fn)
    table.insert(window.stateWatchers, fn)
    return fn
end

--=============================================================================
-- ЗАХВАТ КЛАВИШИ переехал в ядро привязок (см. Binds).
--=============================================================================
--
-- Спрашивают его именно привязки, и второго счётчика на это быть не должно:
-- NierUI.keyGrabbed объявлен там же, где живёт сам счётчик. Парного ему
-- «взвести снаружи» больше нет вовсе -- взводит его Capture и только он.

--=============================================================================
-- «У МЕНЯ ИЗМЕНИЛОСЬ» -- ЕДИНСТВЕННЫЙ КАНАЛ
--=============================================================================
--
-- Ядро привязок состоянием НЕ ВЛАДЕЕТ -- владеет тот, чью пару get/set ему
-- отдали, то есть строка меню. Значит и о смене состояния сообщает он же, вот
-- этим самым вызовом, которым и так сообщал.
--
-- Поэтому сообщение переправляется подписчикам ядра: у списка привязок и
-- менеджера остаётся ОДНА подписка -- на ядро, -- а не две, из которых вторую
-- однажды забудут снять. bind = nil означает «поимённо не знаем, пересоберись».
function NierUI.stateChanged(window)
    if not window then return end

    if window.stateWatchers then
        for _, fn in ipairs(window.stateWatchers) do pcall(fn) end
    end

    local core = rawget(window, "binds")
    if core then core:notify(nil, "state") end
end

function NierUI.containerIndex(class)
    return function(self, key)
        local own = rawget(class, key)
        if own then return own end

        local shared = NierUI.containerMethods[key]
        if shared then return shared end

        local builder = NierUI.widgets[key]
        if builder then
            -- ЕДИНСТВЕННАЯ ВОРОНКА, ЧЕРЕЗ КОТОРУЮ ПРОХОДИТ КАЖДЫЙ ВИДЖЕТ.
            --
            -- Здесь и только здесь известны разом три вещи: имя виджета, его
            -- настройки и готовый handle. Поэтому пометки ставятся тут, а не в
            -- двадцати местах: новый виджет получает их просто потому, что он
            -- виджет.
            return function(_, opts)
                opts = opts or {}
                local handle = builder(self, opts)

                if type(handle) == "table" then
                    -- ПРИВЯЗКА ДАРОМ НЕ ДОСТАЁТСЯ, И МОЛЧАТЬ ОБ ЭТОМ НЕЛЬЗЯ.
                    --
                    -- Каркас строки читает Bind и Binds ровно для одного --
                    -- понять, что меню строит виджет сам (см. makeRow). Саму
                    -- запись заводит виджет: ядру нужна пара get/set до его
                    -- состояния, а что считать состоянием, знает только он.
                    --
                    -- Значит виджет, который эти поля не разбирает, получал бы
                    -- их МОЛЧА: привязки нет, в списке пусто, клавиша ничего не
                    -- делает -- и вдобавок пропало собственное меню строки,
                    -- потому что каркас решил, что виджет построит его сам.
                    --
                    -- Проверяем здесь: только тут известны разом и настройки, и
                    -- готовый handle. Признак -- поле binds: кто привязки
                    -- поддерживает, тот его выставляет всегда, пусть и пустым.
                    if (opts.Bind ~= nil or opts.Binds ~= nil)
                        and rawget(handle, "binds") == nil then
                        error(("[NierUI] %s не умеет привязок, а ему передали "
                            .. "Bind/Binds -- строка «%s». Их разбирают Toggle, "
                            .. "Button и Keybind; своему виджету заведите запись "
                            .. "сами через window.binds:Add и верните её в поле "
                            .. "binds."):format(key, tostring(opts.Text or "?")), 0)
                    end

                    -- kind нужен списку привязок, чтобы отличить Keybind от
                    -- всего остального, text -- чтобы было чем подписать строку.
                    if handle.kind == nil then handle.kind = key end
                    if handle.text == nil and type(opts) == "table" then
                        handle.text = opts.Text
                    end

                    -- МЕНЮ УЗНАЁТ СВОЕГО ВЛАДЕЛЬЦА ТОЛЬКО ЗДЕСЬ.
                    --
                    -- Строится оно внутри makeRow, то есть ДО того, как виджет
                    -- вернул handle: в тот момент владельца ещё не существует.
                    -- Знать его надо списку привязок -- клавиша, объявленная в
                    -- меню тумблера ПОЛЁТ, включена ровно тогда, когда включён
                    -- сам ПОЛЁТ.
                    local pending = rawget(self, "pendingMenu")
                    if pending then
                        pending.owner = handle
                        -- Ссылка на меню нужна и наружу: динамический список
                        -- пересобирает свои строки, и меню снесённой строки
                        -- надо снести вместе с ней -- иначе контейнеры меню
                        -- копились бы на окне без всякой связи с видимым.
                        handle.menu = pending
                        self.pendingMenu = false
                    end

                    -- НАСТРОЙКИ СТРОКИ -- ТОЖЕ ЗДЕСЬ, И ПО ТОЙ ЖЕ ПРИЧИНЕ.
                    --
                    -- Каркас строит их в makeRow, то есть ДО того, как виджет
                    -- вернул handle, а в профиль они уходят именно через него.
                    -- Раньше пару Get/SetSetting выписывал у себя переключатель
                    -- -- единственный, кто вообще звал настройки. Повторять это
                    -- в каждом виджете значит однажды забыть очередной, чем и
                    -- кончилось: у ползунка, палитры, списка и поля ввода поле
                    -- Settings не работало вовсе.
                    local extra = rawget(self, "pendingSettings")
                    if extra then
                        local state, onChange = extra.state, extra.onChange
                        self.pendingSettings = false

                        -- SettingsFlat: у строки уровень один, а у списка
                        -- настройки разложены по пунктам. См. Config.
                        handle.SettingsFlat = true
                        handle.SettingsMap = function() return state end
                        handle.GetSetting = function(_, field) return state[field] end
                        handle.SetSetting = function(_, field, value)
                            state[field] = value
                            -- Загрузка профиля обязана ПРИМЕНИТЬ настройку, а не
                            -- только запомнить: иначе меню показывает новое
                            -- значение, а работает старое.
                            if onChange then pcall(onChange, field, value) end
                        end
                    end
                end

                return handle
            end
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
        -- ЯДРО ПРИВЯЗОК. Заводится пустым и подписок на ввод не создаёт, пока
        -- не объявлена первая привязка: у меню без них обработчиков ввода не
        -- появляется вовсе. Ставится ниже, сразу после setmetatable -- ядру
        -- нужно само окно, а его в этой таблице ещё нет.
        binds = false,
        -- Разбор нажатия правой кнопки один на всё окно, а не по подписке на
        -- каждый элемент: пока открыто всплывающее окно, его фон-перехватчик
        -- забирает правую кнопку себе и до элементов она не доходит. См.
        -- Context.
        m2 = {},
        popupInput = false,
        -- Контейнеры меню правой кнопки. Их содержимое живёт на стоянке в gui,
        -- а подписки -- в собственных стоках, до которых оконный Destroy сам не
        -- достаёт. Поэтому список: снять надо каждый.
        panels = {},
        -- Кому сообщать, что состояние виджета сменилось.
        --
        -- Список привязок здесь больше не сидит: он подписан на ядро, а ядру
        -- это сообщение переправляет stateChanged. Список остаётся ради тех,
        -- кому нужна смена состояния ВИДЖЕТА, а не привязки.
        stateWatchers = {},
        -- Отложенное на конец постройки. Виджеты добавляются ПОСЛЕ того, как
        -- окно вернулось, поэтому всё, чему нужен полный их список -- менеджер
        -- привязок, мастер-профиль, -- ждёт здесь.
        deferred = {},
        -- Перехватчик щелчков ОДИН на всю стопку всплывающих окон, а не по
        -- одному на окно. См. Popup.
        popupShade = false,
        -- Где какое окно настроек стояло в прошлый раз. Живёт столько же,
        -- сколько окно, и в профиль не идёт: положение панели -- это привычка
        -- рук на один сеанс, а не настройка, которую хотят получить обратно
        -- через неделю на другом мониторе.
        popupPlaces = {},
        flags = {},
        noSave = {},
        notifyLayer = false,
        notifications = {},
        triggerSeq = 0,
        -- Папку конфигов задаёт ТОЛЬКО вызывающий. Выводить её из заголовка
        -- окна нельзя: заголовок меняется по вкусу, и каждая его правка
        -- оставляла бы на диске новую папку с осиротевшими профилями.
        configFolder = opts.ConfigFolder or false,

        -- МАСТЕР-ПРОФИЛЬ: какой набор настроек поднимать при каждом запуске.
        --
        -- false означает не «нет мастера», а «в коде не назван» -- тогда имя
        -- берётся из файла рядом с профилями, куда его кладёт SetMaster. Так
        -- назначить главный профиль можно из самого меню, не трогая скрипт.
        --
        -- AutoLoad = false выключает подъём целиком: он нужен тому, кто грузит
        -- профиль сам и в свой момент.
        master = opts.MasterProfile or false,
        autoMaster = opts.AutoLoad ~= false,

        -- Перехват ввода на время, пока меню открыто. По умолчанию включён:
        -- меню, по которому нельзя щёлкнуть в бою, бесполезно.
        captureInput = opts.CaptureInput ~= false,
        captured = false,
        -- Исходное состояние мыши хранится НЕ здесь, а на библиотеке, и
        -- снимается один раз за сеанс: копия на окно записывала бы не исходное
        -- значение, а следы предыдущего окна -- в том числе такого, которое
        -- умерло, не убравшись за собой. См. Capture.
        captureAction = false,

        -- Свой указатель вместо системного. См. Cursor: системный в бою не
        -- показывается, сколько его ни включай.
        drawCursor = opts.Cursor ~= false,
        cursor = false,
        cursorParts = false,
        cursorOn = false,
        cursorConns = false,
        current = false,
        -- Заводится ЗАКРЫТЫМ и открывается в конце конструктора через Toggle.
        --
        -- Раньше здесь стояло true, а Toggle не звался вовсе: окно оказывалось
        -- видимым, но БЕЗ перехвата ввода и без своего указателя -- и то и
        -- другое живёт только внутри Toggle. Курсора нет, щелчки уходят в игру,
        -- а первое нажатие клавиши открытия меню ПРЯЧЕТ. Проходить через один
        -- и тот же путь надёжнее, чем повторять его половину в конструкторе.
        visible = false,
        -- Точка последнего нажатия. MouseButton1Click координат не несёт, а
        -- отличать нажатие по строке от нажатия внутри её раскрытой панели
        -- необходимо: раскрытая панель лежит ВНУТРИ строки, и щелчок по
        -- палитре доходил до строки и схлопывал её.
        lastPress = Vector2.zero,
        toggleKey = opts.ToggleKey or Enum.KeyCode.Delete,
    }, Window)

    -- Ядру нужно окно, поэтому не в таблице выше, а сразу после неё. Раньше
    -- этой строки привязок не существует, и NierUI.keyGrabbed честно отвечает
    -- «никто не ждёт»: он читает ядро через rawget и отсутствие переносит.
    self.binds = NierUI.bindCore(self)

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

        -- ПРАВАЯ КНОПКА РАЗБИРАЕТСЯ ЗДЕСЬ, А НЕ НА ЭЛЕМЕНТЕ, И ДО ПРОВЕРКИ
        -- processed.
        --
        -- Фон-перехватчик всплывающего окна поглощает щелчок целиком, поэтому
        -- на элементе MouseButton2Click при открытом окне не срабатывает вовсе
        -- -- ни на той же строке, ни на любой другой. Отсюда и невозможность
        -- открыть настройки двух пунктов рядом. UserInputService нажатие
        -- получает в любом случае, а кому оно предназначалось, считает Context.
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            if self.visible then NierUI.contextDispatch(self, input.Position) end
            return
        end

        if processed then return end
        -- Строка ждёт клавишу -- нажатие принадлежит ЕЙ. Иначе назначение
        -- клавиши открытия закрывало бы окно тем же самым нажатием, которым её
        -- назначают, и увидеть результат было бы уже негде.
        if NierUI.keyGrabbed(self) then return end
        if input.KeyCode == self.toggleKey then self:Toggle() end

    end))

    -- Открываем через тот же путь, которым пользуется клавиша: вместе с окном
    -- поднимаются перехват ввода и указатель. Visible = false заводит окно
    -- спрятанным -- скрипту, который показывает меню сам, это удобнее, чем
    -- моргнуть им при загрузке.
    self:Toggle(opts.Visible ~= false)

    -- Мастер-профиль поднимается ПОСЛЕ того, как вызывающий закончил постройку.
    --
    -- Прямо здесь его поднимать бессмысленно: окно возвращается пустым, вкладки
    -- и виджеты добавляются следующими строками, и в реестре флагов пока пусто
    -- -- применять было бы нечего. task.defer ждёт ровно до конца текущего
    -- потока, без опроса и без таймера.
    -- ПОРЯДОК ЗДЕСЬ ВАЖЕН: сперва достраиваем, потом применяем профиль.
    --
    -- Менеджер привязок заводит по тумблеру на каждую привязку, и у них есть
    -- флаги. Примени мы профиль раньше -- этих флагов в реестре ещё нет, и
    -- сохранённые значения достались бы некому. Одна отложенная задача на всё,
    -- а не по одной на каждого: две задачи не дают никакого порядка между собой.
    task.defer(function()
        if not self.gui or not self.gui.Parent then return end
        -- Ошибку здесь НЕ ГЛОТАЕМ молча. Отложенное строит настоящие строки
        -- меню, и упавший построитель выглядит как «раздела просто нет» -- ни
        -- ошибки, ни намёка, где искать. Одна отвалившаяся часть при этом не
        -- должна утаскивать за собой остальные, поэтому pcall с жалобой.
        for _, fn in ipairs(self.deferred) do
            local ok, err = pcall(fn)
            if not ok then warn("[NierUI] отложенная постройка: " .. tostring(err)) end
        end
        table.clear(self.deferred)
        if self.autoMaster then pcall(self.LoadMaster, self) end
    end)

    return self
end

function Window:Hint(text)
    self.desc.Text = text or ""
end

--=============================================================================
-- ПРИВЯЗКА БЕЗ СТРОКИ
--=============================================================================
--
--     win:Bind({ Text = "СНЯТЬ ВСЁ", Flag = "panic", Key = Enum.KeyCode.G,
--                Action = unloadAll })
--
-- Привязка, у которой нет ни строки, ни ворот: показывать нечего и гасить
-- нечему. Годится и Toggle -- тогда состояние своё, как у взаимодействия, --
-- но воротами ей никто не управляет, потому что мастер-свитча над ней нет.
--
-- Делегат в одну строку, а не второй способ объявить: набор полей тот же самый,
-- что у Core.Add, и перевода имён между ними нет.
function Window:Bind(opts)
    return self.binds:Add(opts or {})
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

    -- Ядро привязок: отменить ожидание нажатия и отпустить удержания. Сами
    -- подписки лежат в self.conns и гаснут ниже вместе со всеми, но залипшее
    -- ЗАЖАТИЕ они не отпустят -- отпускание придёт в подписку, которой уже нет.
    if self.binds then self.binds:Destroy() end
    -- Перехват ввода надо снять обязательно: он живёт в сервисах, а не в нашем
    -- дереве, и уничтожение ScreenGui его не отпустит -- курсор остался бы
    -- висеть, а управление в игре не вернулось бы вовсе.
    if self.StopCapture then self:StopCapture() end

    -- Контейнеры меню держат подписки в своих стоках, а не в оконном -- гасим
    -- каждый явно. Стоянки лежат в gui и ушли бы с ним, но подписки нет.
    --
    -- ОБХОД ПО КОПИИ, А НЕ ПО ЖИВОМУ СПИСКУ. Panel.Destroy вычёркивает себя
    -- отсюда же, и ipairs по списку, который под ним укорачивается,
    -- ПЕРЕСКАКИВАЕТ ЧЕРЕЗ СОСЕДА: из {A,B,C} уничтожались A и C, а B оставался
    -- жив -- и тут же терялся, потому что следом список чистится целиком.
    --
    -- Цена была не косметическая. У пропущенной панели остаются висеть её
    -- глобальные подписки на ввод, а cleanups не зовутся вовсе -- то есть
    -- счётчик кадров ПРОДОЛЖАЕТ считать каждый кадр после сноса окна. Ровно
    -- тот вечный поток, ради отсутствия которого написана вся библиотека.
    for _, panel in ipairs(table.clone(self.panels)) do
        pcall(function() panel:Destroy() end)
    end
    table.clear(self.panels)

    for _, conn in ipairs(self.conns) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(self.conns)
    self.popupInput = false
    self.popupShade = false
    table.clear(self.popupPlaces)
    -- Реестр правой кнопки держит СИЛЬНЫЕ ссылки на элементы (слабые ключи по
    -- Instance в Lua не работают так, как хочется, -- см. README), поэтому
    -- чистится руками, как и всё остальное.
    table.clear(self.m2)
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
        -- Своего стока у вкладки нет: она живёт столько же, сколько окно, и
        -- заводить ей отдельный список значило бы гасить его ровно тогда же,
        -- когда гаснет оконный. false -- «беру у окна», см. NierUI.sink.
        conns = false,
        -- Владелец: у вкладки его нет. Есть у меню правой кнопки -- это строка,
        -- из которой оно открыто (см. воронку в containerIndex).
        owner = false,
        pendingMenu = false,
        pendingSettings = false,
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
