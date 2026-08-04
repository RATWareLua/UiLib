--!nocheck
--=============================================================================
-- Modal -- подтверждение
--=============================================================================
--
--     win:Confirm({
--         Title = "UNLOAD", Text = "Снять меню целиком?",
--         Confirm = "YES", Cancel = "NO",
--         OnConfirm = function() ... end,
--     })
--
-- Стоит на готовом механизме всплывающих окон: своя раскладка, чужие фон,
-- закрытие щелчком мимо, перетаскивание за заголовок и вложенность.
--
-- Единственное отличие от обычного всплывающего окна -- положение: модалка
-- встаёт по центру экрана, а не рядом с элементом. Подтверждение не привязано
-- к месту, откуда его вызвали, и искать его глазами в углу неправильно.

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

local WIDTH = 300
local BUTTON_H = 26

function Window:Confirm(opts)
    opts = opts or {}

    local view = NierUI.viewport()

    local text = tostring(opts.Text or "")
    -- Высоту прикидываем по длине текста: точную не узнать до отрисовки, а
    -- окно уже должно встать по центру.
    --
    -- В СИМВОЛАХ, А НЕ В БАЙТАХ. Здесь стояло #text, и русский вопрос давал
    -- вдвое больше строк, чем есть: кириллическая буква в UTF-8 занимает два
    -- байта. Окно выходило заметно выше нужного, с пустотой между текстом и
    -- кнопками -- а спрашивает библиотека как раз по-русски, своим же «СНЕСТИ
    -- ПРИВЯЗКУ».
    local lines = math.max(1, math.ceil((U.textLength(text) or #text) / 42))
    local height = THEME.PopupTitleHeight + 12 + lines * 16 + 12 + BUTTON_H + 12

    local panel, close, conns, z = self:Popup({
        Title = opts.Title or "CONFIRM",
        Width = WIDTH, Height = height,
        X = math.floor((view.X - WIDTH) / 2),
        Y = math.floor((view.Y - height) / 2),
    })

    U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = text, TextColor3 = THEME.Ink, TextSize = THEME.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Position = UDim2.fromOffset(12, THEME.PopupTitleHeight + 10),
        Size = UDim2.new(1, -24, 0, lines * 16), ZIndex = z,
    }, panel)

    local function button(label, x, width, action)
        local btn = U.new("TextButton", {
            BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false,
            Font = THEME.Font, Text = tostring(label),
            TextColor3 = THEME.Ink, TextSize = THEME.TextSize,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(x, 0, 1, -12),
            Size = UDim2.new(width, -6, 0, BUTTON_H), ZIndex = z,
        }, panel)
        local line = U.stroke(btn, 1)

        table.insert(conns, btn.MouseEnter:Connect(function()
            btn.BackgroundTransparency = 0
            btn.TextColor3 = THEME.Bg
            line.Transparency = 1
        end))
        table.insert(conns, btn.MouseLeave:Connect(function()
            btn.BackgroundTransparency = 1
            btn.TextColor3 = THEME.Ink
            line.Transparency = 0
        end))
        table.insert(conns, btn.MouseButton1Click:Connect(function()
            -- Закрываем ПЕРЕД действием: действие может открыть своё окно, и
            -- закрытие после него схлопнуло бы уже не нас.
            close()
            if action then pcall(action) end
        end))
    end

    button(opts.Cancel or "CANCEL", 0.04, 0.44, opts.OnCancel)
    button(opts.Confirm or "CONFIRM", 0.52, 0.44, opts.OnConfirm)

    return close
end
