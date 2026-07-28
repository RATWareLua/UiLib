--!nocheck
--=============================================================================
-- Capture -- меню забирает ввод себе, пока открыто
--=============================================================================
--
-- Открыл меню посреди боя -- курсор появился, щелчки идут в меню, а не в игру.
-- Закрыл -- всё вернулось ровно как было.
--
-- Выключается опцией окна: NierUI:Window({ CaptureInput = false }).
--
--
-- ПОЧЕМУ НЕ ПОКАДРОВОЕ УДЕРЖАНИЕ
--
-- Игра выставляет режим мыши своим кодом и делает это регулярно, поэтому
-- однократной записи мало. Напрашивается держать значение каждый кадр -- и это
-- был бы первый постоянный поток в библиотеке, ради того, что меняется раз в
-- десять минут.
--
-- Вместо этого подписка на изменение самого свойства: игра его переписала --
-- мы вернули. Пока никто не спорит, не тратится ничего.
--
-- Своя запись отличается флагом: без него мы отвечали бы на собственное
-- изменение и ушли бы в бесконечную взаимную правку.
--
--
-- ДЕРЖИМ ТОЛЬКО РЕЖИМ МЫШИ
--
-- Раньше здесь удерживался ещё и MouseIconEnabled -- и это не работало.
-- Проверено вживую: щелчки в меню доходят, курсора нет. Игра прячет указатель
-- не одним этим свойством, а проигранный спор выглядит как работающее меню,
-- по которому непонятно куда нажимать.
--
-- Поэтому системный указатель теперь ГАСИТСЯ, а вместо него рисуется свой
-- (см. Cursor). Режим мыши держать по-прежнему необходимо: в LockCenter
-- указатель прибит к середине экрана и ни до одной строки не доедет.
--
--
-- ЧТО ИМЕННО ПОГЛОЩАЕТСЯ
--
-- Кнопки мыши и клавиши движения -- то, чем в бою стреляют и ездят. Не вся
-- клавиатура: под перехватом остались бы и наши собственные поля ввода, и
-- набрать в них что-либо стало бы нельзя.
--
-- Приоритет заведомо выше игровых: у Roblox штатные привязки живут около
-- двух тысяч, берём с запасом.

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local U = NierUI.util
local Window = NierUI.WindowClass

local PRIORITY = 5000

local SINK = {
    Enum.UserInputType.MouseButton1,
    Enum.UserInputType.MouseButton2,
    Enum.UserInputType.MouseButton3,
    Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
    Enum.KeyCode.Q, Enum.KeyCode.E,
    Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.LeftControl,
}

--=============================================================================

function Window:StartCapture()
    if self.captured then return end

    -- БЕЗ МЫШИ ПЕРЕХВАТЫВАТЬ НЕЧЕГО. На телефоне, планшете и консоли касание и
    -- так достаётся тому, по чему нажали, а поглощать WASD и кнопки мыши там
    -- бессмысленно: экранные органы управления -- это тот же интерфейс, и в
    -- ContextActionService они не приходят.
    --
    -- Хуже того, режим мыши там трогать нельзя вовсе: на консоли Default
    -- отвяжет прицел от стика.
    if not UserInputService.MouseEnabled then return end

    self.captured = true

    -- Запоминаем ровно то, что было: вернуть надо не «как принято», а как
    -- стояло у этого человека в этой игре.
    self.capturePrev = {
        behavior = UserInputService.MouseBehavior,
        icon = UserInputService.MouseIconEnabled,
    }

    -- Свой указатель -- значит системный лишний: два курсора хуже, чем ни
    -- одного. Отказались от своего -- пробуем показать системный, больше нам
    -- предложить нечего.
    local icon = not self.drawCursor

    local ours = false
    local function assert()
        if ours then return end
        ours = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = icon
        ours = false
    end
    assert()

    self.captureConns = {
        UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(function()
            if self.captured then assert() end
        end),
        UserInputService:GetPropertyChangedSignal("MouseIconEnabled"):Connect(function()
            if self.captured then assert() end
        end),
    }

    if self.drawCursor then self:ShowCursor() end

    self.captureAction = "NierUI_" .. U.randomName()
    ContextActionService:BindActionAtPriority(
        self.captureAction,
        function() return Enum.ContextActionResult.Sink end,
        false, PRIORITY, table.unpack(SINK))
end

function Window:StopCapture()
    if not self.captured then return end
    self.captured = false

    self:HideCursor()

    for _, conn in ipairs(self.captureConns or {}) do
        pcall(function() conn:Disconnect() end)
    end
    self.captureConns = false

    if self.captureAction then
        pcall(function() ContextActionService:UnbindAction(self.captureAction) end)
        self.captureAction = false
    end

    local prev = self.capturePrev
    if prev then
        UserInputService.MouseBehavior = prev.behavior
        UserInputService.MouseIconEnabled = prev.icon
        self.capturePrev = false
    end
end
