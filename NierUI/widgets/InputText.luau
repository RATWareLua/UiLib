--!nocheck
--=============================================================================
-- InputText -- строка ввода
--=============================================================================
--
--     tab:InputText({ Text = "WEBHOOK", Placeholder = "https://...",
--                     MaxLength = 200, Flag = "webhook",
--                     Callback = function(text) end,   -- по завершении ввода
--                     Changed  = function(text) end }) -- по ходу набора
--
-- Единственная дыра в наборе примитивов, которая оставалась: ввод у нас был,
-- но приколоченный -- числовой внутри ползунка и hex внутри палитры. Поле как
-- самостоятельный элемент отсутствовало, а без него не построить ничего, где
-- нужны ники, ссылки или произвольные имена.
--
--
-- ШИРИНА ФИКСИРОВАННАЯ, А НЕ ПО СОДЕРЖИМОМУ
--
-- У ползунка поле растёт по числу: там оно короткое и предсказуемое. Здесь
-- наоборот -- текст произвольной длины, и растущее поле уползло бы влево прямо
-- под подпись строки. Поэтому ширина задана долей, а лишнее обрезается
-- прокруткой самого TextBox.

local THEME = NierUI.Theme
local U = NierUI.util

NierUI.widget("InputText", function(tab, opts)
    local row, _, box, _, _, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc, "TextBox")

    box.AutomaticSize = Enum.AutomaticSize.None
    box.Size = UDim2.new(opts.Width or 0.42, 0, 0, THEME.RowHeight)
    box.ClearTextOnFocus = false
    box.Text = tostring(opts.Default or "")
    box.PlaceholderText = tostring(opts.Placeholder or "")
    box.PlaceholderColor3 = THEME.InkSoft

    -- Ограничитель ширины из каркаса рассчитан на короткое число; здесь он
    -- только мешал бы доле.
    local limit = box:FindFirstChildOfClass("UISizeConstraint")
    if limit then limit:Destroy() end

    local maxLength = opts.MaxLength
    local current = box.Text

    table.insert(tab.window.conns, box:GetPropertyChangedSignal("Text"):Connect(function()
        -- Обрезаем ПО ХОДУ набора, а не при завершении: иначе человек печатает,
        -- видит текст, а на выходе часть молча исчезает.
        if maxLength and #box.Text > maxLength then
            box.Text = box.Text:sub(1, maxLength)
            return
        end
        if box.Text == current then return end
        current = box.Text
        if opts.Changed then pcall(opts.Changed, current) end
    end))

    table.insert(tab.window.conns, box.FocusLost:Connect(function()
        current = box.Text
        if opts.Callback then pcall(opts.Callback, current) end
    end))

    if opts.Enabled == false then rowApi.setEnabled(false) end

    return NierUI.bind(tab, opts, {
        SetEnabled = function(_, on) rowApi.setEnabled(on) end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
        Get = function(_) return box.Text end,
        Set = function(_, text, silent)
            box.Text = tostring(text or "")
            current = box.Text
            if silent or not opts.Callback then return end
            pcall(opts.Callback, current)
        end,
    })
end)
