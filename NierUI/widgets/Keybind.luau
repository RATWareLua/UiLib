--!nocheck
--=============================================================================
-- Keybind -- РЕДАКТОР КЛАВИШИ
--=============================================================================
--
-- Строка, которая показывает клавишу привязки и даёт её сменить. Ничего больше:
-- ни собственного значения, ни собственного обработчика нажатия, ни учёта в
-- списке привязок -- всем этим владеет ядро (см. Binds).
--
--     любая клавиша, правая или средняя мыши -- назначить
--     Escape                                 -- отменить, оставить как было
--     Backspace                              -- снять привязку совсем
--
--
-- ДВА СПОСОБА ОБЪЯВИТЬ, НО ПРИВЯЗКА ОДНА
--
--     tab:Keybind({ Text = "ПАНИКА", Flag = "panic", Default = Enum.KeyCode.G,
--                   Callback = function() ... end })
--
-- заводит привязку-действие само; а внутренним полем bind ядро подсовывает уже
-- готовую запись, когда строит редактор в меню строки (см. NierUI.bindRows).
--
-- Раньше здесь было иначе: виджет ХРАНИЛ клавишу, вешал свою пару подписок на
-- ввод, вёл собственную запись в реестре и сам переключал строку-владельца.
-- Отсюда и брались все вопросы про то, чьё состояние показывать: у одного факта
-- было два хозяина. Теперь хозяин один, а это -- вид.
--
--
-- ЖДЁМ НАЖАТИЕ ЧУЖИМИ РУКАМИ, И ЭТО ГЛАВНАЯ ПРАВКА
--
-- Танец «взвести захват, дождаться клавиши, отменить по Escape, снять по
-- Backspace, применить со следующего кадра» жил в библиотеке ДВАЖДЫ -- здесь и
-- в окне настроек, -- и копии успели разойтись: вторая принимала только
-- Enum.KeyCode и снимать привязку не умела вовсе. Теперь обе зовут ядро.
--
-- Заодно оттуда пришло то, чего не было ни в одной: ждущий ВСЕГДА ОДИН.
-- Щёлкнул строку, передумал, щёлкнул соседнюю -- прежняя отменяется. Раньше
-- ждали обе и одно нажатие назначалось ОБЕИМ.

NierUI.widget("Keybind", function(tab, opts)
    local row, label, value, _, setHeld, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)

    local window = tab.window

    -- Своя запись или чужая. Своя -- это действие: у строки-редактора состояния
    -- нет и быть не может, показывать ей нечего кроме клавиши.
    local bind = opts.bind or window.binds:Add({
        Flag = opts.Flag, rowTitle = opts.Text, row = row,
        Key = opts.Default, Action = opts.Callback,
    })

    -- ПРАВАЯ КНОПКА -- НАСТРОЙКИ ЭТОЙ ПРИВЯЗКИ.
    --
    -- Левая назначает клавишу, правая открывает то, что к клавише не относится:
    -- режим и подпись. Строим сами и одним построителем -- заявка на правую
    -- кнопку у строки одна, спорить за неё не с кем (см. Row).
    rowApi.menu(tab, opts.MenuTitle or bind:Title(), function(menu)
        -- manage приходит только от менеджера привязок: у него права выше, см.
        -- bindOptions. Обычная строка меню его не ставит и не может.
        NierUI.bindOptions(menu, bind, opts.manage)
        if opts.Menu then
            menu:Divider()
            opts.Menu(menu)
        end
    end, opts.MenuWidth)

    -- Чем отпустить ожидание. false -- не ждём ничего.
    local waiting = false

    local function render()
        value.Text = waiting and "[ ... ]" or bind:KeyName()
    end
    render()

    -- Снять ожидание одним куском: поводов к нему три -- пришла клавиша, строку
    -- выключили, отменили по Escape. Забыть отпустить захват хотя бы в одном
    -- значит оставить его взведённым НАВСЕГДА, а с ним перестают работать и
    -- клавиша меню, и все привязки разом.
    local function stopWaiting()
        if not waiting then return end
        local release = waiting
        waiting = false
        setHeld(false)
        release()
        render()
    end

    NierUI.connect(tab, row.MouseButton1Click, rowApi.gate(function()
        if waiting then return end
        setHeld(true)
        waiting = bind:Capture(function()
            waiting = false
            setHeld(false)
            render()
        end)
        render()
    end))

    -- КЛАВИШУ МОГЛИ СМЕНИТЬ НЕ ЗДЕСЬ: из менеджера привязок, загрузкой профиля,
    -- вызовом SetKey из кода. Ничего не кешируем -- перерисовываемся по поводу.
    --
    -- Отсюда же уходит Changed вызывающему. Раньше он звался ТОЛЬКО когда
    -- клавишу назначили щелчком по этой самой строке -- то есть о смене из
    -- профиля или из кода тот, кто на него подписан, не узнавал вовсе. Теперь
    -- повод один на все источники, потому что и источник правды один.
    local unwatch = window.binds:Changed(function(changed, what)
        if what ~= "key" then return end
        if changed ~= nil and changed ~= bind then return end
        render()
        if opts.Changed then pcall(opts.Changed, bind:Key()) end
    end)
    table.insert(NierUI.sink(tab), { Disconnect = unwatch })

    if opts.Enabled == false then rowApi.setEnabled(false) end

    return NierUI.bind(tab, opts, {
        -- Клавиша, режим и подпись уезжают в профиль вместе с самой привязкой
        -- (см. Config): у строки-редактора собственного значения нет.
        --
        -- СПИСКОМ, хотя она здесь одна: у строки бывает и рубильник, и сколько
        -- угодно взаимодействий, и кодек не должен знать двух форм одного и
        -- того же. Одна форма -- один разбор.
        binds = opts.bind and {} or { bind },

        Get = function(_) return bind:Key() end,
        Set = function(_, key) bind:SetKey(key) end,
        -- Подпись строки меняется наравне со значением: менеджеру привязок надо
        -- поправить её при переименовании, а пересобирать ради этого весь
        -- список значило бы захлопнуть открытое меню под руками у того, кто
        -- прямо сейчас в нём печатает.
        SetText = function(_, text) label.Text = tostring(text) end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Ждали нажатие в момент выключения -- ожидание надо снять, иначе
            -- строка останется подсвеченной навсегда, а захват -- взведённым,
            -- и клавиатура не вернётся никому.
            if not on then stopWaiting() end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)
