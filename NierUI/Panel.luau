--!nocheck
--=============================================================================
-- Panel -- всплывающее окно как КОНТЕЙНЕР
--=============================================================================
--
--     local menu = NierUI.panel(window, { Width = 220 })
--     menu:Toggle({ Text = "ПОЛЁТ" })
--     menu:Slider({ Text = "СКОРОСТЬ", Min = 16, Max = 100 })
--     menu:Open({ Anchor = row, Title = "ПОЛЁТ" })
--
-- У него есть .page, .rows, .window и .conns -- значит он контейнер, и любой
-- виджет работает в нём, ничего не зная. Ровно тем же приёмом бесплатно поехали
-- блоки, секции и колонки: «Ни один виджет ради блоков править не пришлось».
--
--
--=============================================================================
-- СОДЕРЖИМОЕ ЖИВЁТ НЕ ВО ВСПЛЫВАЮЩЕМ ОКНЕ, А НА СТОЯНКЕ
--=============================================================================
--
-- Напрашивается строить виджеты прямо в панель окна. Так нельзя, и причина не в
-- красоте.
--
-- Всплывающее окно УНИЧТОЖАЕТСЯ при закрытии -- на этом держатся и перехватчик
-- щелчков, и стопка, и цепочки родства. Строй мы содержимое в него, оно
-- пересоздавалось бы на каждое открытие. А виджет с полем Flag регистрируется в
-- окне НАВСЕГДА: второе открытие уронило бы меню на «Flag уже занят». Плюс
-- заново заводились бы все подписки -- те самые сорок с лишним на одно меню.
--
-- Поэтому содержимое строится ОДИН раз и лежит на скрытой стоянке. Открытие --
-- это переезд страницы в свежее окно, закрытие -- переезд обратно. Виджеты при
-- этом не пересоздаются, их состояние, флаги и подписки живут ровно столько,
-- сколько живёт сам контейнер.
--
-- Стоянка ЗАДАЁТ ШИРИНУ, и это не мелочь: строки виджетов заданы долей ширины
-- (Size = UDim2.new(1, 0, ...)), и без определённой ширины у родителя раскладка
-- не считается вовсе. Ширина стоянки равна ширине окна, поэтому при переезде
-- ничего не перестраивается и не дёргается.
--
-- Стоянка невидима, но НЕ отсоединена от дерева: у отсоединённого объекта
-- AbsoluteSize равен нулю, и высоту содержимого было бы неоткуда взять. Visible
-- гасит отрисовку, но не раскладку.
--
--
-- ВЫСОТА -- ПО СОДЕРЖИМОМУ, С ЗАЖИМОМ ПО ЭКРАНУ
--
-- Считать её вызывающему, как это делает окошко настроек, здесь нельзя: он не
-- знает, из чего меню собрано, а раскрывшийся внутри список меняет высоту уже
-- после открытия. Поэтому меряем сами и пересчитываем по изменению.

local THEME = NierUI.Theme
local U = NierUI.util

local Panel = {}
Panel.__index = NierUI.containerIndex(Panel)
NierUI.PanelClass = Panel

local WIDTH = 220
local PAD = 6
local EDGE = 40          -- сколько оставить по вертикали до края экрана

-- Постоянный слой: ВЫШЕ корня окна, но НИЖЕ всплывающих окон и их перехватчика.
-- Счётчик кадров не должен закрывать собой меню, а меню -- прятаться за
-- счётчиком. Числа здесь больше не повторяются: весь порядок слоёв объявлен
-- одной таблицей, см. NierUI.layers в Util.
local HUD_Z = NierUI.layers.hud

--=============================================================================
-- Геометрия
--=============================================================================

local function topOf(self)
    return self.titled and (THEME.PopupTitleHeight + 1) or 0
end

-- Держим слой в пределах экрана. Спрашивают двое -- показ и перестановка из
-- профиля, -- и зажим у них обязан быть один: сохранённое с другого разрешения
-- положение иначе вернуло бы слой за край, где его не видно и не поймать.
local function clampToView(self, x, y)
    local view = NierUI.viewport()
    return math.clamp(math.floor(x or 0), 0, math.max(0, view.X - self.width)),
           math.clamp(math.floor(y or 0), 0, math.max(0, view.Y - THEME.RowHeight))
end

-- Высота содержимого. AutomaticSize учитывает и UIPadding, поэтому отдельно
-- добавлять его не нужно.
function Panel.Measure(self)
    return math.max(self.page.AbsoluteSize.Y, THEME.RowHeight)
end

-- Кадр, размером которого мы распоряжаемся: панель всплывающего окна или
-- постоянный слой. Отличать эти два случая на каждом шагу незачем -- разница
-- только в том, кто создал кадр и что его закрывает.
local function hostOf(self)
    if self.entry then return self.entry.panel end
    return self.hud or false
end

local function applyHeight(self)
    local panel = hostOf(self)
    if not panel then return end

    local view = NierUI.viewport()
    local top = topOf(self)
    local room = math.max(THEME.RowHeight * 2, view.Y - EDGE - top)
    local height = top + math.min(self:Measure(), room)

    panel.Size = UDim2.fromOffset(self.width, height)

    -- Выехало за нижний край -- поднимаем. Раскрытый внутри список растит окно
    -- вниз, и открытое у низа экрана меню иначе уползло бы за него целиком.
    local maxY = math.max(4, view.Y - height - 4)
    if panel.Position.Y.Offset > maxY then
        panel.Position = UDim2.fromOffset(panel.Position.X.Offset, maxY)
    end
end

-- ОКНО ПРОСМОТРА -- ОДНО НА ОБА СЛУЧАЯ, И ОНО ПРОКРУЧИВАЕТСЯ.
--
-- Высота зажата экраном (см. applyHeight), значит содержимое выше экрана
-- обязано прокручиваться -- иначе оно просто обрезается по ClipsDescendants, и
-- до нижних строк не добраться ничем. Всплывающее окно так и делало, а
-- постоянный слой держал страницу в простом кадре: список из полутора десятков
-- привязок обрывался на середине и не двигался.
--
-- Само окно просмотра строит NierUI.popupScroll: у окна настроек пунктов оно
-- третье такое же, и три копии десяти свойств прокрутки однажды разошлись бы.

--=============================================================================

function NierUI.panel(window, opts)
    opts = opts or {}
    local width = opts.Width or WIDTH

    local park = U.new("Frame", {
        BackgroundTransparency = 1, Visible = false, Active = false,
        Size = UDim2.fromOffset(width, 0), ZIndex = 1, Name = U.randomName(),
    }, window.gui)

    local page = U.new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, park)
    U.new("UIListLayout", {
        Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    U.new("UIPadding", {
        PaddingTop = UDim.new(0, PAD), PaddingBottom = UDim.new(0, PAD),
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    }, page)

    -- Как и у окна: состояние заводится ЦЕЛИКОМ здесь. Диспетчер контейнера
    -- ругается на любое отсутствующее поле, и «ещё не присвоено» от опечатки
    -- иначе не отличить.
    local self = setmetatable({
        window = window, rows = 0, page = page,
        -- Свой сток: подписки виджетов внутри гаснут вместе с контейнером, а не
        -- живут до конца окна. См. NierUI.sink.
        conns = {},
        park = park, width = width,
        entry = false, close = false, titled = false,
        -- Постоянный слой. Живёт параллельно всплывающему: контейнер либо
        -- всплывает, либо висит, но устроен одинаково.
        hud = false,
        -- Владелец -- строка, из меню которой этот контейнер открыт. Ставится
        -- воронкой в containerIndex, когда виджет вернул handle.
        owner = false, pendingMenu = false, pendingSettings = false,
        -- Что сделать при сносе сверх обычного. Нужно тем, у кого есть не только
        -- подписки: счётчик кадров держит свой коннект отдельной ссылкой, и без
        -- этого он пережил бы и контейнер, и окно.
        cleanups = {},
    }, Panel)

    -- Список или палитра внутри меню раскрываются ВНУТРИ своей строки и растят
    -- её (см. makePanel). Высота меню меняется уже после открытия, и знать об
    -- этом заранее нельзя -- значит следим за фактической.
    NierUI.connect(self, page:GetPropertyChangedSignal("AbsoluteSize"), function()
        applyHeight(self)
    end)

    -- Окно должно уметь снять контейнер: его подписки лежат в собственном
    -- стоке, и оконный Destroy до них не достаёт.
    table.insert(window.panels, self)

    return self
end

--=============================================================================
-- Открытие и закрытие
--=============================================================================

function Panel.IsOpen(self)
    return self.entry ~= false
end

-- Снять страницу обратно на стоянку. Зовётся из OnClose всплывающего окна,
-- поэтому отрабатывает при ЛЮБОМ способе закрытия -- щелчком мимо, Escape,
-- закрытием родителя или ClosePopups.
function Panel.Detach(self)
    if not self.entry then return end
    self.entry, self.close = false, false
    -- Страницу возвращаем на стоянку, а НЕ уничтожаем: в ней живут виджеты со
    -- своим состоянием, флагами и подписками.
    self.page.Parent = self.park
end

function Panel.Open(self, opts)
    opts = opts or {}
    if self.entry then return self.close end

    self.titled = opts.Title ~= nil

    local anchor = opts.Anchor
    local x = opts.X
        or (anchor and (anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + 6)) or 0
    local y = opts.Y or (anchor and anchor.AbsolutePosition.Y) or 0

    local top = topOf(self)
    local panel, close, _, z, entry = self.window:Popup({
        Title = opts.Title,
        Width = self.width,
        Height = top + self:Measure(),
        X = x, Y = y,
        Place = opts.Place, Owner = opts.Owner,
        OnClose = function()
            self:Detach()
            if opts.OnClose then pcall(opts.OnClose) end
        end,
    })

    self.entry, self.close = entry, close
    -- Active = true: содержимое всплывающего окна тянут пальцем, см. popupScroll.
    self.page.Parent = NierUI.popupScroll(panel,
        { Top = top, ZIndex = z, Active = true })
    applyHeight(self)

    return close
end

function Panel.Close(self)
    if self.close then pcall(self.close) end
end

--=============================================================================
-- ПОСТОЯННЫЙ ПОКАЗ
--=============================================================================
--
-- То же содержимое, но не во всплывающем окне, а на своём слое: видно ВСЕГДА,
-- в том числе при закрытом меню.
--
-- Всплывающее окно для этого не годится принципиально. Оно гаснет щелчком мимо,
-- по Escape и целиком в ClosePopups -- а ClosePopups первым делом зовёт
-- Window:Toggle(false). То есть счётчик кадров на всплывающем окне исчезал бы
-- ровно тогда, когда меню закрыли, то есть всегда.
--
-- Работает же оно потому, что Toggle гасит КОРЕНЬ окна, а не ScreenGui: на нём
-- держатся и уведомления, которые обязаны показываться при закрытом меню.
--
-- ВЗАИМОДЕЙСТВИЕ ТОЛЬКО ПРИ ОТКРЫТОМ МЕНЮ. Закрыли меню -- перехват ввода снят,
-- своего указателя нет, и попасть по слою нечем. Для счётчика и списка привязок
-- это ровно то, что нужно: они показывают, а не принимают.

function Panel.Show(self, opts)
    opts = opts or {}

    if self.hud then
        self.hud.Visible = true
        return self.hud
    end
    if self.entry then self:Close() end

    self.titled = opts.Title ~= nil
    local top = topOf(self)

    local x, y = clampToView(self, opts.X or 20, opts.Y or 20)

    local frame = U.new("Frame", {
        BackgroundColor3 = THEME.Bg, BorderSizePixel = 0, Active = true,
        BackgroundTransparency = opts.Transparency or 0,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(self.width, top + self:Measure()),
        ZIndex = HUD_Z, ClipsDescendants = true, Name = U.randomName(),
    }, self.window.gui)
    U.stroke(frame, 1)

    if opts.Title then NierUI.popupTitle(frame, opts.Title, HUD_Z + 2) end

    self.hud = frame
    -- Active = false: слой таскают мышью за пустое место, и поглощающий потомок
    -- забрал бы у него нажатие целиком. См. popupScroll.
    self.page.Parent = NierUI.popupScroll(frame,
        { Top = top, ZIndex = HUD_Z + 1, Active = false })
    applyHeight(self)

    --== перетаскивание ======================================================
    --
    -- За любое пустое место, а не только за полосу заголовка (то есть без Grip):
    -- у слоя её может и не быть вовсе, а таскать его надо. Виджеты внутри щелчок
    -- съедают сами, поэтому по ним слой не поедет.
    NierUI.dragFrame(NierUI.sink(self), frame)

    return frame
end

function Panel.Hide(self)
    -- Прячем, а не сносим: положение, куда слой перетащили, и всё его
    -- содержимое обязаны пережить выключение и вернуться как были.
    if self.hud then self.hud.Visible = false end
end

function Panel.SetVisible(self, on)
    if on == false then self:Hide() else self:Show() end
end

function Panel.IsVisible(self)
    return self.hud ~= false and self.hud.Visible
end

-- Где слой стоит и куда его поставить. Нужно конфигу: положение худа, в отличие
-- от положения всплывающего окна, -- это НАСТРОЙКА. Всплывающее живёт секунды и
-- открывается у своей строки; худ человек ставит в угол экрана раз и навсегда,
-- и заново двигать его после каждого перезапуска -- та ещё радость.
function Panel.Place(self)
    if not self.hud then return nil end
    return self.hud.Position.X.Offset, self.hud.Position.Y.Offset
end

function Panel.MoveTo(self, x, y)
    if not self.hud then return end
    self.hud.Position = UDim2.fromOffset(clampToView(self, x, y))
end

-- Снять контейнер целиком: и содержимое, и подписки. Открытое окно закрывается
-- первым -- иначе оно осталось бы висеть с пустой страницей внутри.
function Panel.OnDestroy(self, fn)
    table.insert(self.cleanups, fn)
    return fn
end

function Panel.Destroy(self)
    self:Close()
    for _, fn in ipairs(self.cleanups) do pcall(fn) end
    table.clear(self.cleanups)
    NierUI.drain(self.conns)
    pcall(function() self.park:Destroy() end)
    if self.hud then
        pcall(function() self.hud:Destroy() end)
        self.hud = false
    end
    self.rows = 0

    -- Снимаемся с учёта у окна: снятый контейнер не должен ждать своей очереди
    -- в Destroy, а пустое меню сносится сразу после сборки и оставляло бы за
    -- собой мёртвую запись.
    local list = self.window.panels
    for i = #list, 1, -1 do
        if list[i] == self then table.remove(list, i) end
    end
end
