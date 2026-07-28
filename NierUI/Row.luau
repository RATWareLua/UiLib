--!nocheck
--=============================================================================
-- Row -- общий каркас строки
--=============================================================================
--
-- Всё, что есть у любого элемента: фон подсветки, маркер, подпись, значение,
-- разделитель и механизм инверсии. Виджеты берут это готовым и дописывают
-- сверху только своё.
--
--
-- ВСЁ СОДЕРЖИМОЕ ПРИБИТО К ПЕРВОЙ СТРОКЕ, А НЕ РАСТЯНУТО ПО ВЫСОТЕ
--
-- Строка может вырасти -- так раскрываются списки и палитра. Подпись когда-то
-- была высотой во всю строку и центрировалась по РАСКРЫТОЙ высоте: текст
-- уезжал вниз и прятался под раскрытым блоком. Значение выживало случайно --
-- у него высота была задана в пикселях. Теперь фиксированы все.
--
-- Заливка подсветки тоже вынесена в отдельный фон фиксированной высоты, а не
-- висит на самой строке: иначе при раскрытии подсвечивался бы весь блок.
--
--
-- ПОДСВЕТКА -- ЭТО СОСТОЯНИЕ, А НЕ РЕАКЦИЯ НА КУРСОР
--
-- Раньше она была намертво привязана к MouseEnter/MouseLeave, и раскрытый
-- блок это ломало: увёл мышь -- шапка гасла, а раскрытое висело само по себе,
-- без начала. Теперь поводов два -- курсор и удержание, -- а рисуется одно и
-- то же. setHeld отдаётся виджету, он и держит.
--
--
-- ИНВЕРСИЯ -- ОБЩИЙ МЕХАНИЗМ, А НЕ ДВЕ ЗАХАРДКОЖЕННЫЕ ПОДПИСИ
--
-- Под курсором строка заливается чернилами, значит ВСЁ, что нарисовано
-- чернилами, обязано стать песочным, иначе просто исчезнет. На этом уже
-- попались: дорожка ползунка была того же цвета, что и фон под курсором, и
-- наведение делало ползунок невидимым. Любой элемент подписывает любое своё
-- свойство через invert().

local THEME = NierUI.Theme
local U = NierUI.util

-- valueClass -- "TextLabel" (по умолчанию) или "TextBox" для редактируемого
-- значения. Раньше ползунок получал подпись, гасил её и рисовал поле рядом
-- сам: в строке оставался мёртвый объект, а зарегистрированная на него
-- инверсия работала вхолостую. Теперь каркас сразу отдаёт нужный тип.
--
-- Поле НЕ ставится по умолчанию намеренно: TextBox перехватывает щелчки, и у
-- переключателя нажатие по «[ ON ]» перестало бы переключать строку.
function NierUI.makeRow(tab, text, desc, valueClass)
    tab.rows = tab.rows + 1

    local row = U.new("TextButton", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "",
        Size = UDim2.new(1, 0, 0, THEME.RowHeight),
        LayoutOrder = tab.rows,
    }, tab.page)

    local bg = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
        BorderSizePixel = 0, Active = false,
        Size = UDim2.new(1, 0, 0, THEME.RowHeight), ZIndex = 1,
    }, row)

    local marker = U.new("Frame", {
        BackgroundColor3 = THEME.Bg, BorderSizePixel = 0,
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.fromOffset(4, 4), ZIndex = 3,
    }, row)

    local label = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = text or "", TextColor3 = THEME.Ink, TextSize = THEME.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(THEME.LabelFrac, 0, 0, THEME.RowHeight), ZIndex = 3,
    }, row)

    local value
    if valueClass == "TextBox" then
        -- Ширина РОВНО ПО ТЕКСТУ: растянутое на всю колонку поле ловило бы
        -- щелчки далеко левее видимого числа, в том числе те, что метят в
        -- дорожку ползунка. Растёт от правого края влево, поэтому число стоит
        -- на месте и не съезжает при наборе длинного значения. Нижний предел --
        -- чтобы в пустое поле было чем попасть.
        value = U.new("TextBox", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = "", TextColor3 = THEME.InkSoft, TextSize = THEME.TextSize,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextEditable = true, ClearTextOnFocus = false,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 0),
            Size = UDim2.fromOffset(0, THEME.RowHeight),
            AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3,
        }, row)
        U.new("UISizeConstraint", { MinSize = Vector2.new(22, THEME.RowHeight) }, value)
    else
        value = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = "", TextColor3 = THEME.InkSoft, TextSize = THEME.TextSize,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 0),
            Size = UDim2.new(THEME.ValueFrac, 0, 0, THEME.RowHeight), ZIndex = 3,
        }, row)
    end

    -- Тонкая черта под строкой: в оригинале списки разлинованы. Тоже по первой
    -- строке, а не по низу блока -- иначе у раскрытого она убегала бы вниз.
    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        BackgroundTransparency = 0.85,
        Position = UDim2.new(0, 0, 0, THEME.RowHeight - 1),
        Size = UDim2.new(1, 0, 0, 1), ZIndex = 2,
    }, row)

    local inverts = {}
    local function invert(inst, prop, hovered, normal)
        inverts[#inverts + 1] = { inst = inst, prop = prop, on = hovered, off = normal }
    end

    invert(label, "TextColor3", THEME.Bg, THEME.Ink)
    invert(value, "TextColor3", THEME.Bg, THEME.InkSoft)

    local hovered, held, enabled = false, false, true

    --== недоступное состояние ===============================================
    --
    -- Недоступная строка НЕ ПРЯЧЕТСЯ и не перестаёт показывать своё значение --
    -- она бледнеет и перестаёт отзываться. Скрывать нельзя: человек ищет
    -- знакомый пункт глазами, а его нет, и непонятно, исчез он или не существует.
    --
    -- Подсветка при этом гасится совсем, а не просто не включается: курсор над
    -- недоступной строкой не должен обещать, что по ней можно щёлкнуть.

    -- ПОДПИСКА НА ПЕРЕРИСОВКУ, помимо простой инверсии.
    --
    -- invert годится там, где у элемента ровно два вида: обычный и под
    -- курсором. Но у сегментного переключателя вид зависит ещё и от того,
    -- выбран ли он, -- четыре сочетания вместо двух, и подстановкой пары
    -- значений это не описать. Такому элементу нужно знать, что строка
    -- перерисовалась, и решать самому.
    local painters = {}

    local function paintRow()
        local on = enabled and (hovered or held)
        U.tween(bg, { BackgroundTransparency = on and 0 or 1 })
        for _, e in ipairs(inverts) do e.inst[e.prop] = on and e.on or e.off end
        marker.BackgroundTransparency = on and 0 or 1

        if not enabled then
            label.TextColor3 = THEME.Disabled
            value.TextColor3 = THEME.Disabled
        end

        for _, paint in ipairs(painters) do paint(on, enabled) end
    end

    local window = tab.window
    table.insert(window.conns, row.MouseEnter:Connect(function()
        hovered = true
        paintRow()
        if desc then window:Hint(desc) end
    end))
    table.insert(window.conns, row.MouseLeave:Connect(function()
        hovered = false
        paintRow()
    end))

    local function setHeld(state)
        held = state and true or false
        paintRow()
    end

    -- ВОРОТА ВМЕСТО ПРОВЕРКИ В КАЖДОМ ОБРАБОТЧИКЕ.
    --
    -- Виджет оборачивает свои подписки в gate, и недоступность работает сама.
    -- Иначе пришлось бы дописывать `if not enabled then return end` в каждый
    -- обработчик каждого виджета -- а забыть один из них ничего не стоит, и
    -- получилась бы строка, которая выглядит выключенной, но щёлкается.
    local function gate(fn)
        return function(...)
            if not enabled then return end
            return fn(...)
        end
    end

    local rowApi = {}

    function rowApi.gate(fn) return gate(fn) end
    function rowApi.isEnabled() return enabled end

    -- fn(подсвечена, доступна) -- зовётся при каждой перерисовке строки.
    function rowApi.onPaint(fn)
        painters[#painters + 1] = fn
        fn(false, enabled)
    end

    function rowApi.setEnabled(state)
        enabled = state ~= false
        -- Поле ввода надо гасить отдельно: оно принимает фокус само, минуя
        -- обработчики, и осталось бы редактируемым.
        if value:IsA("TextBox") then
            value.TextEditable = enabled
            if not enabled then value:ReleaseFocus() end
        end
        hovered = false
        paintRow()
    end

    return row, label, value, invert, setHeld, rowApi
end

--=============================================================================
-- Раскрывающийся блок под строкой
--=============================================================================
--
-- Общий и для списков, и для палитры.
--
-- БЛОК ВЫДЕЛЯЕТСЯ ТОНОМ, А НЕ БОКОВЫМИ ЛИНИЯМИ. Здесь по очереди перепробованы
-- и отброшены два подхода на волосяных линиях по краям:
--
--   UIStroke -- рисуется по ВНЕШНЕМУ краю. Совпал по ширине со строкой --
--     вылез на пиксель влево, вправо и вниз; вдвинул объект -- обводка встала
--     на место, но по краям открылась щель в фон. Третьего у него нет.
--
--   Свои линии в крайних колонках -- геометрия становится симметричной
--     (замерено: слева x=553 w=1, справа x=947 w=1, обе непрозрачные,
--     координаты целые), а выглядят они всё равно по-разному: однопиксельная
--     линия на самом краю читается вместе с тем, что нарисовано впритык, а
--     слева и справа это разные вещи.
--
-- Поэтому боковых линий нет вовсе. Тон фона не зависит ни от разрешения, ни от
-- округления, ни от соседей. Снизу одна линия, чтобы блок был закрыт; сверху
-- её роль играет разделитель под строкой.

function NierUI.makePanel(row, height)
    -- Active = true: раскрытый блок ПОГЛОЩАЕТ щелчки. Без этого нажатие по его
    -- пустому месту -- по полям вокруг палитры, по краю списка -- проваливалось
    -- в строку под ним и схлопывало блок прямо во время работы с ним.
    local panel = U.new("Frame", {
        BackgroundColor3 = THEME.BgSunk, BorderSizePixel = 0, Active = true,
        Position = UDim2.new(0, 0, 0, THEME.RowHeight),
        Size = UDim2.new(1, 0, 0, 0), Visible = false,
        ZIndex = 30, ClipsDescendants = true,
    }, row)

    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 1), ZIndex = 32,
    }, panel)

    -- Высота хранится в состоянии, а не защёлкивается при создании: у
    -- динамического списка она меняется вместе с числом пунктов, и пересоздавать
    -- ради этого всю панель было бы нелепо.
    local current, isOpen = height or 0, false

    local function apply()
        local h = isOpen and current or 0
        panel.Size = UDim2.new(1, 0, 0, h)
        -- строка растёт вместе с блоком, иначе соседние строки его перекроют
        row.Size = UDim2.new(1, 0, 0, THEME.RowHeight + h)
    end

    local function setOpen(state)
        isOpen = state
        panel.Visible = state
        apply()
    end

    local function setHeight(h)
        current = h
        apply()
    end

    return panel, setOpen, setHeight
end
