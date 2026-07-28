--!nocheck
--=============================================================================
-- Cursor -- собственный указатель
--=============================================================================
--
-- ПОЧЕМУ СВОЙ, А НЕ СИСТЕМНЫЙ
--
-- Перехват сначала просто включал MouseIconEnabled и возвращал его, когда игра
-- гасила. Проверено вживую: щелчки в меню доходят, а курсора нет. Игра прячет
-- его не одним этим свойством, и спор за него проигрывается молча -- то есть
-- худшим способом: меню работает, а куда нажимать, непонятно.
--
-- Поэтому системный указатель гасится намеренно, а свой рисуется поверх.
--
--
--=============================================================================
-- ГЕОМЕТРИЯ ЗАДАНА В ФИЗИЧЕСКИХ ПИКСЕЛЯХ. ЭТО ГЛАВНОЕ ЗДЕСЬ.
--=============================================================================
--
-- При дробном масштабе экрана Windows интерфейс рисуется в логических пикселях
-- и растягивается. Замерено: панель 1920x1080, масштаб 125%, ViewportSize
-- 1536x864 -- один логический пиксель это 1.25 физического.
--
-- Логическая сетка тут не спасает никак, и вот почему. Пусть весь указатель
-- симметричен и начало координат стоит на целом физическом пикселе. Возьмём
-- горизонтальную черту с оправой в два логических пикселя: по X её края лягут
-- как (0.5, 1, 1), а по Y -- как (1, 1, 0.5). Оправа вокруг ОДНОЙ И ТОЙ ЖЕ
-- черты получает разный вес сбоку и сверху. Это и читается как «съехала».
--
-- Ровно она ляжет, только если каждый край попадёт на целую границу
-- физического пикселя. В логических пикселях при 125% это кратность четырём,
-- то есть оправа в пять физических пикселей -- неприемлемо толсто.
--
-- Поэтому размеры здесь -- В ФИЗИЧЕСКИХ ПИКСЕЛЯХ, а в логические переводятся
-- дробью. Дробь ВЫЖИВАЕТ ТОЛЬКО В Scale: UDim.Offset сам отбрасывает дробную
-- часть (проверено -- fromOffset(100.4) даёт ровно 100), а у Scale она
-- сохраняется (AbsolutePosition показывает 100.400002). Отсюда весь указатель
-- на долях и ни одного Offset.
--
--
-- ОТКУДА БЕРЁТСЯ МАСШТАБ
--
-- Ниоткуда: Roblox физического разрешения не сообщает. GuiService при 125%
-- отдаёт 1536x806 -- тот же логический размер минус верхняя панель.
--
-- Зато его видно по мыши. GetMouseLocation отдаёт ДРОБНЫЕ координаты (замерено:
-- 268.800018, 330.399994 -- кратны 0.8, то есть 1/1.25): положение мыши всегда
-- соответствует целому физическому пикселю. Значит наименьший ненулевой сдвиг
-- между двумя её положениями и есть размер физического пикселя в логических.
--
-- Меряем по ходу дела. До первого замера считаем шаг равным единице -- при 100%
-- это и есть точный ответ, а при дробном первое же движение мыши его уточняет.
--
-- Берём НЕ минимум сдвигов, а их НОД, и это принципиально: минимум верен, лишь
-- когда мышь хоть раз сдвинули ровно на пиксель, а если ею возят рывками по
-- три-четыре, минимум так и застрянет на трёх. НОД же сходится к истинному
-- шагу с любых движений -- достаточно двух сдвигов во взаимно простое число
-- пикселей, а таких пар среди случайных движений подавляющее большинство.

local UserInputService = game:GetService("UserInputService")

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

-- Поверх всего своего: у окна ZIndexBehavior = Sibling, число сравнивается
-- глобально, и всплывающие окна с их сотнями сюда не дотягиваются.
local Z = 1000000

--== размеры, В ФИЗИЧЕСКИХ ПИКСЕЛЯХ ==========================================

local MARGIN = 1         -- оправа
local THICK = 2          -- толщина черты
local ARM = 8            -- её длина
local GAP = 4            -- от середины до черты
local CORE = 2           -- сторона сердцевины

-- Части указателя: прямоугольник ЧЕРТЫ относительно середины, оправа шире его
-- на MARGIN со всех сторон. Отсюда просвет между оправой черты и оправой
-- сердцевины: GAP - MARGIN - (CORE/2 + MARGIN) = 1 пиксель. Слипаться им
-- нельзя -- проверено увеличенным снимком, всё светлое тогда сливается в один
-- толстый крест.
local PARTS = {
    { x = -GAP - ARM, y = -THICK / 2, w = ARM, h = THICK },   -- слева
    { x = GAP, y = -THICK / 2, w = ARM, h = THICK },          -- справа
    { x = -THICK / 2, y = -GAP - ARM, w = THICK, h = ARM },   -- сверху
    { x = -THICK / 2, y = GAP, w = THICK, h = ARM },          -- снизу
    { x = -CORE / 2, y = -CORE / 2, w = CORE, h = CORE },     -- сердцевина
}

-- Размер физического пикселя в логических. Живёт на самой библиотеке, а не на
-- окне: библиотека кешируется в окружении, поэтому замер делается один раз за
-- сессию и переживает и пересоздание окна, и перезапуск скрипта. Единица --
-- честное значение для масштаба 100%.
NierUI.pixelStep = NierUI.pixelStep or 1

--=============================================================================

local function build(window)
    -- Контейнер во весь экран: доли его детей считаются от размера экрана, и
    -- никакой арифметики с верхней панелью не нужно -- GetMouseLocation живёт
    -- в той же системе отсчёта.
    local holder = U.new("Frame", {
        BackgroundTransparency = 1, Active = false, Visible = false,
        Size = UDim2.fromScale(1, 1), ZIndex = Z,
    }, window.gui)

    local parts = {}
    for _, spec in ipairs(PARTS) do
        -- Оправа. Active = false на всём: указатель лежит поверх меню и ловил
        -- бы своими краями щелчки, предназначенные строке под ним.
        local frame = U.new("Frame", {
            BackgroundColor3 = THEME.Bg, BorderSizePixel = 0, Active = false,
            ZIndex = Z,
        }, holder)

        -- Черта внутри оправы -- чистое отношение, масштаб ей не нужен.
        local wTotal = spec.w + MARGIN * 2
        local hTotal = spec.h + MARGIN * 2
        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
            Position = UDim2.fromScale(MARGIN / wTotal, MARGIN / hTotal),
            Size = UDim2.fromScale(spec.w / wTotal, spec.h / hTotal),
            ZIndex = Z + 1,
        }, frame)

        parts[#parts + 1] = {
            frame = frame,
            x = spec.x - MARGIN, y = spec.y - MARGIN,
            w = wTotal, h = hTotal,
        }
    end

    window.cursor = holder
    window.cursorParts = parts
    return holder
end

--=============================================================================

function Window:ShowCursor()
    if self.cursorOn then return end
    -- Мыши может не быть вовсе: телефон, планшет, консоль. Указатель за пальцем
    -- не ходит, а нарисованный посреди экрана крест только мешает.
    if not UserInputService.MouseEnabled then return end
    self.cursorOn = true

    local holder = self.cursor or build(self)
    local parts = self.cursorParts

    local step = NierUI.pixelStep
    local last = nil
    local moves = 0

    local function layout()
        local size = holder.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then return end
        for _, p in ipairs(parts) do
            p.frame.Size = UDim2.fromScale(
                p.w * step / size.X, p.h * step / size.Y)
        end
    end

    local function place(at)
        local size = holder.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then return end
        for _, p in ipairs(parts) do
            p.frame.Position = UDim2.fromScale(
                (at.X + p.x * step) / size.X,
                (at.Y + p.y * step) / size.Y)
        end
    end

    -- Евклид с допуском. Сдвиги кратны истинному шагу, поэтому остаток сходится
    -- к нему за считаные итерации; порог 0.05 гасит накопленную погрешность.
    local function fold(a, b)
        if b < 1e-4 then return a end
        if a == nil then return b end
        if a < b then a, b = b, a end
        for _ = 1, 40 do
            if b <= 0.05 then break end
            a, b = b, a - math.floor(a / b + 1e-6) * b
        end
        return a
    end

    -- Евклид на float32 копит погрешность: замер дал 0.799591 вместо 0.8, и
    -- края разъезжались на сотую пикселя. Но настоящий шаг -- всегда дробь с
    -- небольшим знаменателем (125% -> 4/5, 150% -> 2/3, 175% -> 4/7, 200% ->
    -- 1/2), поэтому подтягиваем измеренное к ближайшей такой дроби. Заодно это
    -- якорь: подтянутое значение идёт обратно в накопитель и не даёт ему
    -- уползать дальше.
    local function snap(x)
        local best, err = x, 0.01
        for q = 1, 16 do
            local p = math.floor(x * q + 0.5)
            if p >= 1 then
                local v, d = p / q, math.abs(p / q - x)
                if d < err then best, err = v, d end
            end
        end
        return best
    end

    -- ГРАНИЦЫ ДОВЕРИЯ.
    --
    -- Снизу 0.1 -- это масштаб 1000%, с запасом на телефоны с плотностью 3x и
    -- 4x. Сверху 4 -- на случай, когда логический экран КРУПНЕЕ физического
    -- (масштаб меньше 100%; через настройки Windows такого не выставить, но
    -- драйверы и правка реестра позволяют).
    --
    -- Шаг больше логического пикселя принимаем только после восьми движений, и
    -- это не перестраховка: НОД сходится СВЕРХУ, и на первых сдвигах он вполне
    -- может оказаться равным трём. Приняв это сразу, мы бы на секунду раздули
    -- указатель втрое. Значение меньше единицы такой опасности не несёт --
    -- крупнее, чем при масштабе 100%, он от него не станет.
    local acc = nil
    local function observe(at)
        if last then
            moves = moves + 1
            acc = fold(fold(acc, math.abs(at.X - last.X)), math.abs(at.Y - last.Y))
            local trusted = acc and acc >= 0.1
                and (acc <= 1 or (acc <= 4 and moves >= 8))
            if trusted then
                acc = snap(acc)
                if math.abs(acc - step) > 1e-4 then
                    step = acc
                    NierUI.pixelStep = step
                    layout()
                end
            end
        end
        last = at
    end

    layout()
    place(UserInputService:GetMouseLocation())
    holder.Visible = true

    self.cursorConns = {
        -- Движение -- СОБЫТИЕ, а не кадр: мышь стоит, и не тратится ничего.
        -- Постоянных потоков в библиотеке по-прежнему нет ни одного.
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local at = UserInputService:GetMouseLocation()
            observe(at)
            place(at)
        end),

        -- Размер экрана меняется чаще, чем кажется: окно тянут за угол,
        -- включают полноэкранный режим, поворачивают планшет, перетаскивают
        -- окно на монитор с другой плотностью. Положение считается от текущего
        -- размера при каждом движении, а вот РАЗМЕРЫ частей заданы долей и
        -- сами не пересчитаются.
        --
        -- Замер при этом сбрасываем: у другого монитора другой физический
        -- пиксель, а НОД умеет только уменьшаться и сам бы туда не вернулся.
        holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            acc, last, moves = nil, nil, 0
            step = 1
            NierUI.pixelStep = 1
            layout()
            place(UserInputService:GetMouseLocation())
        end),
    }
end

function Window:HideCursor()
    if not self.cursorOn then return end
    self.cursorOn = false

    for _, conn in ipairs(self.cursorConns or {}) do
        pcall(function() conn:Disconnect() end)
    end
    self.cursorConns = false

    if self.cursor then self.cursor.Visible = false end
end
