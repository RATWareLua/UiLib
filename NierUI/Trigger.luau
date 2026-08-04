--!nocheck
--=============================================================================
-- Trigger -- условие снаружи, обработка внутри
--=============================================================================
--
--     win:Trigger({
--         Name = "join",
--         Signal = Players.PlayerAdded,          -- любой RBXScriptSignal
--         Filter = function(p) return p ~= me end,   -- условие пишет юзер
--         Message = function(p) return p.Name .. " зашёл" end,
--         Title = "PLAYER",
--         Action = function(p) list:Refresh(...) end,
--         Enabled = true,
--         Flag = "notifyJoin",
--     })
--
-- Возвращает handle: :Enable(), :Disable(), :IsEnabled(), :Fire(...).
--
--
-- ГДЕ ЗДЕСЬ ГРАНИЦА
--
-- Библиотека НЕ ЗНАЕТ, что такое игрок, вход и выход. Ей передают сигнал и
-- предикат -- она берёт на себя ровно три вещи, которые иначе пришлось бы
-- писать заново на каждый случай:
--
--   ВРЕМЯ ЖИЗНИ. Подписка живёт в окне и гаснет вместе с ним. Собственный
--     коннект пользователя пережил бы Destroy и остался бы висеть -- ровно тот
--     класс утечки, на котором мы горели трижды.
--
--   ВЫКЛЮЧАТЕЛЬ. У триггера есть состояние, которое можно завести на Flag и
--     тем самым сохранить в профиль. Выключенный триггер не отписывается, а
--     перестаёт срабатывать: переподписка на каждый щелчок тумблера -- лишний
--     способ потерять сигнал.
--
--   ПОКАЗ. Есть Message -- будет уведомление. Нет -- не будет. Пользователю не
--     нужно знать, как устроен слой сообщений.
--
-- Всё остальное -- откуда сигнал, что считать событием, что делать сверх
-- уведомления -- пишет тот, кто триггер объявляет.
--
--
-- ПОЧЕМУ ТОЛЬКО СИГНАЛЫ, А НЕ УСЛОВИЯ-ПРОВЕРКИ
--
-- Напрашивается Condition = function() return hp < 20 end с опросом каждый
-- кадр. Этого здесь нет намеренно: опрос -- это цикл, а библиотека держится на
-- том, что в ней нет ни одного постоянного потока. Нужен опрос -- заведите его
-- снаружи и дёргайте handle:Fire(), обработка та же.

local Window = NierUI.WindowClass

function Window:Trigger(opts)
    opts = opts or {}

    -- Имя нужно ровно для одного -- сказать в предупреждении, ЧЕЙ обработчик
    -- упал. Реестра «имя -> триггер» здесь больше нет: он только заполнялся и
    -- не читался никем, а найти триггер по имени было нечем -- метода наружу не
    -- существовало. Ручку и так возвращает сам вызов, держать её вторую копию
    -- незачем.
    --
    -- Счётчик, а не длина реестра: у отображения имя -> обработчик нет числовой
    -- части, и # всегда давал ноль -- все безымянные получали одно «trigger1».
    self.triggerSeq = self.triggerSeq + 1

    local trigger = {
        name = opts.Name or ("trigger" .. self.triggerSeq),
        enabled = opts.Enabled ~= false,
    }

    -- Само срабатывание: сперва выключатель, потом условие, потом показ.
    -- Порядок важен -- выключенный триггер не должен даже вычислять предикат,
    -- он может быть дорогим.
    local function fire(...)
        if not trigger.enabled then return end

        if opts.Filter then
            local ok, pass = pcall(opts.Filter, ...)
            if not ok or not pass then return end
        end

        if opts.Message then
            local ok, text = pcall(opts.Message, ...)
            if ok and text ~= nil and text ~= "" then
                self:Notify({
                    Text = tostring(text),
                    Title = opts.Title,
                    Duration = opts.Duration,
                })
            end
        end

        if opts.Action then
            local ok, err = pcall(opts.Action, ...)
            if not ok then
                warn(("[NierUI] триггер %s: %s"):format(trigger.name, tostring(err)))
            end
        end
    end

    if opts.Signal then
        -- В window.conns, а не в собственный список: триггеры живут столько
        -- же, сколько окно, и гаснут одним махом в Destroy.
        table.insert(self.conns, opts.Signal:Connect(fire))
    end

    local handle = {
        Fire = function(_, ...) fire(...) end,
        Enable = function(_) trigger.enabled = true end,
        Disable = function(_) trigger.enabled = false end,
        IsEnabled = function(_) return trigger.enabled end,
        -- Пара Get/Set -- чтобы триггер сохранялся в профиль как обычный
        -- переключатель, без отдельной ветки в конфиге.
        Get = function(_) return trigger.enabled end,
        Set = function(_, on) trigger.enabled = on and true or false end,
    }

    NierUI.bindFlag(self, opts.Flag, handle, 2, opts.Save)

    return handle
end
