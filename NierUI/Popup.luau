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
-- нажатие мимо окна не проваливалось в меню под ним. Правую кнопку она тоже
-- поглощает, и разделить их у GuiButton нечем -- поэтому правая обрабатывается
-- на уровне окна, минуя дерево (см. Context).
--
--
--=============================================================================
-- ОКОН МОЖЕТ БЫТЬ НЕСКОЛЬКО, И ОНИ БЫВАЮТ ДВУХ РАЗНЫХ РОДОВ
--=============================================================================
--
-- Раньше правило было одно: отзывается только ВЕРХНЕЕ окно. Оно решало ровно
-- один случай -- палитра поверх настроек, -- и решало его ценой того, что
-- независимых окон существовать не могло в принципе.
--
-- Теперь окна связаны родством: Owner говорит, из какого окна открыто это.
-- Палитра -- ребёнок настроек, настройки двух разных пунктов -- ровня друг
-- другу. Отсюда правило:
--
--   щёлкнули ВНУТРИ окна   -- закрываются только те, что открыты ИЗ НЕГО;
--                             само оно и его соседи остаются;
--   щёлкнули В ПУСТОТУ     -- закрывается всё.
--
-- Прежнее поведение получается из этого само: у палитры и настроек родство
-- есть, значит щелчок в палитре настройки не трогает.
--
-- Подписка на закрытие ОДНА НА ОКНО, а не по одной на всплывающее: при пяти
-- открытых окнах пять обработчиков делали бы одну и ту же работу пять раз.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

local TITLE_H = THEME.PopupTitleHeight

local GAP = 6

--=============================================================================
-- ПЕРЕХВАТЧИК ОДИН НА ВСЮ СТОПКУ, А НЕ ПО ОДНОМУ НА ОКНО
--=============================================================================
--
-- Сперва каждое окно несло собственную прозрачную кнопку во весь экран, на
-- своём слое. Пока окно было одно, разницы не было никакой.
--
-- Со вторым окном это сломалось сразу и наглухо: слои идут по возрастанию
-- (100, 110, ...), и перехватчик ВЕРХНЕГО окна ложится поверх ПАНЕЛИ нижнего.
-- Нижнее окно остаётся видимым, выглядит совершенно рабочим и не отзывается ни
-- на что -- щелчки до него просто не доходят.
--
-- Работа у перехватчика ровно одна: не пускать щелчок в меню под стопкой.
-- Значит и слой ему нужен один, ниже любой панели. Панели начинаются со 100,
-- перехватчик стоит на 90 -- каждая из них выше него, и все они нажимаются.

local SHADE_Z = 90

local function ensureShade(window)
    if window.popupShade then return end
    window.popupShade = U.new("TextButton", {
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1), ZIndex = SHADE_Z, Name = U.randomName(),
    }, window.gui)
end

local function dropShade(window)
    if not window.popupShade then return end
    pcall(function() window.popupShade:Destroy() end)
    window.popupShade = false
end

--=============================================================================
-- РАСКЛАДКА: ОКНА НЕ НАЛЕЗАЮТ ДРУГ НА ДРУГА
--=============================================================================
--
-- Каждое окно встаёт рядом со своей строкой, а строки идут через 26 пикселей --
-- то есть настройки двух соседних пунктов открывались почти на одном месте и
-- перекрывали друг друга. Сравнить их было так же нельзя, как и раньше, только
-- теперь по другой причине.
--
-- Поэтому положение от якоря -- это ПОЖЕЛАНИЕ. Если оно занято, окно съезжает
-- под то, с чем столкнулось; кончилось место по высоте -- начинает следующую
-- колонку правее. Считаем в системе Position (смещение от верха экрана), а не в
-- AbsolutePosition: у окна IgnoreGuiInset, и эти две системы разъезжаются на
-- высоту верхней панели.

local function overlaps(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and bx < ax + aw
       and ay < by + bh and by < ay + ah
end

local function freeSpot(window, x, y, width, height, view)
    local minX, maxX = 4, math.max(4, view.X - width - 4)
    local minY, maxY = 4, math.max(4, view.Y - height - 4)

    local baseX = math.clamp(x, minX, maxX)
    local startY = math.clamp(y, minY, maxY)

    x, y = baseX, startY
    local column = 0

    for _ = 1, 60 do
        local moved = false
        for _, other in ipairs(window.popups) do
            local at = other.panel.Position
            local size = other.panel.AbsoluteSize
            if overlaps(x, y, width, height,
                at.X.Offset, at.Y.Offset, size.X, size.Y) then
                y = at.Y.Offset + size.Y + GAP
                moved = true
            end
        end
        if not moved then break end

        if y > maxY then
            column = column + 1
            if column > 6 then break end
            x = baseX + column * (width + GAP)
            y = startY
            -- Правее экрана уже некуда -- кладём как есть, внахлёст. Лучше
            -- окно на чужом месте, чем окно за краем экрана.
            if x > maxX then break end
        end
    end

    return math.clamp(x, minX, maxX), math.clamp(y, minY, maxY)
end

--=============================================================================
-- Закрытие: один разбор на всё окно
--=============================================================================

-- Открыто ли entry из host -- по цепочке родителей.
local function descends(entry, host)
    local node = entry.owner
    while node do
        if node == host then return true end
        node = node.owner
    end
    return false
end

local function dismiss(window, point)
    local host = false
    for _, entry in ipairs(window.popups) do
        if U.inside(entry.panel, point) then host = entry end
    end

    for i = #window.popups, 1, -1 do
        local entry = window.popups[i]
        -- armed: окно не закрывается тем же щелчком, которым его открыли.
        if entry.armed and entry ~= host
            and (not host or descends(entry, host)) then
            pcall(entry.close)
        end
    end
end

local function ensureDismiss(window)
    if window.popupInput then return end

    window.popupInput = {
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            for _, entry in ipairs(window.popups) do entry.armed = true end
        end),

        UserInputService.InputBegan:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.Escape then
                local top = window.popups[#window.popups]
                -- holdEscape поднимает тот, кому Escape нужен самому: захват
                -- клавиши отменяется им же, и закрывать заодно окно нельзя.
                --
                -- Пометка на записи работает, только когда ждёт САМО это окно.
                -- Привязка внутри меню правой кнопки (m:Keybind) о записи не
                -- знает вовсе -- она обычная строка обычного контейнера, -- и
                -- Escape закрывал меню вместо того, чтобы отменить захват.
                -- Общий признак закрывает и этот случай.
                if top and not top.holdEscape
                    and not NierUI.keyGrabbed(window) then
                    pcall(top.close)
                end
                return
            end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            dismiss(window, input.Position)
        end),
    }

    -- В window.conns: подписка живёт столько же, сколько окно, и гаснет в
    -- Destroy вместе со всем остальным.
    for _, conn in ipairs(window.popupInput) do
        table.insert(window.conns, conn)
    end
end

function Window:Popup(opts)
    opts = opts or {}

    -- Слой каждого следующего окна выше предыдущего, но не бесконечно: выше
    -- 200 живут уведомления, и десяток открытых окон не должен их накрывать.
    -- Упёршись в потолок, окна остаются на равных номерах, а порядок между
    -- ними решает очерёдность создания -- позже созданное и так сверху.
    local depth = math.min(#self.popups, 8)
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

    --== где встать ==========================================================
    --
    -- ЗАПОМНЕННОЕ ПОЛОЖЕНИЕ СИЛЬНЕЕ ЛЮБОЙ РАСКЛАДКИ.
    --
    -- Окно, которое перетащили руками, обязано открываться там, куда его
    -- поставили: человек двигал его не случайно, а чтобы оно не мешало. Место
    -- у якоря и объезд чужих окон -- это то, что делается ЗА него, пока он сам
    -- ничего не сказал.

    local x, y
    local place = opts.Place and self.popupPlaces[opts.Place]
    if place then
        x = math.clamp(place.X, 4, math.max(4, view.X - width - 4))
        y = math.clamp(place.Y, 4, math.max(4, view.Y - height - 4))
    else
        x, y = freeSpot(self,
            (opts.X or 0) + inset.X, (opts.Y or 0) + inset.Y,
            width, height, view)
    end

    local layer = U.new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        ZIndex = base, Name = U.randomName(),
    }, self.gui)

    ensureShade(self)

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

    local entry

    local function close()
        if closed then return end
        closed = true

        -- СООБЩАЕМ ДО ТОГО, КАК ЧТО-ЛИБО УНИЧТОЖЕНО.
        --
        -- Сначала OnClose стоял в самом конце -- логично казалось сообщать о
        -- свершившемся факте. Но содержимое окна не обязано ему принадлежать:
        -- контейнер (см. Panel) кладёт внутрь свою страницу и забирает её
        -- обратно при закрытии, чтобы построенные виджеты пережили окно.
        --
        -- Destroy у слоя рекурсивен и запирает Parent у всех потомков. Успей он
        -- раньше -- страница вместе со всеми виджетами уничтожалась бы вместе с
        -- окном, а забрать её было бы уже нельзя: «The Parent property is
        -- locked, current parent: NULL».
        --
        -- Порядок обратный: сперва отдать чужое, потом убирать своё.
        if opts.OnClose then pcall(opts.OnClose) end

        -- ЗАКРЫЛСЯ РОДИТЕЛЬ -- ЗАКРЫЛИСЬ И ДЕТИ.
        --
        -- Палитра открыта ИЗ окна настроек и без него не значит ничего: под ней
        -- больше нет ни строки, которую она красит, ни места, к которому она
        -- привязана. Оставшись одна, она висит сиротой и продолжает править
        -- настройку окна, которого уже нет.
        for i = #self.popups, 1, -1 do
            local other = self.popups[i]
            local node = other.owner
            while node do
                if node == entry then pcall(other.close) break end
                node = node.owner
            end
        end

        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        table.clear(conns)
        pcall(function() layer:Destroy() end)
        for i = #self.popups, 1, -1 do
            if self.popups[i].close == close then table.remove(self.popups, i) end
        end
        -- Ушло последнее -- перехватчику больше нечего стеречь. Оставить его
        -- значило бы накрыть меню невидимой кнопкой навсегда.
        if #self.popups == 0 then dropShade(self) end
    end

    -- Взводим сразу, если кнопка мыши уже отпущена; иначе -- по её отпусканию.
    -- Так окно не закроется тем же самым щелчком, которым его открыли, и при
    -- этом не нужен ни таймер, ни задержка.
    entry = {
        close = close, panel = panel,
        -- Owner приходит панелью, а хранится записью: вызывающему проще отдать
        -- то, что ему вернули из Popup, чем помнить ещё и внутреннюю запись.
        owner = false,
        armed = not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1),
        holdEscape = false,
    }

    if opts.Owner then
        for _, other in ipairs(self.popups) do
            if other.panel == opts.Owner then entry.owner = other end
        end
    end

    table.insert(self.popups, entry)
    ensureDismiss(self)

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
        local nx = math.floor(startPos.X.Offset + delta.X + 0.5)
        local ny = math.floor(startPos.Y.Offset + delta.Y + 0.5)
        panel.Position = UDim2.fromOffset(nx, ny)

        -- Запоминаем сразу, а не по отпусканию: до отпускания дело может и не
        -- дойти -- окно закроют щелчком мимо прямо во время перетаскивания, и
        -- тогда оно вернулось бы на прежнее место, будто его и не двигали.
        if opts.Place then
            self.popupPlaces[opts.Place] = Vector2.new(nx, ny)
        end
    end))

    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))

    return panel, close, conns, base + 2, entry
end

function Window:ClosePopups()
    for i = #self.popups, 1, -1 do
        pcall(self.popups[i].close)
    end
    self.popups = {}
end
