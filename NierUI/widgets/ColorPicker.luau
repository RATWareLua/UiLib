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
    local window = tab.window

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

    local control = NierUI.colorControl(panel, {
        Position = UDim2.fromOffset(12, 10),
        Width = 0, Height = FIELD_HEIGHT,
        Color = opts.Default,
        -- Палитра слушает мышь глобально и обязана уметь отключаться: сток
        -- берём у контейнера, а не у окна. Во временном контейнере эти две
        -- подписки иначе переживали бы его.
        sink = NierUI.sink(tab),
        ZIndex = 30,
        Callback = function(c)
            swatch.BackgroundColor3 = c
            value.Text = U.hex(c)
            if opts.Callback then pcall(opts.Callback, c) end
        end,
    })
    -- ширину контрол берёт от родителя, оставляем поля по краям; высоту не
    -- трогаем -- он сам знает про свою HEX-строку
    control.instance.Size = UDim2.new(1, -24, 0, FIELD_HEIGHT + NierUI.colorControlExtra)

    value.Text = U.hex(control.Get())

    -- ЩЕЛЧОК ВНУТРИ РАСКРЫТОЙ ПАНЕЛИ НЕ ЗАКРЫВАЕТ СТРОКУ.
    --
    -- Active = true на панели и на квадрате оказалось НЕ достаточно: панель
    -- лежит внутри самой строки, а не поверх неё, и нажатие по палитре всё
    -- равно доходило до строки-кнопки. Выбор цвета схлопывал палитру на
    -- отпускании -- ровно то, что уже чинили однажды сторожем «сейчас тянем».
    --
    -- Тот сторож я потом убрал, посчитав мёртвым по рассуждению, а не по
    -- замеру, -- и вернул поломку. Теперь проверка не про перетаскивание, а
    -- про место: MouseButton1Click координат не несёт, поэтому окно помнит
    -- точку последнего нажатия. Это ловит и простой щелчок без движения, чего
    -- прежний сторож не умел.
    local open = false
    NierUI.connect(tab, row.MouseButton1Click, rowApi.gate(function()
        if open and U.inside(panel, window.lastPress) then return end
        open = not open
        setPanel(open)
        setHeld(open)
    end))

    if opts.Enabled == false then rowApi.setEnabled(false) end

    return NierUI.bind(tab, opts, {
        Get = function(_) return control.Get() end,
        Set = function(_, c, silent) control.Set(c, silent) end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Образец цвета гасим вручную: он не текст, и общее приглушение
            -- подписей до него не достаёт.
            swatch.BackgroundTransparency = on and 0 or 0.6
            if not on and open then
                open = false
                setPanel(false)
                setHeld(false)
            end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)
