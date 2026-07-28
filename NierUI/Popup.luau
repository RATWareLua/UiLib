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
-- нажатие мимо окна не проваливалось в меню под ним.
--
-- Отзывается только ВЕРХНЕЕ окно: иначе щелчок внутри палитры закрывал бы
-- настройки под ней.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

local TITLE_H = THEME.PopupTitleHeight

function Window:Popup(opts)
    opts = opts or {}

    local depth = #self.popups
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
    local x = math.clamp((opts.X or 0) + inset.X, 4, math.max(4, view.X - width - 4))
    local y = math.clamp((opts.Y or 0) + inset.Y, 4, math.max(4, view.Y - height - 4))

    local layer = U.new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        ZIndex = base, Name = U.randomName(),
    }, self.gui)

    -- Только поглотитель щелчков. Ничего не закрывает -- см. шапку.
    U.new("TextButton", {
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1), ZIndex = base,
    }, layer)

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

    local function close()
        if closed then return end
        closed = true
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        table.clear(conns)
        pcall(function() layer:Destroy() end)
        for i = #self.popups, 1, -1 do
            if self.popups[i].close == close then table.remove(self.popups, i) end
        end
    end

    local entry = { close = close, panel = panel }
    table.insert(self.popups, entry)

    --== закрытие ============================================================
    --
    -- Взводим сразу, если кнопка мыши уже отпущена; иначе -- по её отпусканию.
    -- Так окно не закроется тем же самым щелчком, которым его открыли, и при
    -- этом не нужен ни таймер, ни задержка.

    local armed = not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)

    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then armed = true end
    end))

    table.insert(conns, UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Escape then
            if self.popups[#self.popups] == entry then close() end
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not armed then return end
        -- отзывается только верхнее окно, иначе щелчок внутри палитры закрывал
        -- бы настройки под ней
        if self.popups[#self.popups] ~= entry then return end
        if U.inside(panel, input.Position) then return end
        close()
    end))

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
        panel.Position = UDim2.fromOffset(
            math.floor(startPos.X.Offset + delta.X + 0.5),
            math.floor(startPos.Y.Offset + delta.Y + 0.5))
    end))

    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))

    return panel, close, conns, base + 2
end

function Window:ClosePopups()
    for i = #self.popups, 1, -1 do
        pcall(self.popups[i].close)
    end
    self.popups = {}
end
