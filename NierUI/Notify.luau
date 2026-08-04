--!nocheck
--=============================================================================
-- Notify -- всплывающие сообщения
--=============================================================================
--
--     win:Notify({ Text = "...", Title = "...", Duration = 6 })
--
-- Выезжают из-за правого края экрана, стопкой сверху вниз, снизу убывающая
-- полоска остатка времени. Duration задаёт срок жизни, по умолчанию берётся
-- Theme.NotifyDuration.
--
--
-- ЖИВУТ ОТДЕЛЬНО ОТ ОКНА
--
-- Сообщение о том, что кто-то зашёл на сервер, обязано показаться при ЗАКРЫТОМ
-- меню. Поэтому слой висит на ScreenGui рядом с окном, а Toggle прячет корень
-- окна, а не весь ScreenGui.
--
--
-- СТОПКА ВЕДЁТСЯ ВРУЧНУЮ, БЕЗ UIListLayout
--
-- Сначала карточки лежали в UIListLayout. Он САМ управляет позицией детей и
-- молча перезаписывал твин выезда -- анимации не было вовсе, карточка просто
-- возникала на месте. Разложить это на «слот от раскладки плюс карточка
-- внутри» тоже нельзя без второго слоя вложенности: по X двигается карточка,
-- по Y -- вся стопка, и обе координаты живут в одном свойстве Position.
--
-- Поэтому позиции считаются здесь: X отвечает за выезд и уход, Y -- за место в
-- стопке, пересчёт идёт при появлении, уходе и изменении высоты карточки.
--
--
-- ВЫСОТА ЗАДАЁТСЯ ЯВНО, А НЕ AutomaticSize
--
-- Полоска остатка прижата к низу карточки. С AutomaticSize по высоте это
-- замкнутая зависимость: высота считается по детям, а ребёнок стоит по высоте.
-- Поэтому высоту карточки выставляем сами по фактической высоте текста.
--
--
-- УНИЧТОЖЕНИЕ ГАРАНТИРОВАНО
--
-- Снос привязан к Completed твина ухода, а не к отдельной задержке: задержка
-- могла разъехаться с анимацией и оставить карточку висеть. Плюс защита от
-- повторного ухода и от сноса окна раньше срока -- в обоих случаях выходим
-- молча, ничего не оставляя.

local TweenService = game:GetService("TweenService")

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

local PAD = 10
local GAP = 6
local BAR = 2
local EDGE = 16          -- отступ стопки от края экрана

local MOVE = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EXIT = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

--=============================================================================

local function ensureLayer(window)
    if window.notifyLayer then return window.notifyLayer end

    window.notifyLayer = U.new("Frame", {
        BackgroundTransparency = 1, Active = false,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -EDGE, 0, EDGE),
        Size = UDim2.fromOffset(THEME.NotifyWidth, 0),
        ZIndex = 200,
    }, window.gui)

    return window.notifyLayer
end

-- Пересчёт стопки. X берётся у самой записи: за него отвечает выезд и уход, и
-- пересчёт не должен его затирать.
local function reflow(window)
    local y = 0
    for _, entry in ipairs(window.notifications) do
        if entry.card.Parent then
            TweenService:Create(entry.card, MOVE, {
                Position = UDim2.fromOffset(entry.x, y),
            }):Play()
            y = y + entry.card.AbsoluteSize.Y + GAP
        end
    end
end

--=============================================================================

function Window:Notify(opts)
    opts = opts or {}

    local width = THEME.NotifyWidth
    local duration = tonumber(opts.Duration) or THEME.NotifyDuration
    local layer = ensureLayer(self)

    -- Стартовая позиция -- за краем экрана: слой отбит от края на EDGE, значит
    -- сдвиг на ширину плюс этот отступ выводит карточку ровно за экран.
    local offscreen = width + EDGE

    local card = U.new("Frame", {
        BackgroundColor3 = THEME.Bg, BorderSizePixel = 0, Active = false,
        Position = UDim2.fromOffset(offscreen, 0),
        Size = UDim2.fromOffset(width, 0),
        ZIndex = 200, ClipsDescendants = true,
    }, layer)
    local line = U.stroke(card, 1)

    local top = PAD
    local titleLabel
    if opts.Title then
        titleLabel = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = tostring(opts.Title), TextColor3 = THEME.InkSoft, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(PAD, top),
            Size = UDim2.new(1, -PAD * 2, 0, 12), ZIndex = 201,
        }, card)
        top = top + 15
    end

    local body = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = tostring(opts.Text or ""), TextColor3 = THEME.Ink,
        TextSize = THEME.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(PAD, top),
        Size = UDim2.new(1, -PAD * 2, 0, 0), ZIndex = 201,
    }, card)

    -- Полоска остатка: живёт ровно duration и убывает линейно, поэтому по ней
    -- видно, сколько сообщение ещё провисит.
    local bar = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        BackgroundTransparency = 0.35,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, BAR), ZIndex = 202,
    }, card)

    -- abandon заполняется ниже: это способ для ClearNotifications погасить
    -- карточку изнутри, не разбираясь в её внутренностях.
    local entry = { card = card, x = 0, abandon = false }
    table.insert(self.notifications, entry)

    -- Высота карточки -- по фактической высоте текста. Пересчитывается по
    -- событию, потому что на кадре создания она ещё нулевая.
    local sizeConn
    sizeConn = body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if not card.Parent then return end
        card.Size = UDim2.fromOffset(width, top + body.AbsoluteSize.Y + PAD + BAR)
        reflow(self)
    end)

    card.Size = UDim2.fromOffset(width, top + body.TextBounds.Y + PAD + BAR)
    reflow(self)

    --== уход ================================================================
    --
    -- Гаснет ВСЁ разом и одним TweenInfo: подложка, рамка, обе подписи и
    -- полоска. Раньше гасились только подложка и текст -- рамка с заголовком
    -- оставались висеть в воздухе, пока карточка уезжала.

    local gone = false

    -- Бросить карточку: пометить ушедшей и снять подписку на высоту.
    --
    -- Подписку здесь снимать ОБЯЗАТЕЛЬНО. ClearNotifications уничтожает карточку
    -- сам, мимо destroy, и раньше взводил только пометку -- sizeConn оставался
    -- висеть на теле уничтоженной карточки. Одна забытая подписка на каждое
    -- показанное сообщение, а сообщений за сеанс сотни.
    local function abandon()
        gone = true
        if sizeConn then
            sizeConn:Disconnect()
            sizeConn = nil
        end
    end
    entry.abandon = abandon

    local function destroy()
        abandon()
        for i = #self.notifications, 1, -1 do
            if self.notifications[i] == entry then table.remove(self.notifications, i) end
        end
        if card.Parent then card:Destroy() end
        reflow(self)
    end

    local function dismiss()
        if gone then return end
        gone = true
        if not card.Parent then
            destroy()
            return
        end

        entry.x = offscreen
        TweenService:Create(line, EXIT, { Transparency = 1 }):Play()
        TweenService:Create(body, EXIT, { TextTransparency = 1 }):Play()
        TweenService:Create(bar, EXIT, { BackgroundTransparency = 1 }):Play()
        if titleLabel then
            TweenService:Create(titleLabel, EXIT, { TextTransparency = 1 }):Play()
        end

        local slide = TweenService:Create(card, EXIT, {
            Position = UDim2.fromOffset(offscreen, card.Position.Y.Offset),
            BackgroundTransparency = 1,
        })
        -- Снос по завершении анимации, а не по отдельной задержке: та могла
        -- разъехаться с ней и оставить карточку висеть.
        slide.Completed:Connect(destroy)
        slide:Play()
    end

    TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0, 0, 0, BAR) }):Play()

    task.delay(duration, dismiss)

    return { Dismiss = dismiss, instance = card }
end

-- Снять все разом. Нужно выгрузке окна: карточки висят на ScreenGui, и без
-- этого отложенные задержки достались бы уже уничтоженным объектам.
--
-- Бросаем каждую явно, её же собственным механизмом. Карточка уничтожается
-- здесь, а отложенный dismiss на неё всё равно придёт -- и без пометки пошёл бы
-- уводить и хоронить то, чего уже нет. До сих пор его удерживала только
-- проверка card.Parent внутри, то есть случайность, а не намерение.
--
-- Через abandon, а не пометкой руками: вместе с пометкой снимается и подписка на
-- высоту карточки, а её здесь снять больше некому -- destroy отсюда не зовётся.
function Window:ClearNotifications()
    for i = #self.notifications, 1, -1 do
        local entry = self.notifications[i]
        if entry.abandon then entry.abandon() end
        if entry.card.Parent then entry.card:Destroy() end
        table.remove(self.notifications, i)
    end
end
