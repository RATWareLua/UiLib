--!nocheck
--=============================================================================
-- Progress -- полоса выполнения
--=============================================================================
--
--     local bar = tab:Progress({ Text = "LOADING", Default = 0 })
--     bar:Set(0.42)                 доля от нуля до единицы
--     bar:SetValue("42 / 100")      своя подпись вместо процентов
--     bar:SetValue(nil)             вернуть проценты
--
-- Только показывает. Ничего не считает и ни на что не подписывается: чем
-- заполнять -- дело вызывающего. Это осознанно, иначе полосе пришлось бы знать
-- про источник данных, а библиотека такого не знает нигде.

local THEME = NierUI.Theme
local U = NierUI.util

NierUI.widget("Progress", function(tab, opts)
    local row, _, value, invert, _, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)

    -- Геометрия как у дорожки ползунка -- те же доли, поэтому полоса и ползунок
    -- в соседних строках стоят вровень.
    local track = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        BackgroundTransparency = 0.8, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(THEME.TrackRight, 0, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.new(THEME.TrackFrac, 0, 0, 4), ZIndex = 3,
    }, row)
    U.new("UISizeConstraint", {
        MinSize = Vector2.new(36, 4), MaxSize = Vector2.new(110, 4),
    }, track)

    local fill = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
    }, track)

    invert(track, "BackgroundColor3", THEME.Bg, THEME.Ink)
    invert(fill, "BackgroundColor3", THEME.Bg, THEME.Ink)

    local current = math.clamp(tonumber(opts.Default) or 0, 0, 1)
    local caption = nil

    local function render()
        fill.Size = UDim2.fromScale(current, 1)
        value.Text = caption or ("%d%%"):format(math.floor(current * 100 + 0.5))
    end
    render()

    if opts.Enabled == false then rowApi.setEnabled(false) end

    return NierUI.bind(tab, opts, {
        Get = function(_) return current end,

        -- ВТОРОЙ ПАРАМЕТР Set ВЕЗДЕ ОЗНАЧАЕТ ОДНО И ТО ЖЕ -- «без обратного
        -- вызова». Полоса была единственной строкой, где он значил другое:
        -- подпись. Стоило чему-нибудь позвать общий Set(значение, true) --
        -- конфигу, менеджеру, чужому коду, гасящему группу строк, -- и в поле
        -- уезжало булево значение, а отрисовка падала на присваивании.
        --
        -- Подпись теперь ставится SetValue -- тем же примитивом, каким её
        -- ставит кнопка. Одно имя на одно действие во всей библиотеке.
        Set = function(_, fraction, silent)
            if type(silent) == "string" then
                error(("[NierUI] строка «%s»: Set(доля, подпись) больше нет -- "
                    .. "подпись ставится :SetValue(текст)")
                    :format(tostring(opts.Text or "?")), 2)
            end
            current = math.clamp(tonumber(fraction) or 0, 0, 1)
            render()
        end,

        -- Своя подпись вместо процентов; nil возвращает проценты.
        SetValue = function(_, text)
            caption = text ~= nil and tostring(text) or nil
            render()
        end,
        -- Пара доступности есть у ВСЕХ обработчиков, и полоса не исключение:
        -- README обещает её всем, а тот, кто гасит группу строк разом, не
        -- обязан помнить, какая из них показывает, а какая принимает ввод.
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Заливка -- не текст, общее приглушение подписей до неё не
            -- достаёт; гасим отдельно, как образец у палитры.
            fill.BackgroundTransparency = on and 0 or 0.6
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)
