# Триггеры

Подписка на чужой сигнал с уведомлением и выключателем. Условие пишет
вызывающий, обработку берёт на себя библиотека.

Условие пишет пользователь, меню его обрабатывает.

```lua
local Players = game:GetService("Players")

local join = win:Trigger({
    Name    = "playerJoin",
    Signal  = Players.PlayerAdded,                        -- любой RBXScriptSignal
    Filter  = function(p) return p ~= Players.LocalPlayer end,
    Title   = "PLAYER",
    Message = function(p) return p.DisplayName .. " зашёл" end,
    Action  = function(p) list:Refresh(roster()) end,
    Flag    = "notifyJoin",
})

join:Enable()  join:Disable()  join:IsEnabled()  join:Fire(...)
```

Библиотека берёт на себя три вещи: **время жизни** подписки (гаснет вместе с
окном), **выключатель** с парой `Get`/`Set`, из-за которой триггер сохраняется в
профиль как обычный переключатель, и **показ** уведомления. Откуда сигнал и что
считать событием — дело вызывающего.

Опроса по условию каждый кадр здесь нет намеренно: это цикл. Нужен опрос —
заводите снаружи и дёргайте `Fire()`.

---

[← к оглавлению](../README.md)
