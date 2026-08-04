--!nocheck
--=============================================================================
-- ColorControl -- сам выбор цвета, без привязки к строке
--=============================================================================
--
-- Вынесен отдельно, потому что мест, где он нужен, стало два: строка-палитра
-- в меню и всплывающее окно у пункта списка. Держать две копии этой геометрии
-- -- гарантированно получить две разные палитры через месяц.
--
--
-- БЕЗ ЕДИНОГО АССЕТА
--
-- Квадрат насыщенности -- три слоя, а не картинка: снизу чистый тон, поверх
-- белый с горизонтальным градиентом прозрачности (насыщенность), поверх чёрный
-- с вертикальным (яркость). Полоса тона -- один Frame с UIGradient на семь
-- опорных цветов.
--
-- Это не эстетство: загруженная картинка -- это ассет, который надо где-то
-- держать, который модерируется и который может однажды перестать грузиться.
-- Здесь всё рисует движок.
--
--
-- sink -- КУДА СКЛАДЫВАТЬ КОННЕКТЫ
--
-- Контрол слушает мышь глобально (иначе перетаскивание рвётся, стоит курсору
-- уйти за пределы квадрата), поэтому обязан уметь отключаться. Владелец
-- передаёт свой список: строка -- window.conns на всю жизнь окна, всплывающее
-- окно -- свой, который гаснет при закрытии.

local UserInputService = game:GetService("UserInputService")

local THEME = NierUI.Theme
local U = NierUI.util

local HUE_STOPS = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
})

-- parent  -- куда встроить
-- opts    -- Position (UDim2), Width, Height, Color, Callback, sink, ZIndex
-- Высота HEX-строки под квадратом. Отдаётся наружу, чтобы вызывающие
-- резервировали место числом отсюда, а не подгоняли на глаз.
local HEX_H = 22
NierUI.colorControlExtra = HEX_H

function NierUI.colorControl(parent, opts)
    local z = opts.ZIndex or 30
    local fieldHeight = opts.Height or 100
    local sink = opts.sink or {}

    local h, s, v = Color3.toHSV(opts.Color or Color3.fromRGB(255, 40, 40))

    -- Ширина: число -- пиксели, ничего -- во всю ширину родителя. Ноль тут
    -- пикселями и остаётся, потому что «во всю ширину» просят ОТСУТСТВИЕМ поля,
    -- а не нулём: строка-палитра когда-то передавала Width = 0 и тут же
    -- переписывала размер сама -- то есть просила нулевую ширину и чинила
    -- последствия следующей строкой.
    local size = opts.Width
        and UDim2.fromOffset(opts.Width, fieldHeight + HEX_H)
        or UDim2.new(1, 0, 0, fieldHeight + HEX_H)

    local holder = U.new("Frame", {
        BackgroundTransparency = 1,
        Position = opts.Position or UDim2.fromOffset(0, 0),
        Size = size,
        ZIndex = z,
    }, parent)

    -- ACTIVE = TRUE ОБЯЗАТЕЛЕН, И ЭТО НЕ МЕЛОЧЬ.
    --
    -- Frame с Active = false щелчок не перехватывает -- он проваливается
    -- насквозь к тому, что лежит ниже. В строке под палитрой ничего не было, и
    -- это сходило с рук. Во всплывающем окне ниже лежит фон-перехватчик во весь
    -- экран, и щелчок по квадрату уходил в него: окно закрывалось раньше, чем
    -- начиналось перетаскивание, выбрать цвет было невозможно в принципе.
    --
    -- То же будет с любым будущим контролом внутри всплывающего окна: не
    -- поглощаешь щелчок -- закрываешь окно вместо работы.
    local field = U.new("Frame", {
        BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0,
        Active = true, Size = UDim2.new(1, -24, 0, fieldHeight), ZIndex = z,
    }, holder)

    local white = U.new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Active = false, Size = UDim2.fromScale(1, 1), ZIndex = z + 1,
    }, field)
    U.new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, white)

    local black = U.new("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
        Active = false, Size = UDim2.fromScale(1, 1), ZIndex = z + 2,
    }, field)
    U.new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, black)

    local fieldDot = U.new("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7),
        ZIndex = z + 4,
    }, field)
    U.stroke(fieldDot, 1, Color3.new(1, 1, 1))

    local hueBar = U.new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Active = true,   -- см. field: без этого щелчок уходит в фон окна
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 14, 0, fieldHeight), ZIndex = z,
    }, holder)
    U.new("UIGradient", { Rotation = 90, Color = HUE_STOPS }, hueBar)

    local hueDot = U.new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Active = false, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 4, 0, 2),
        ZIndex = z + 4,
    }, hueBar)

    --== HEX ==================================================================
    --
    -- Мышью в конкретный цвет не попасть -- это две координаты по сотне
    -- пикселей плюс тон. Поэтому цвет можно вписать кодом, и это тот же
    -- контрол, что стоит и в строке меню, и во всплывающем окне у пункта
    -- списка: пишется один раз, работает в обоих местах.

    -- Поле шириной РОВНО ПО КОДУ, а не во всю ширину контрола. Растянутое на
    -- всю строку, оно ловило щелчки далеко правее самого текста -- по пустому
    -- месту под квадратом.
    --
    -- Растёт вправо от левого края, поэтому код стоит на месте. Нижний предел
    -- нужен пустому полю: без него в него нечем попасть.
    local hexBox = U.new("TextBox", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = "", TextColor3 = THEME.Ink, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextEditable = true, ClearTextOnFocus = false,
        Position = UDim2.new(0, 0, 0, fieldHeight + 4),
        Size = UDim2.fromOffset(0, HEX_H - 4),
        AutomaticSize = Enum.AutomaticSize.X, ZIndex = z,
    }, holder)
    U.new("UISizeConstraint", { MinSize = Vector2.new(48, HEX_H - 4) }, hexBox)

    local editing = false

    -- Разрешаем решётку первым символом и до шести шестнадцатеричных цифр.
    -- Фильтруем по ходу набора: иначе набранные буквы видны, а на выходе молча
    -- превращаются в прежний цвет -- выглядит как проглоченный ввод.
    local function sanitizeHex(text)
        local out, digits = {}, 0
        for i = 1, #text do
            local ch = text:sub(i, i)
            if ch == "#" and #out == 0 then
                out[#out + 1] = ch
            elseif ch:match("[0-9a-fA-F]") and digits < 6 then
                digits = digits + 1
                out[#out + 1] = ch:upper()
            end
        end
        return table.concat(out)
    end

    -- Разбор -- в Util: тот же нужен кодеку конфига, и двух копий быть не должно.

    --=========================================================================

    local api = {}

    local function color()
        return Color3.fromHSV(h, s, v)
    end

    local function render(silent)
        field.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        fieldDot.Position = UDim2.fromScale(s, 1 - v)
        hueDot.Position = UDim2.fromScale(0.5, h)
        if not editing then hexBox.Text = U.hex(color()) end
        -- Тот же общий вызов, что у всех виджетов (см. NierUI.fire): своя копия
        -- здесь молча глотала ошибку владельца палитры.
        NierUI.fire(opts, silent, color())
    end
    render(true)

    table.insert(sink, hexBox:GetPropertyChangedSignal("Text"):Connect(function()
        if not editing then return end
        local clean = sanitizeHex(hexBox.Text)
        if clean ~= hexBox.Text then hexBox.Text = clean end
    end))

    table.insert(sink, hexBox.Focused:Connect(function()
        editing = true
    end))

    table.insert(sink, hexBox.FocusLost:Connect(function()
        editing = false
        local parsed = U.fromHex(hexBox.Text)
        if parsed then
            h, s, v = Color3.toHSV(parsed)
        end
        -- не разобралось -- render вернёт прежний код обратно в поле
        render()
    end))

    -- Одна переменная с именем активной области, а не два независимых флага:
    -- иначе нажатие в квадрате и увод курсора на полосу тянуло бы обе сразу.
    local dragging = nil

    local function applyField(x, y)
        s = U.alongX(field, x)
        v = 1 - U.alongY(field, y)
        render()
    end

    local function applyHue(y)
        h = U.alongY(hueBar, y)
        render()
    end

    table.insert(sink, field.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = "field"
        applyField(input.Position.X, input.Position.Y)
    end))

    table.insert(sink, hueBar.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = "hue"
        applyHue(input.Position.Y)
    end))

    table.insert(sink, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if dragging == "field" then
            applyField(input.Position.X, input.Position.Y)
        else
            applyHue(input.Position.Y)
        end
    end))

    table.insert(sink, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = nil end
    end))

    -- Внутренний контрол, не виджет: вызывается точкой, без self. Виджеты
    -- наружу отдают двоеточные Get/Set -- смешивать соглашения в одном файле
    -- нельзя, а разводить их по слоям можно и нужно.
    function api.Get() return color() end
    function api.Set(c, silent)
        h, s, v = Color3.toHSV(c)
        render(silent)
    end
    api.instance = holder

    return api
end
