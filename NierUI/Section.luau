--!nocheck
--=============================================================================
-- Section и Split -- вложенные контейнеры
--=============================================================================
--
--     local group = tab:Section("PASSIVE")        складная группа
--     group:Toggle({ ... })
--
--     local left, right = tab:Split(2)            колонки в одной строке
--     left:Toggle({ ... })  right:Slider({ ... })
--
-- Оба возвращают КОНТЕЙНЕР -- то же, что вкладка и блок. Виджеты не заметят
-- разницы, потому что знают только про .page, .rows и .window.
--
--
-- ПОЧЕМУ SPLIT, А НЕ SameLine
--
-- В imgui несколько элементов в строке ставятся через SameLine -- пометку
-- «следующий рядом с предыдущим». Здесь это не годится: каждый виджет строит
-- СВОЮ строку во всю ширину и сам расставляет подпись, дорожку и значение по
-- долям. Чтобы SameLine заработал, пришлось бы вскрыть все виджеты и научить
-- их делить строку -- то есть переписать ровно то, что мы только что привели в
-- порядок.
--
-- Split решает ту же задачу снаружи: делит МЕСТО, а не строку. Виджеты внутри
-- колонки продолжают считать, что занимают всю ширину, потому что для них это
-- правда -- просто ширина теперь другая. Ни один виджет не тронут.

local THEME = NierUI.Theme
local U = NierUI.util
local C = NierUI.containerMethods

local Sub = {}
Sub.__index = NierUI.containerIndex(Sub)

local function makeSub(parent, page)
    return setmetatable({
        window = parent.window, rows = 0, page = page,
        -- Сток НАСЛЕДУЕТСЯ, а не берётся у окна: секция внутри временного
        -- контейнера обязана гаснуть вместе с ним. Взяв оконный, она пережила
        -- бы своего родителя вместе со всеми подписками виджетов внутри.
        conns = parent.conns,
        -- Владелец тоже наследуется: привязка в секции внутри меню принадлежит
        -- той же строке, что и меню.
        owner = parent.owner, pendingMenu = false, pendingSettings = false,
    }, Sub)
end

-- Наружу: динамическому списку нужен собственный кусок страницы, который можно
-- чистить целиком, не задевая соседей по контейнеру.
NierUI.makeSub = makeSub

--=============================================================================
-- Секция
--=============================================================================

function C.Section(self, title, opts)
    opts = opts or {}
    self.rows = self.rows + 1

    local holder = U.new("Frame", {
        BackgroundTransparency = 1, ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, THEME.RowHeight),
        LayoutOrder = self.rows,
    }, self.page)

    local header = U.new("TextButton", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "",
        Size = UDim2.new(1, 0, 0, THEME.RowHeight),
    }, holder)

    -- Указатель состояния: заполненный квадрат -- раскрыто, пустой -- свёрнуто.
    -- Значок вместо стрелки, чтобы не заводить ещё один шрифт ради глифа.
    local mark = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.fromOffset(6, 6), ZIndex = 3,
    }, header)

    local label = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = tostring(title or ""), TextColor3 = THEME.InkSoft, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -26, 0, THEME.RowHeight), ZIndex = 3,
    }, header)

    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        BackgroundTransparency = 0.75,
        Position = UDim2.new(0, 0, 0, THEME.RowHeight - 1),
        Size = UDim2.new(1, 0, 0, 1), ZIndex = 2,
    }, header)

    local body = U.new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, THEME.RowHeight),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, holder)
    U.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    U.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, body)

    local open = opts.Open ~= false

    -- Высота держателя считается ЯВНО: свёрнутая секция должна занимать ровно
    -- заголовок, а AutomaticSize учитывает и невидимых детей, из-за чего
    -- свёрнутая группа продолжала бы раздвигать соседей.
    local function relayout()
        holder.Size = UDim2.new(1, 0, 0,
            THEME.RowHeight + (open and body.AbsoluteSize.Y or 0))
        mark.BackgroundTransparency = open and 0 or 0.6
        body.Visible = open
    end

    NierUI.connect(self, body:GetPropertyChangedSignal("AbsoluteSize"), relayout)

    NierUI.connect(self, header.MouseButton1Click, function()
        open = not open
        relayout()
    end)
    NierUI.connect(self, header.MouseEnter, function()
        label.TextColor3 = THEME.Ink
    end)
    NierUI.connect(self, header.MouseLeave, function()
        label.TextColor3 = THEME.InkSoft
    end)

    relayout()

    local sub = makeSub(self, body)
    sub.SetOpen = function(_, state) open = state ~= false relayout() end
    sub.IsOpen = function(_) return open end
    return sub
end

--=============================================================================
-- Колонки
--=============================================================================

function C.Split(self, count, opts)
    opts = opts or {}
    count = math.max(2, math.min(count or 2, 4))
    self.rows = self.rows + 1

    local gap = opts.Gap or 6

    local holder = U.new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self.rows,
    }, self.page)

    local columns = {}
    local share = 1 / count

    -- ЗАЗОР ДЕЛИТСЯ ПО ЧИСЛУ ЩЕЛЕЙ, А ОТСТУП КОЛОНКИ РАСТЁТ ВМЕСТЕ С НОМЕРОМ.
    --
    -- Раньше отступ был один и тот же (gap/2) у всех колонок кроме первой, а
    -- ширина уменьшалась на gap*(count-1)/count. На двух колонках это сходилось
    -- точно и потому не вызывало вопросов; на трёх зазоры выходили 7 и 4, на
    -- четырёх расходились ещё сильнее -- колонки визуально разъезжались, хотя
    -- ширина у всех была одинаковой.
    --
    -- Щелей ровно count-1, каждая шириной gap. Колонка отдаёт долю зазора,
    -- пропорциональную числу щелей, а её левый край сдвигается на столько
    -- зазоров, сколько щелей осталось слева.
    local shrink = gap * (count - 1) / count

    for index = 1, count do
        local column = U.new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(share * (index - 1),
                gap * (index - 1) - shrink * (index - 1), 0, 0),
            Size = UDim2.new(share, -shrink, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        }, holder)
        U.new("UIListLayout", {
            Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
        }, column)

        columns[index] = makeSub(self, column)
    end

    return table.unpack(columns)
end
