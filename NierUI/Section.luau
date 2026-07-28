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
    return setmetatable({ window = parent.window, rows = 0, page = page }, Sub)
end

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

    table.insert(self.window.conns,
        body:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout))

    table.insert(self.window.conns, header.MouseButton1Click:Connect(function()
        open = not open
        relayout()
    end))
    table.insert(self.window.conns, header.MouseEnter:Connect(function()
        label.TextColor3 = THEME.Ink
    end))
    table.insert(self.window.conns, header.MouseLeave:Connect(function()
        label.TextColor3 = THEME.InkSoft
    end))

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

    for index = 1, count do
        -- Ширина долей минус доля зазора: колонки складываются в единицу без
        -- переполнения при любом количестве.
        local column = U.new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(share * (index - 1), index > 1 and gap / 2 or 0, 0, 0),
            Size = UDim2.new(share, -gap * (count - 1) / count, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        }, holder)
        U.new("UIListLayout", {
            Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
        }, column)

        columns[index] = makeSub(self, column)
    end

    return table.unpack(columns)
end
