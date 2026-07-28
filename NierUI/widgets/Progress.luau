--!nocheck
--=============================================================================
-- Progress -- полоса выполнения
--=============================================================================
--
--     local bar = tab:Progress({ Text = "LOADING", Default = 0 })
--     bar:Set(0.42)                 доля от нуля до единицы
--     bar:Set(0.42, "42 / 100")     своя подпись вместо процентов
--
-- Только показывает. Ничего не считает и ни на что не подписывается: чем
-- заполнять -- дело вызывающего. Это осознанно, иначе полосе пришлось бы знать
-- про источник данных, а библиотека такого не знает нигде.

local THEME = NierUI.Theme
local U = NierUI.util

NierUI.widget("Progress", function(tab, opts)
    local row, _, value, invert = NierUI.makeRow(tab, opts.Text, opts.Desc)

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

    return NierUI.bind(tab, opts, {
        Get = function(_) return current end,
        Set = function(_, fraction, text)
            current = math.clamp(tonumber(fraction) or 0, 0, 1)
            caption = text
            render()
        end,
    })
end)
