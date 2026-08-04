--!nocheck
--=============================================================================
-- ColorPicker -- строка с палитрой
--=============================================================================
--
-- Сама палитра живёт в NierUI.colorControl и здесь только встраивается: тот же
-- контрол используется во всплывающем окне настроек пункта списка. Держать две
-- копии этой геометрии значило бы получить через месяц две разные палитры.

local THEME = NierUI.Theme
local U = NierUI.util

local FIELD_HEIGHT = 100
-- место под HEX-строку берём у самого контрола, а не подгоняем числом
local PANEL_HEIGHT = FIELD_HEIGHT + NierUI.colorControlExtra + 20

NierUI.widget("ColorPicker", function(tab, opts)
    local row, _, value, invert, setHeld, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)

    -- Образец встаёт по той же доле, что и дорожка ползунка (см. Theme):
    -- жёсткий отступ от правого края не пережил бы половинной ширины ячейки.
    local swatch = U.new("Frame", {
        BackgroundColor3 = opts.Default or Color3.fromRGB(255, 40, 40),
        BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(THEME.TrackRight, 0, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.fromOffset(28, 12), ZIndex = 3,
    }, row)
    local swatchLine = U.stroke(swatch, 1)
    -- Обводка образца обязана инвертироваться: чернильная рамка на чернильном
    -- фоне под курсором исчезла бы, и образец повис бы в воздухе.
    invert(swatchLine, "Color", THEME.Bg, THEME.Ink)

    local panel, setPanel = NierUI.makePanel(row, PANEL_HEIGHT)

    -- ВИД СТРОКИ -- ОТДЕЛЬНО ОТ ОБРАТНОГО ВЫЗОВА.
    --
    -- Образец и код цвета рисовались прямо в обработчике, который уходит
    -- наружу, а он гасится тишиной. Значит Set(цвет, true) -- загрузка профиля
    -- у строки с Apply = false -- менял палитру внутри и НЕ менял ни квадрат, ни
    -- подпись: строка показывала прежний цвет, а хранила новый. Тишина гасит
    -- обратный вызов вызывающего, а не осведомлённость самого меню.
    local function show(c)
        swatch.BackgroundColor3 = c
        value.Text = U.hex(c)
    end

    local control = NierUI.colorControl(panel, {
        Position = UDim2.fromOffset(12, 10),
        Height = FIELD_HEIGHT,
        Color = opts.Default,
        -- Палитра слушает мышь глобально и обязана уметь отключаться: сток
        -- берём у контейнера, а не у окна. Во временном контейнере эти две
        -- подписки иначе переживали бы его.
        sink = NierUI.sink(tab),
        ZIndex = 30,
        Callback = function(c)
            show(c)
            NierUI.fire(opts, false, c)
        end,
    })
    -- Ширину контрол берёт от родителя (Width ему не задан), оставляем поля по
    -- краям; высоту не трогаем -- он сам знает про свою HEX-строку.
    control.instance.Size = UDim2.new(1, -24, 0, FIELD_HEIGHT + NierUI.colorControlExtra)

    show(control.Get())

    -- Раскрытие щелчком по строке -- в каркасе (см. NierUI.rowExpand), вместе
    -- со сторожем «щелчок пришёлся ВНУТРЬ раскрытой палитры -- строку не
    -- трогаем». Тот же самый, что у списка: держать его в двух местах значило
    -- бы однажды починить одно и оставить второе.
    local setOpen = NierUI.rowExpand(tab, row, rowApi, panel, function(state)
        setPanel(state)
        setHeld(state)
    end)

    return NierUI.bind(tab, opts, {
        Get = function(_) return control.Get() end,
        -- Вид строки обновляем ВСЕГДА, даже когда просили молчать: см. show.
        Set = function(_, c, silent)
            control.Set(c, silent)
            show(control.Get())
        end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Образец цвета гасим вручную: он не текст, и общее приглушение
            -- подписей до него не достаёт. Сравнение с false, а не просто
            -- `on and ...`: доступность везде -- это `state ~= false`, и
            -- SetEnabled() без аргумента строку ВКЛЮЧАЕТ.
            swatch.BackgroundTransparency = on ~= false and 0 or 0.6
            -- Раскрытую палитру схлопываем: иначе она останется висеть поверх
            -- соседних строк, а закрыть её будет уже нечем.
            if not on then setOpen(false) end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)
