--!nocheck
--=============================================================================
-- Keybind -- привязка клавиши
--=============================================================================
--
-- Пока ждём нажатие, строка держится подсвеченной: иначе непонятно, что меню
-- вообще чего-то ждёт. Ровно тот же setHeld, что держит раскрытый список.

local UserInputService = game:GetService("UserInputService")

NierUI.widget("Keybind", function(tab, opts)
    local row, _, value, _, setHeld, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc)

    local key = opts.Default
    local listening = false

    local function render()
        value.Text = listening and "[ ... ]" or (key and key.Name or "NONE")
    end
    render()

    table.insert(tab.window.conns, row.MouseButton1Click:Connect(rowApi.gate(function()
        listening = true
        setHeld(true)
        render()
    end)))

    -- Глобальная подписка тоже под воротами: у выключенной привязки не должна
    -- срабатывать ни сама клавиша, ни ожидание новой.
    table.insert(tab.window.conns, UserInputService.InputBegan:Connect(rowApi.gate(function(input, processed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        if listening then
            listening = false
            setHeld(false)
            -- Escape отменяет назначение, а не назначает Escape.
            if input.KeyCode ~= Enum.KeyCode.Escape then
                key = input.KeyCode
                if opts.Changed then pcall(opts.Changed, key) end
            end
            render()
            return
        end

        if processed or not key or input.KeyCode ~= key then return end
        if opts.Callback then pcall(opts.Callback, key) end
    end)))

    if opts.Enabled == false then rowApi.setEnabled(false) end

    return NierUI.bind(tab, opts, {
        Set = function(_, k) key = k render() end,
        Get = function(_) return key end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Ждали нажатие в момент выключения -- ожидание надо снять, иначе
            -- строка останется подсвеченной навсегда.
            if not on and listening then
                listening = false
                setHeld(false)
                render()
            end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)
