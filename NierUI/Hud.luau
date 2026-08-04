--!nocheck
--=============================================================================
-- Hud -- то, что видно при закрытом меню
--=============================================================================
--
--     local hud = win:Hud({ Title = "STATS", X = 20, Y = 20 })
--     win:FpsCounter({ X = 20, Y = 20 })
--     win:BindList({ X = 20, Y = 60, Mode = "active" })
--
-- Всё три -- один и тот же контейнер (см. Panel) в постоянном режиме показа.
-- Счётчик и список привязок не отдельные сущности, а готовая начинка: общий
-- каркас вышел ДЕШЕВЛЕ двух самостоятельных виджетов, а не дороже.
--
--
--=============================================================================
-- ЗДЕСЬ ЕДИНСТВЕННОЕ МЕСТО В БИБЛИОТЕКЕ С ПОКАДРОВОЙ ПОДПИСКОЙ
--=============================================================================
--
-- Кадры в секунду нельзя посчитать иначе, чем считая кадры. Это прямо
-- противоречит правилу «ничего не работает, пока ничего не происходит», и
-- обойти это нечем -- происходит как раз каждый кадр.
--
-- Оговорка касается ТОЛЬКО счётчика кадров. Список привязок покадрового не
-- имеет: он перерисовывается по сообщению от того, у кого изменилось (см.
-- NierUI.stateChanged). Здесь был опрос -- и это была ошибка, а не компромисс.
--
-- У счётчика же:
--
--   подписка ОДНА, RunService.RenderStepped;
--   живёт, ТОЛЬКО пока счётчик показан -- спрятали, и её нет;
--   гаснет в Destroy вместе с контейнером и окном.
--
-- Это по-прежнему не то, чем болел CompKiller: там были вечные `while true do
-- task.wait() end`, переживавшие снос интерфейса. Здесь коннект с записанным
-- временем жизни, который выключается вместе с тем, ради чего заведён.
--
-- Подпись обновляется НЕ каждый кадр, а раз в UPDATE секунды: перерисовывать
-- текст полтораста раз в секунду незачем, а число, дёргающееся быстрее, чем его
-- успевает прочесть глаз, ещё и бесполезно.
--
--
-- СГЛАЖИВАНИЕ ОБЯЗАТЕЛЬНО, А НЕ ДЛЯ КРАСОТЫ
--
-- Мгновенное 1/dt скачет на десятки даже при ровной картинке -- дрожит уже
-- целая часть, не то что десятая. Просили десятую, значит она должна что-то
-- означать. Считаем среднее по окну и подмешиваем к предыдущему.

local RunService = game:GetService("RunService")

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

local UPDATE = 0.2       -- как часто обновлять подпись
local BLEND = 0.4        -- насколько новое окно вытесняет прежнее значение

--=============================================================================
-- Общий слой
--=============================================================================

-- Слой создаётся ВСЕГДА, даже когда заведён спрятанным.
--
-- Иначе у невидимого худа нет ни кадра, ни положения, и сохранять в профиль
-- нечего: включил его человек через месяц -- и слой встал бы в умолчание, хотя
-- место для него было выбрано давным-давно.
local function mount(panel, opts)
    panel:Show(opts)
    if opts.Visible == false then panel:Hide() end
end

-- Положение худа -- НАСТРОЙКА, и идёт в профиль наравне с остальными.
--
-- Видимостью отсюда не управляем намеренно: ею почти всегда заведует отдельный
-- тумблер вызывающего, у него свой Flag, и два хозяина у одного значения
-- означали бы, что при загрузке побеждает тот, кого профиль применил последним,
-- -- а порядок обхода профиля не определён.
local function placeHandle(window, panel, opts)
    local handle = {
        Get = function(_)
            local x, y = panel:Place()
            if not x then return nil end
            return { X = x, Y = y }
        end,
        Set = function(_, v)
            if type(v) == "table" then panel:MoveTo(v.X, v.Y) end
        end,
    }
    NierUI.bindFlag(window, opts.Flag, handle, 3, opts.Save)
    return handle
end

function Window:Hud(opts)
    opts = opts or {}
    local panel = NierUI.panel(self, { Width = opts.Width or 150 })
    mount(panel, opts)
    placeHandle(self, panel, opts)
    return panel
end

-- Строка текста без каркаса строки: у худа нет ни наведения, ни значения, ни
-- нижней панели -- он не принимает, а показывает. Полноценная строка потащила
-- бы за собой подсветку и щелчки, которые тут некому обрабатывать.
local function line(panel, size)
    panel.rows = panel.rows + 1
    return U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = "", TextColor3 = THEME.Ink, TextSize = size or THEME.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Size = UDim2.new(1, 0, 0, (size or THEME.TextSize) + 4),
        LayoutOrder = panel.rows,
    }, panel.page)
end

--=============================================================================
-- Счётчик кадров
--=============================================================================

function Window:FpsCounter(opts)
    opts = opts or {}

    local panel = NierUI.panel(self, { Width = opts.Width or 96 })

    local label = line(panel, opts.TextSize or THEME.TextSize)
    label.Text = "FPS: --"

    local smooth, frames, elapsed = 0, 0, 0
    local conn = false

    local function stop()
        if not conn then return end
        conn:Disconnect()
        conn = false
    end

    local function start()
        if conn then return end
        frames, elapsed = 0, 0
        conn = RunService.RenderStepped:Connect(function(dt)
            frames = frames + 1
            elapsed = elapsed + dt
            if elapsed < UPDATE then return end

            local instant = frames / elapsed
            -- Первое значение берём как есть: подмешивать его к нулю значило бы
            -- показать полсотни там, где на деле полтораста.
            smooth = smooth > 0 and (smooth + (instant - smooth) * BLEND) or instant
            frames, elapsed = 0, 0
            label.Text = ("FPS: %.1f"):format(smooth)
        end)
        -- Коннект держим В СВОЕЙ переменной, а не сваливаем в сток контейнера.
        -- Показ и скрытие чередуются сколько угодно раз, и каждый вызов start
        -- дописывал бы в список ещё одну запись -- список рос бы без конца, а
        -- мёртвые записи в нём копились. Здесь ссылка одна, и stop её гасит.
    end

    mount(panel, opts)
    placeHandle(self, panel, opts)
    -- Снесли окно, не тронув счётчик -- подписка обязана уйти вместе с ним.
    -- Своей ссылкой она не в стоке контейнера, значит сама бы не погасла.
    panel:OnDestroy(stop)
    if opts.Visible ~= false then start() end

    return {
        SetVisible = function(_, on)
            on = on ~= false
            panel:SetVisible(on)
            -- ПОДПИСКУ СНИМАЕМ ВМЕСТЕ С ПОКАЗОМ. Спрятанный счётчик, который
            -- продолжает считать каждый кадр, -- ровно то, чего библиотека и
            -- не допускает.
            if on then start() else stop() end
        end,
        IsVisible = function(_) return panel:IsVisible() end,
        Get = function(_) return smooth end,
        Set = function(_, on) return on end,
        Destroy = function(_) stop() panel:Destroy() end,
        panel = panel,
    }
end

--=============================================================================
-- Список привязок
--=============================================================================
--
-- Mode = "all"     все привязки, каждая с пометкой [ON] или [OFF]
-- Mode = "active"  только включённые, с пометкой [ON]
--
-- ЧТО СЧИТАЕТСЯ ВКЛЮЧЁННЫМ -- ОТВЕЧАЕТ САМА ПРИВЯЗКА, одним вызовом Get.
--
-- Прежде состояние выводилось из РАЗМЕТКИ: список искал строку-владельца по
-- контейнеру, в котором привязка объявлена, и показывал её состояние. Отсюда и
-- бралась главная ложь этого экрана -- у тумблера ПОЛЁТ спрашивалось «включён
-- ли он», а показать надо было «летим ли мы». А привязке вне меню владельца
-- было неоткуда взять вовсе, и ей дописывали State руками.
--
-- Теперь у каждой привязки есть ровно один хозяин её состояния, и он же на
-- вопрос отвечает (см. Binds). Ни владельцев, ни State, ни запасных вариантов.
--
-- ПЕРЕРИСОВЫВАЕТСЯ ПО СОБЫТИЮ, А НЕ ПО ТАЙМЕРУ. Здесь был написан опрос -- и
-- это было прямым нарушением того, на чём стоит вся библиотека: ничего не
-- работает, пока ничего не происходит. Тумблер и так знает момент, когда его
-- переключили, привязка -- когда её переназначили; они и сообщают.

-- Три исхода, а не два: true, false и nil.
--
-- nil -- это ДЕЙСТВИЕ, а не «выключено». Привязка на кнопку PANIC ничего не
-- держит включённым: она срабатывает в момент нажатия и на этом всё. Показывать
-- ей [OFF] значит врать -- выглядит как отключённая фича, хотя нажми её, и она
-- сработает. Поэтому у неё написано, ЧТО ОНА ТАКОЕ.
--
--
-- ЗДЕСЬ БОЛЬШЕ НЕТ НИ ОДНОГО ВЫЧИСЛЕНИЯ. Раньше список сам добывал недостающее:
-- искал владельца строки по контейнеру, собирал подпись из чужих полей, выводил
-- состояние по цепочке запасных вариантов. Это была модель, построенная из
-- разметки, -- и потому она врала: у тумблера ПОЛЁТ спрашивалось «включён ли
-- он», а показать надо было «летим ли мы».
--
-- Теперь всё это спрашивается у ручки привязки одним вызовом каждое, а ручка --
-- у ядра (см. Binds). Сторонний менеджер пишется ровно этими же вызовами:
-- привилегированных потребителей у ядра нет.

--== ИМЯ ОБРЕЗАЕТСЯ ПО СИМВОЛАМ, А НЕ ПО БАЙТАМ ==============================
--
-- Сам счёт живёт в Util: тем же пределом ограничено поле ввода, и двух разборов
-- одного и того же в библиотеке уже достаточно было (см. U.textCut).
--
-- Хвостовой пробел снимаем до многоточия: «АНТИАИМ ...» читается как оборванное
-- на пустом месте, а не как продолжение слова.
local NAME_MAX = 8

local function short(text, limit)
    text = tostring(text)
    local cut = U.textCut(text, limit)
    if cut == text then return text end
    return (cut:gsub("%s+$", "")) .. "..."
end

function Window:BindList(opts)
    opts = opts or {}

    -- ИМЯ УКОРОЧЕНО, ЗНАЧИТ И ОКНО УЖЕ.
    --
    -- Прежние 240 были рассчитаны на полное имя любой длины. С пределом в восемь
    -- символов самая длинная строка -- одиннадцать глифов вместе с многоточием,
    -- и половина ширины пустовала бы просто так. Слой висит поверх игры, и
    -- лишнее место он отнимает у неё, а не у меню.
    local panel = NierUI.panel(self, { Width = opts.Width or 176 })

    local mode = opts.Mode or "all"
    local nameMax = opts.NameMax or NAME_MAX
    local size = opts.TextSize or 11

    -- ВОЗДУХ ВОКРУГ СТРОКИ, А НЕ МЕЖДУ БУКВАМИ.
    --
    -- Межбуквенного расстояния в Roblox нет вовсе: у TextLabel есть LineHeight
    -- (это про строки внутри одной подписи) и нет LetterSpacing -- проверено
    -- присваиванием на живом клиенте. Раздвинуть глифы можно было бы только
    -- вставкой тонких пробелов в сам текст, а это ломает и обрезку по символам,
    -- и поиск глазами.
    --
    -- Поэтому воздух даётся там, где он вообще существует: по вертикали между
    -- строками. Было size + 3 -- шрифт уменьшили, а шаг уменьшили сильнее, и
    -- строки сомкнулись плотнее прежнего.
    local rowH = size + 5

    local rows, empty = {}, nil

    local function rowFor(index)
        if rows[index] then return rows[index] end
        local holder = U.new("Frame", {
            BackgroundTransparency = 1, Active = false,
            Size = UDim2.new(1, 0, 0, rowH), LayoutOrder = index,
        }, panel.page)
        panel.rows = panel.rows + 1

        --== ТРИ КОЛОНКИ: ИМЯ, ТИП, КЛАВИША ==================================
        --
        -- Тип стоит у ИМЕНИ, а не у клавиши: он отвечает на вопрос «что это за
        -- привязка», а не «чем её вызвать». Справа тогда остаётся ровно одно --
        -- чем вызвать и в каком она сейчас состоянии.
        --
        -- СВОЕЙ КОЛОНКОЙ, А НЕ ХВОСТОМ К ИМЕНИ. Приписанный к имени, он уезжал
        -- бы вместе с ним в многоточие у первого же длинного названия -- то
        -- есть пропадал бы ровно там, где список длинный и разбираться в нём
        -- нужнее всего. Отдельная колонка ещё и читается сверху вниз одним
        -- взглядом, а не выискивается в конце каждой строки.
        --
        -- Доли: имени хватает укороченного, поэтому лишнее отдано клавише --
        -- «MouseButton2[OFF]» длиннее любого имени.
        --
        -- Между именем и типом ЗАЗОР, а не стык: подпись обрезана по ширине
        -- колонки, и последняя точка многоточия упиралась прямо в скобку --
        -- «ОТДАЧА У...[T]» читается как одно слово.
        local name = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = "", TextColor3 = THEME.Ink, TextSize = size,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Size = UDim2.new(0.44, 0, 1, 0),
        }, holder)

        local kind = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = "", TextColor3 = THEME.InkSoft, TextSize = size,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromScale(0.48, 0),
            Size = UDim2.new(0.14, 0, 1, 0),
        }, holder)

        local value = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = "", TextColor3 = THEME.InkSoft, TextSize = size,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
            Size = UDim2.new(0.38, 0, 1, 0),
        }, holder)

        rows[index] = { holder = holder, name = name, kind = kind, value = value }
        return rows[index]
    end

    local function refresh()
        -- НИЧЕГО НЕ КЕШИРУЕМ: всё читается у ручки при каждой перерисовке.
        -- Копия здесь однажды уже разошлась с оригиналом, и три места
        -- показывали три разных ответа про одну и ту же клавишу.
        local shown = 0
        for _, bind in ipairs(panel.window.binds:All()) do
            local state = bind:Get()

            -- ДВЕ ПОМЕТКИ: ЧТО ЭТО ЗА ПРИВЯЗКА И В КАКОМ ОНА СОСТОЯНИИ.
            --
            -- Режим виден прямо здесь, буквой, а не только в меню правой
            -- кнопки: человек, переставивший половину привязок в ЗАЖАТИЕ, иначе
            -- не может проверить, что где стоит, не открыв десяток меню.
            --
            --     [T]  ПЕРЕКЛ. -- нажал и отпустил
            --     [H]  ЗАЖАТИЕ -- работает, пока держишь
            --     [B]  действие -- сработало и всё
            --
            -- У действия второй пометки нет и быть не может: [OFF] читалось бы
            -- как «отключено», а [ON] обещало бы состояние, которого нет.
            local kind = bind:Kind()
            local letter = kind == "hold" and "H" or (kind == "action" and "B" or "T")

            local mark, tone
            if state == nil then
                -- У действия состояния нет: справа только клавиша. Пока её
                -- держат, строка горит -- иначе нажатие ничем себя не проявляет
                -- и понять, сработало ли, неоткуда.
                mark = ""
                tone = bind:Held() and THEME.Ink or THEME.InkSoft
            elseif state then
                mark, tone = "[ON]", THEME.Ink
            else
                mark, tone = "[OFF]", THEME.Disabled
            end

            -- ПРИВЯЗКА БЕЗ КЛАВИШИ НЕ ДЕЙСТВУЕТ НИЧЕМ: нажимать нечего. Раньше
            -- это выражалось тем, что записи в реестре не существовало вовсе, и
            -- виджет заводил её и убирал вручную на каждое назначение. Теперь
            -- запись живёт со строкой, а показывается по наличию клавиши -- то
            -- же правило, но без второго механизма, который надо не забыть
            -- позвать из каждого источника.
            --
            -- В режиме «только активные» действие остаётся: выключенным оно не
            -- бывает, а значит и скрывать его не за что.
            -- Shown -- решение ЧЕЛОВЕКА, принятое в менеджере: он вправе убрать
            -- с экрана привязку, о которой и так помнит. Скриптеру этого поля
            -- не выдано: чужой экран не его забота.
            if bind:Key() and bind:Shown()
                and (mode ~= "active" or state ~= false) then
                shown = shown + 1
                local ui = rowFor(shown)
                ui.name.Text = short(bind:Title(), nameMax)
                ui.kind.Text = ("[%s]"):format(letter)
                ui.kind.TextColor3 = tone
                ui.value.Text = bind:KeyName() .. mark
                ui.value.TextColor3 = tone
                ui.holder.Visible = true
            end
        end
        for index = shown + 1, #rows do rows[index].holder.Visible = false end

        -- Пустой список схлопнулся бы в полоску без единого признака, что это
        -- вообще список, а не мусор на экране.
        if not empty then empty = line(panel, size) end
        empty.Text = opts.Empty or "нет привязок"
        empty.TextColor3 = THEME.Disabled
        empty.Visible = shown == 0
    end

    -- НИКАКОГО ОПРОСА. Список перерисовывается тогда, когда есть от чего:
    -- переключили тумблер, переназначили клавишу, сменили режим, загрузили
    -- профиль. Обо всём этом сообщает ядро -- спрашивать его по таймеру значило
    -- бы работать постоянно ради того, что меняется раз в минуту.
    --
    -- ПОДПИСКА ОДНА, на ядро. Сообщение от виджетов (NierUI.stateChanged) ядро
    -- переправляет своим подписчикам само -- иначе здесь висели бы две, из
    -- которых вторую однажды забудут снять.
    --
    -- Спрятанный список не перерисовываем: показывать некому, а при следующем
    -- показе он всё равно соберётся заново.
    local live = opts.Visible ~= false

    local unwatch = self.binds:Changed(function()
        if live then refresh() end
    end)
    -- Список можно снести, не трогая окно, -- ядро его переживёт. Без снятия
    -- подписка осталась бы в ядре навсегда и перерисовывала уничтоженные
    -- строки на каждое нажатие любой привязки.
    panel:OnDestroy(unwatch)

    mount(panel, opts)
    placeHandle(self, panel, opts)
    refresh()

    return {
        SetVisible = function(_, on)
            on = on ~= false
            live = on
            panel:SetVisible(on)
            if on then refresh() end
        end,
        IsVisible = function(_) return panel:IsVisible() end,
        SetMode = function(_, value) mode = value refresh() end,
        GetMode = function(_) return mode end,
        Refresh = function(_) refresh() end,
        Destroy = function(_) live = false panel:Destroy() end,
        panel = panel,
    }
end
