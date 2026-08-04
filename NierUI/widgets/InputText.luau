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
    -- ШИРИНУ ЗАДАЁТ КАРКАС, А НЕ МЫ ПОСЛЕ НЕГО.
    --
    -- Здесь стояла разборка только что построенного поля: погасить
    -- AutomaticSize, переписать размер и СНЕСТИ ограничитель, который каркас
    -- поставил строкой выше. Умолчание подсовываем подстановкой -- ровно как
    -- список прячет от каркаса свой двухуровневый Settings: остальные поля
    -- читаются через __index и остаются теми же самыми, а таблица вызывающего
    -- не трогается.
    local rowOpts = setmetatable({ Width = opts.Width or 0.42 },
        { __index = opts })

    -- Сама строка полю не нужна: щелчок по ней ловит TextBox, а всё остальное
    -- -- меню, настройки, доступность -- каркас делает сам.
    local _, _, box, _, _, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, "TextBox", rowOpts)

    box.Text = tostring(opts.Default or "")
    box.PlaceholderText = tostring(opts.Placeholder or "")
    box.PlaceholderColor3 = THEME.InkSoft

    local maxLength = opts.MaxLength
    local current = box.Text

    NierUI.connect(tab, box:GetPropertyChangedSignal("Text"), function()
        -- Обрезаем ПО ХОДУ набора, а не при завершении: иначе человек печатает,
        -- видит текст, а на выходе часть молча исчезает.
        --
        -- В СИМВОЛАХ, А НЕ В БАЙТАХ. Здесь стояло #box.Text, и на кириллице
        -- предел срабатывал вдвое раньше обещанного -- MaxLength = 24 давало
        -- двенадцать букв, -- а на границе разрубал букву пополам: в поле
        -- вылезал знак-заменитель. Ловилось прямо на переименовании привязки,
        -- где поле как раз с пределом в 24.
        if maxLength and (U.textLength(box.Text) or 0) > maxLength then
            box.Text = U.textCut(box.Text, maxLength)
            return
        end
        if box.Text == current then return end
        current = box.Text
        if opts.Changed then pcall(opts.Changed, current) end
    end)

    NierUI.connect(tab, box.FocusLost, function()
        current = box.Text
        NierUI.fire(opts, false, current)
    end)

    return NierUI.bind(tab, opts, {
        SetEnabled = function(_, on) rowApi.setEnabled(on) end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
        Get = function(_) return box.Text end,

        -- CHANGED -- ПРО НАБОР РУКАМИ, И ПРОГРАММНАЯ ПОДСТАНОВКА ЕГО НЕ ЗОВЁТ.
        --
        -- Раньше звала: присваивание в box.Text поднимает ту же подписку, что и
        -- нажатие клавиши, и Set(текст, true) -- то самое «молча» -- честно
        -- сообщал о наборе, которого не было. На этом уже спотыкался список
        -- привязок: он ставит имя из профиля таким Set, а поле отвечало ему
        -- «человек печатает».
        --
        -- Гасится это НЕ флагом: события в Roblox приходят отложенно, и снятый
        -- сразу после присваивания флаг подписчик прочитал бы уже снятым.
        -- Поэтому current ставится ВПЕРЁД -- подписка сравнивает с ним и выходит
        -- первой же строкой.
        Set = function(_, text, silent)
            local value = tostring(text or "")
            if maxLength then value = U.textCut(value, maxLength) end
            current = value
            box.Text = value
            NierUI.fire(opts, silent, current)
        end,
    })
end)
