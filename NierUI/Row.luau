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

--=============================================================================
-- ОБРАТНЫЙ ВЫЗОВ ВЫЗЫВАЮЩЕГО -- ОДНИМ МЕСТОМ НА ВСЕ ВИДЖЕТЫ
--=============================================================================
--
-- Приём был скопирован дюжину раз по семи файлам: «молчим, если просили
-- молчать; зовём под pcall, чтобы чужая ошибка не уронила меню». Копии успели
-- разойтись в единственном, что в них есть: три ругались в консоль именем
-- строки, остальные глотали ошибку молча -- то есть обработчик вызывающего мог
-- падать на каждый щелчок, а снаружи это выглядело как «строка не работает».
--
-- silent -- тот самый второй аргумент Set во всей библиотеке. Он гасит
-- обратный вызов ВЫЗЫВАЮЩЕГО и ничего больше: собственный вид строки рисуется
-- в любом случае, иначе загрузка профиля меняла бы значения молча и меню врало
-- бы до первого щелчка руками.
function NierUI.fire(opts, silent, ...)
    if silent or not opts.Callback then return end
    local ok, err = pcall(opts.Callback, ...)
    if not ok then
        warn("[NierUI] " .. tostring(opts.Text or "?") .. ": " .. tostring(err))
    end
end

-- valueClass -- "TextLabel" (по умолчанию) или "TextBox" для редактируемого
-- значения. Раньше ползунок получал подпись, гасил её и рисовал поле рядом
-- сам: в строке оставался мёртвый объект, а зарегистрированная на него
-- инверсия работала вхолостую. Теперь каркас сразу отдаёт нужный тип.
--
-- Поле НЕ ставится по умолчанию намеренно: TextBox перехватывает щелчки, и у
-- переключателя нажатие по «[ ON ]» перестало бы переключать строку.
-- opts -- те же настройки, что виджет получил снаружи. Нужны каркасу ровно для
-- одного: подключить меню правой кнопки ЗДЕСЬ, а не в каждом виджете отдельно.
--
-- Раньше настройки строки были привилегией переключателя -- единственного, кто
-- звал rowApi.settings. Ни у палитры, ни у списка, ни у поля ввода поле Settings
-- не работало вовсе, и заметить это можно было только по тому, что ничего не
-- происходит. Меню обязано быть у ЛЮБОЙ строки, а перечислять виджеты по одному
-- значит однажды забыть очередной.
function NierUI.makeRow(tab, text, desc, valueClass, opts)
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

    -- ДОЛИ ПОДПИСИ И ЗНАЧЕНИЯ МОЖНО ЗАДАТЬ СТРОКЕ ОТДЕЛЬНО.
    --
    -- Умолчания рассчитаны на страницу вкладки. В узком контейнере -- меню
    -- правой кнопки шириной 220 -- те же доли дают под значение полсотни
    -- пикселей, и «NO COOLDOWN» превращается в «NO». Виноваты не умолчания, а
    -- то, что их нечем было поправить на месте: у строки с длинным значением и
    -- коротким названием соотношение обратное обычному.
    local labelFrac = (opts and opts.LabelFrac) or THEME.LabelFrac
    local valueFrac = (opts and opts.ValueFrac) or THEME.ValueFrac

    local label = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = text or "", TextColor3 = THEME.Ink, TextSize = THEME.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(labelFrac, 0, 0, THEME.RowHeight), ZIndex = 3,
    }, row)

    local value
    if valueClass == "TextBox" then
        -- Ширина РОВНО ПО ТЕКСТУ: растянутое на всю колонку поле ловило бы
        -- щелчки далеко левее видимого числа, в том числе те, что метят в
        -- дорожку ползунка. Растёт от правого края влево, поэтому число стоит
        -- на месте и не съезжает при наборе длинного значения. Нижний предел --
        -- чтобы в пустое поле было чем попасть.
        --
        -- ДОЛЯ ВМЕСТО РОСТА ПО СОДЕРЖИМОМУ -- ЭТО Width, И ОН ТОЖЕ ЗДЕСЬ.
        --
        -- У числа длина короткая и предсказуемая, у произвольного текста -- нет:
        -- растущее поле уползало бы влево под подпись строки. Раньше это чинил у
        -- себя сам виджет -- гасил AutomaticSize, переписывал размер и СНОСИЛ
        -- ограничитель, поставленный каркасом строкой выше. Каркас, который
        -- строит объект и тут же даёт его разобрать, -- не каркас; проще сразу
        -- построить то, что просят.
        local width = opts and opts.Width
        value = U.new("TextBox", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = "", TextColor3 = THEME.InkSoft, TextSize = THEME.TextSize,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextEditable = true, ClearTextOnFocus = false,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 0),
            Size = width and UDim2.new(width, 0, 0, THEME.RowHeight)
                or UDim2.fromOffset(0, THEME.RowHeight),
            AutomaticSize = width and Enum.AutomaticSize.None
                or Enum.AutomaticSize.X,
            ZIndex = 3,
        }, row)
        -- Ограничитель нужен только растущему полю: доля и так не схлопывается.
        if not width then
            U.new("UISizeConstraint", { MinSize = Vector2.new(22, THEME.RowHeight) }, value)
        end
    else
        value = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = "", TextColor3 = THEME.InkSoft, TextSize = THEME.TextSize,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 0),
            Size = UDim2.new(valueFrac, 0, 0, THEME.RowHeight), ZIndex = 3,
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
        -- НЕ `on and e.on or e.off`: подписать можно ЛЮБОЕ свойство, в том числе
        -- булево, и подписанный false молча превратился бы в «обычное» значение.
        -- Ровно эта ловушка уже трижды стоила библиотеке поломки.
        for _, e in ipairs(inverts) do
            if on then e.inst[e.prop] = e.on else e.inst[e.prop] = e.off end
        end
        marker.BackgroundTransparency = on and 0 or 1

        if not enabled then
            label.TextColor3 = THEME.Disabled
            value.TextColor3 = THEME.Disabled
        end

        for _, paint in ipairs(painters) do paint(on, enabled) end
    end

    local window = tab.window
    NierUI.connect(tab, row.MouseEnter, function()
        hovered = true
        paintRow()
        if desc then window:Hint(desc) end
    end)
    NierUI.connect(tab, row.MouseLeave, function()
        hovered = false
        paintRow()
    end)

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

    --== ПРАВАЯ КНОПКА У СТРОКИ ОДНА =========================================
    --
    -- Поводов два -- Menu и Settings, -- а нажатие одно, и разделить их нечем:
    -- обе цели встают на ОДИН И ТОТ ЖЕ фрейм строки, с одинаковой глубиной в
    -- дереве. Диспетчер выбирает по глубине (см. Context), при равенстве
    -- побеждает зарегистрированная позже -- то есть Settings, а Menu не
    -- открывался бы НИКОГДА.
    --
    -- Молча -- худший из возможных исходов: точка на месте, правая кнопка что-то
    -- открывает, и понять, что открылось не то, можно только сверившись с
    -- кодом. Поэтому ошибка, как на занятом Flag и на занятой клетке блока.
    --
    -- Уровень 0: строку с ошибкой всё равно не показать честно -- виджет
    -- зовётся через воронку containerIndex, и любой конкретный уровень указал бы
    -- внутрь библиотеки. Имя строки в сообщении однозначнее номера.
    local m2Claim = false
    local function claimContext(what)
        if m2Claim then
            error(("[NierUI] у строки «%s» правая кнопка уже занята (%s): "
                .. "Menu и Settings на одной строке несовместимы -- нажатие "
                .. "одно, а открывать пришлось бы двоих. Переложите настройки "
                .. "внутрь Menu."):format(tostring(text or "?"), m2Claim), 0)
        end
        m2Claim = what
    end

    --== метка «здесь есть правая кнопка» ====================================
    --
    -- Одна на строку, сколько бы поводов ни было: без метки правая кнопка --
    -- знание, которое неоткуда взять, а две точки подряд означали бы, что
    -- поводов два, чего не бывает.
    local dot = false
    local function markDot()
        if dot then return dot end
        dot = U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BackgroundTransparency = 0.4,
            BorderSizePixel = 0, Active = false,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -2, 0, math.floor(THEME.RowHeight / 2)),
            Size = UDim2.fromOffset(4, 4), ZIndex = 3,
        }, row)

        -- Точка нарисована чернилами, а под курсором строка заливается ими же --
        -- метка сливалась с подложкой и пропадала ровно там, где нужна. Это тот
        -- самый случай, для которого инверсия и заведена: два вида, обычный и
        -- под курсором, подписываем свойство и забываем.
        invert(dot, "BackgroundColor3", THEME.Bg, THEME.Ink)
        paintRow()
        return dot
    end

    --== МЕНЮ ПРАВОЙ КНОПКИ ==================================================
    --
    --     tab:Toggle({
    --         Text = "ПОЛЁТ",
    --         Menu = function(m)
    --             m:Keybind({ Text = "КЛАВИША", Default = Enum.KeyCode.F })
    --             m:Slider({ Text = "СКОРОСТЬ", Min = 16, Max = 100 })
    --         end,
    --     })
    --
    -- В отличие от Settings, где набор контролов выводится из значений, здесь
    -- вызывающий кладёт В МЕНЮ ЛЮБЫЕ ВИДЖЕТЫ -- те же самые, что и во вкладку.
    -- Меню это контейнер (см. Panel), и виджеты о нём ничего не знают.
    --
    -- СОДЕРЖИМОЕ СТРОИТСЯ СРАЗУ, А НЕ ПРИ ПЕРВОМ ОТКРЫТИИ. Отложенная сборка
    -- сэкономила бы память на неоткрытых меню, но заплатить за неё пришлось бы
    -- заметной задержкой ровно в тот момент, когда по строке нажали, -- а меню
    -- обязано появляться мгновенно. Один раз на загрузке дешевле, чем один раз
    -- на каждом первом нажатии.
    function rowApi.menu(container, title, builder, width)
        if type(builder) ~= "function" then return end

        local window = container.window
        local menu = NierUI.panel(window, { Width = width })
        builder(menu)

        -- Пустое меню метки не получает и на правую кнопку не отзывается:
        -- обещать окно, в котором ничего нет, хуже, чем не обещать ничего.
        if menu.rows == 0 then
            menu:Destroy()
            return
        end

        -- Ключ памяти положения выдаётся ОДИН раз на меню. Сгенерируй его внутри
        -- открытия -- он менялся бы на каждое нажатие, и запомненное место
        -- никогда бы не нашлось.
        local placeId = "menu\0" .. U.randomName()

        -- Оставляем меню воронке в containerIndex: она поставит ему владельца,
        -- как только виджет вернёт handle. Раньше этого момента владельца не
        -- существует -- мы внутри его же постройки.
        container.pendingMenu = menu

        -- Заявка на правую кнопку -- ПОСЛЕ отказа от пустого меню: пустое её не
        -- занимает и Settings не мешает.
        claimContext("Menu")
        markDot()
        NierUI.contextTarget(window, row, function(onClosed)
            if not enabled then return nil end
            menu:Open({ Anchor = row, Title = title, OnClose = onClosed,
                        Place = placeId })
            return function() menu:Close() end
        end, THEME.RowHeight)

        return menu
    end

    --== настройки строки по правой кнопке ===================================
    --
    -- Тот же механизм, что у пунктов списка, но для ЛЮБОЙ строки. Раньше
    -- настройки были привилегией пунктов, хотя причина этому была только
    -- историческая: строке они нужны ничуть не реже -- клавиша активации,
    -- дополнительный цвет, режим.
    --
    -- Строка с настройками помечается точкой справа: без метки правая кнопка --
    -- знание, которое неоткуда взять.
    function rowApi.settings(window, title, spec, state, onChange)
        if not spec or next(spec) == nil then return end

        --== ТИП ВЫВОДИТСЯ ИЗ ЗНАЧЕНИЯ, И НЕВЫВОДИМОЕ -- ОШИБКА ===============
        --
        -- Веток разбора четыре: описание ползунка, Color3, EnumItem, boolean.
        -- Всё остальное молча рисовало подпись и НИЧЕГО -- ни контрола, ни
        -- ошибки. Самая частая опечатка при этом ровно такая: голое 1000 вместо
        -- описания ползунка, потому что по числу диапазон не угадать.
        -- Библиотека в остальных таких случаях ругается вслух -- на занятый
        -- Flag, на Menu с Settings, на неизвестный виджет.
        --
        -- Проверяем ЗДЕСЬ, при постройке строки, а не при открытии окошка:
        -- ошибка должна прилетать на загрузке и указывать на строку, а не
        -- через полчаса, когда по ней впервые щёлкнут правой кнопкой.
        for field, descriptor in pairs(spec) do
            local value = NierUI.settingDefault(descriptor)
            local kind = typeof(value)
            local ok = kind == "Color3" or kind == "EnumItem" or kind == "boolean"
                or (type(descriptor) == "table" and descriptor.Type ~= nil)
            if not ok then
                error(("[NierUI] строка «%s», настройка «%s»: по значению типа "
                    .. "%s контрол не выводится. Цвет -- Color3, клавиша -- "
                    .. "EnumItem, флаг -- boolean, число -- { Type = \"Slider\", "
                    .. "Default = ..., Min = ..., Max = ... }.")
                    :format(tostring(text or "?"), tostring(field), kind), 0)
            end
        end

        claimContext("Settings")
        markDot()

        -- ЧЕРЕЗ РЕЕСТР ОКНА, А НЕ ЧЕРЕЗ MouseButton2Click НА СТРОКЕ.
        --
        -- Пока открыто хоть одно всплывающее окно, его фон-перехватчик забирает
        -- правую кнопку себе, и до строки она не доходит -- открыть настройки
        -- второго пункта, не закрыв первый, было нельзя. См. Context.
        -- Целью считается только ПЕРВАЯ строка: у списка и палитры раскрытая
        -- панель лежит внутри строки и растит её, и без этого правая кнопка по
        -- раскрытой палитре открывала бы настройки строки вместо своего.
        -- Ключ памяти положения -- СТРОКА, а не сама строка меню.
        --
        -- Окно настроек порождает вложенные (палитра), и их ключи строятся
        -- склейкой от родительского. Instance склеить нельзя, а tostring по
        -- нему даёт всего лишь имя -- у двух строк оно совпадёт запросто.
        -- Собственное имя выдаётся один раз и живёт со строкой.
        local placeId = "row\0" .. U.randomName()

        NierUI.contextTarget(window, row, function(onClosed)
            if not enabled then return nil end
            return NierUI.optionSettings(window, {
                Anchor = row, Title = title,
                Spec = spec, State = state, OnChange = onChange,
                OnClose = onClosed, Place = placeId,
            })
        end, THEME.RowHeight)
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

    -- Меню подключается САМИМ каркасом: виджету для этого ничего делать не надо,
    -- и новый виджет получает правую кнопку просто потому, что строит строку.
    --
    -- КРОМЕ СТРОКИ С ПРИВЯЗКОЙ. Ядру надо вложить в её меню свои редакторы, а
    -- привязки в этот момент ещё не существует -- мы внутри постройки виджета,
    -- который её и заведёт. Такая строка зовёт rowApi.menu сама, одним
    -- построителем на своё и на наше; заявка на правую кнопку одна, и спор за
    -- неё не возникает.
    --
    -- Признаков три, потому что объявить привязку можно тремя способами:
    -- Bind -- рубильник, Binds -- взаимодействия, bind -- готовая запись,
    -- которую ядро подсовывает строке клавиши. Правило при этом одно.
    local ownMenu = opts
        and (opts.Bind ~= nil or opts.Binds ~= nil or opts.bind ~= nil)

    if opts and opts.Menu and not ownMenu then
        rowApi.menu(tab, opts.MenuTitle or text, opts.Menu, opts.MenuWidth)
    end

    --== НАСТРОЙКИ ТОЖЕ ПОДКЛЮЧАЕТ КАРКАС ====================================
    --
    -- Раньше это делал ТОЛЬКО переключатель, у себя в файле. Комментарий выше
    -- уверял, что настройки положены любой строке, -- и это было неправдой:
    -- Settings у ползунка, палитры, списка и поля ввода не работал вовсе, и
    -- заметить это можно было лишь по тому, что ничего не происходит.
    --
    -- Состояние копируется в СВОЁ: править переданный spec нельзя, он может
    -- быть общей на несколько строк таблицей.
    --
    -- Наружу оно уходит через воронку в containerIndex -- там, где известен
    -- готовый handle. Виджету для этого делать не надо ничего, ровно как с меню.
    if opts and opts.Settings then
        local state = {}
        for key, default in pairs(opts.Settings) do
            state[key] = NierUI.settingDefault(default)
        end
        rowApi.settings(tab.window, opts.Text or text or "",
            opts.Settings, state, opts.OnSetting)
        tab.pendingSettings = { state = state, onChange = opts.OnSetting }
    end

    --== НЕДОСТУПНОСТЬ ОБЪЯВЛЕНИЕМ -- ТОЖЕ РАБОТА КАРКАСА ====================
    --
    -- `if opts.Enabled == false then rowApi.setEnabled(false) end` стояло
    -- ПОСЛЕДНЕЙ строкой в восьми виджетах подряд: тот самый случай, когда каждый
    -- доделывает за каркас одно и то же. И, как всякий переписанный по образцу
    -- список, он оказался неполным -- у списка этой строки не было вовсе, и
    -- Enabled = false у него не делал НИЧЕГО, при том что поле обещано всем
    -- виджетам разом (см. docs/widgets.md).
    --
    -- Radio сюда не относится: он не строка, а несколько строк, и гасит их
    -- перебором у себя.
    if opts and opts.Enabled == false then rowApi.setEnabled(false) end

    return row, label, value, invert, setHeld, rowApi
end

--=============================================================================
-- Дорожка с заливкой
--=============================================================================
--
-- Одна геометрия на ползунок и на полосу выполнения, и это не совпадение, а
-- требование: они стоят в соседних строках и обязаны быть вровень. Пока копий
-- было две, «вровень» держалось на том, что обе правили одинаково, -- а долей в
-- Theme четыре, и разъехаться им хватило бы одной невнимательной правки.
--
-- Дорожка задана долями (см. Theme): правым краем на TrackRight, шириной
-- TrackFrac, по центру ПЕРВОЙ строки -- строка может вырасти, и центрирование
-- по её высоте увело бы дорожку вниз.
--
-- Отличий у двух дорожек ровно два: толщина и то, светлеет ли она под курсором.
-- invert строка отдаёт свой: дорожка нарисована чернилами, а под курсором
-- строка заливается ими же -- без подписи на инверсию ползунок пропадал бы
-- вместе с фоном (см. шапку файла).
function NierUI.makeTrack(row, invert, thickness, dim, dimHot)
    local track = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        BackgroundTransparency = dim, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(THEME.TrackRight, 0, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.new(THEME.TrackFrac, 0, 0, thickness), ZIndex = 3,
    }, row)
    -- Ограничитель держит дорожку в разумных пределах: на широкой странице она
    -- не растягивается бесконечно, на узкой не схлопывается в точку, по которой
    -- нечем попасть.
    U.new("UISizeConstraint", {
        MinSize = Vector2.new(36, thickness),
        MaxSize = Vector2.new(110, thickness),
    }, track)

    local fill = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
    }, track)

    invert(track, "BackgroundColor3", THEME.Bg, THEME.Ink)
    invert(fill, "BackgroundColor3", THEME.Bg, THEME.Ink)
    -- Полоса выполнения под курсором не светлеет: тянуть её нечем, и лишний
    -- отклик обещал бы, что можно.
    if dimHot then invert(track, "BackgroundTransparency", dimHot, dim) end

    return track, fill
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

--=============================================================================
-- Раскрытие блока щелчком по строке
--=============================================================================
--
-- Одинаково у списка и у палитры -- вместе с тонкостью, которую порознь
-- пришлось бы чинить дважды.
--
-- ЩЕЛЧОК ВНУТРИ РАСКРЫТОЙ ПАНЕЛИ НЕ СХЛОПЫВАЕТ СТРОКУ. Active = true на панели
-- оказалось НЕ достаточно: панель лежит внутри самой строки, а не поверх неё, и
-- нажатие по палитре всё равно доходило до строки-кнопки -- выбор цвета
-- схлопывал палитру на отпускании. У списка то же самое: пункты -- кнопки и
-- щелчок съедают сами, а поля вокруг них нет.
--
-- Однажды это чинил сторож «сейчас тянем»; потом его убрали, посчитав мёртвым
-- по рассуждению, а не по замеру, -- и вернули поломку. Теперь проверка не про
-- перетаскивание, а про МЕСТО: MouseButton1Click координат не несёт, поэтому
-- окно помнит точку последнего нажатия. Это ловит и простой щелчок без
-- движения, чего прежний сторож не умел.
--
-- apply(раскрыто) -- что делать при смене; сам флаг держит каркас. Наружу
-- уходит setOpen, потому что закрывают блок не только щелчком: строку могли
-- выключить, а у одиночного списка выбор пункта закрывает его сам.
function NierUI.rowExpand(container, row, rowApi, panel, apply)
    local window = container.window
    local open = false

    local function setOpen(state)
        open = state
        apply(state)
    end

    NierUI.connect(container, row.MouseButton1Click, rowApi.gate(function()
        if open and U.inside(panel, window.lastPress) then return end
        setOpen(not open)
    end))

    return setOpen
end
