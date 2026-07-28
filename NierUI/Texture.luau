--!nocheck
--=============================================================================
-- Texture -- процедурные текстуры вместо декораций из фреймов
--=============================================================================
--
-- ЗАЧЕМ
--
-- Скан-линии рисовались фреймами: по одному на каждую линию. Замер на живом
-- меню -- 122 фрейма из 856 в иерархии, то есть СЕДЬМАЯ ЧАСТЬ всего меню
-- уходила на декорацию, нарисованную самым дорогим из возможных способов. И
-- потолок там жёсткий: зерно, дизеринг и любой попиксельный узор фреймами не
-- сделать в принципе -- это тысячи инстансов на панель.
--
-- EditableImage позволяет собрать текстуру попиксельно прямо в рантайме и
-- положить её ОДНИМ ImageLabel с тайлингом. Замерено в этом клиенте:
--     CreateEditableImage  есть
--     WritePixelsBuffer    есть   (старого WritePixels уже нет)
--     Content.fromObject   есть
--     ImageLabel.ImageContent есть
--
-- Ассет при этом не нужен: ничего не грузится, не модерируется и не может
-- однажды перестать открываться. Ровно тот же довод, по которому палитра
-- собрана из градиентов, а не из картинки.
--
--
-- ПОЧЕМУ ТАЙЛ, А НЕ ТЕКСТУРА ПО РАЗМЕРУ ОКНА
--
-- Текстура на всё окно -- это 644x483 пикселя, 1.2 МБ буфера, и пересборка при
-- каждом изменении размера. Тайл 64x64 -- 16 КБ, строится один раз и повторяется
-- движком. Шаг скан-линий (4) делит 64 нацело, поэтому стык невидим.
--
--
-- ЕСЛИ EditableImage НЕДОСТУПЕН
--
-- В другом клиенте его может не быть. Тогда откатываемся на прежние фреймы --
-- меню должно выглядеть хуже, но не ломаться.

local AssetService = game:GetService("AssetService")

local THEME = NierUI.Theme
local U = NierUI.util

local T = {}
NierUI.texture = T

local TILE = 64

--=============================================================================
-- Сборка тайла
--=============================================================================
--
-- Один проход по пикселям. Цвет всюду чернильный, различие только в альфе:
-- на строках скан-линий она заметная, между ними -- случайное зерно в
-- несколько единиц. Именно зерно даёт бумажность, из-за которой песочный фон
-- в оригинале не выглядит заливкой.

local function inkBytes()
    local ink = THEME.Ink
    return math.floor(ink.R * 255 + 0.5),
           math.floor(ink.G * 255 + 0.5),
           math.floor(ink.B * 255 + 0.5)
end

-- Три слоя в один проход, по убыванию заметности: скан-линии, миллиметровка,
-- зерно. Порядок проверок и есть приоритет -- на строке скан-линии сетку не
-- рисуем, иначе она бы её только грязнила.
local function buildTile()
    local buf = buffer.create(TILE * TILE * 4)
    local r, g, b = inkBytes()

    -- В теме прозрачность, в текстуре альфа -- величины обратные.
    local lineAlpha = math.floor((1 - THEME.ScanAlpha) * 255 + 0.5)
    local grain = THEME.Grain
    local step = math.max(1, THEME.ScanStep)
    local gridStep = THEME.GridStep
    local gridAlpha = THEME.GridAlpha

    for y = 0, TILE - 1 do
        local onLine = THEME.Scanlines and (y % step) == 0
        local onGridRow = gridStep > 0 and (y % gridStep) == 0
        local rowBase = y * TILE * 4

        for x = 0, TILE - 1 do
            local i = rowBase + x * 4
            local alpha
            if onLine then
                alpha = lineAlpha
            elseif onGridRow or (gridStep > 0 and (x % gridStep) == 0) then
                alpha = gridAlpha
            else
                alpha = grain > 0 and math.random(0, grain) or 0
            end
            buffer.writeu8(buf, i, r)
            buffer.writeu8(buf, i + 1, g)
            buffer.writeu8(buf, i + 2, b)
            buffer.writeu8(buf, i + 3, alpha)
        end
    end

    return buf
end

--=============================================================================
-- Полоса-перфорация
--=============================================================================
--
-- МОТИВ: штрих ВВЕРХУ, за ним три точки «галочкой» -- крайние выше, средняя
-- ниже. Это и есть весь период, дальше он просто повторяется.
--
-- Первая версия была снята с общих кадров на глаз и оказалась не тем: там были
-- разрозненные точки на двух уровнях с редким штрихом, без «галочки» и без
-- привязки штриха к верху. Рисунок читается только по крупному плану.
--
-- Таблица прямоугольников, а не процедура: подправить мотив -- значит
-- поправить числа. Координаты внутри тайла: x, y, ширина, высота.

-- СИММЕТРИЯ ЗДЕСЬ -- ИНВАРИАНТ, А НЕ ПОЖЕЛАНИЕ. Держатся три равенства:
--
--   нижняя точка стоит РОВНО посередине между верхними
--       левая 14..15 (центр 14.5), нижняя 18..19 (18.5),
--       правая 22..23 (22.5) -- шаг 4 между всеми тремя;
--   зазоры между точками одинаковые -- по два пикселя (15|18 и 19|22);
--   шаг между штрихом и треугольником равен шагу до следующего мотива
--       центр штриха 5, центр треугольника 18.5, следующий штрих 33 --
--       13.5 и 14.5 от центра к центру.
--
-- ШТРИХ ЦЕНТРИРОВАН В СВОЁМ МЕСТЕ, А НЕ ПРИЖАТ К КРАЮ. Поэтому его длину можно
-- менять, не сдвигая ничего остального: укоротили вдвое (11 -> 5) -- центр как
-- стоял на 5, так и остался, а освободившееся место само разошлось поровну
-- влево и вправо. Прижми штрих к нулю -- и любая правка длины поедет узором.
--
-- Точки 2x2, а не 3x3: на пиксельной сетке это ближайший шаг вниз, он же
-- минус треть. Промежуточного размера не существует -- за ним пришлось бы
-- увеличивать весь мотив целиком.
--
-- По высоте мотив занимает 2..9 из 12, то есть отбит сверху и снизу поровну.

local BAND_W, BAND_H = 28, 12

local BAND_MARKS = {
    { 3, 2, 5, 2 },     -- штрих, верхний уровень; центр на 5
    { 14, 5, 2, 2 },    -- левая верхняя
    { 18, 8, 2, 2 },    -- нижняя, посередине
    { 22, 5, 2, 2 },    -- правая верхняя
}

local BAND_ALPHA = 150

local function buildBand()
    local buf = buffer.create(BAND_W * BAND_H * 4)
    local r, g, b = inkBytes()

    -- Прозрачный фон: полоса ложится поверх подложки окна.
    for i = 0, BAND_W * BAND_H - 1 do
        buffer.writeu8(buf, i * 4, r)
        buffer.writeu8(buf, i * 4 + 1, g)
        buffer.writeu8(buf, i * 4 + 2, b)
        buffer.writeu8(buf, i * 4 + 3, 0)
    end

    for _, mark in ipairs(BAND_MARKS) do
        local mx, my, mw, mh = mark[1], mark[2], mark[3], mark[4]
        for y = my, math.min(my + mh - 1, BAND_H - 1) do
            for x = mx, math.min(mx + mw - 1, BAND_W - 1) do
                buffer.writeu8(buf, (y * BAND_W + x) * 4 + 3, BAND_ALPHA)
            end
        end
    end

    return buf
end

--=============================================================================
-- Поверхность
--=============================================================================

-- parent -- на что натянуть, обычно корень окна или подложка блока.
-- Возвращает созданный слой либо nil, если не получилось.
function T.surface(parent)
    if not THEME.Scanlines and THEME.Grain <= 0 then return nil end

    local ok, layer = pcall(function()
        local image = AssetService:CreateEditableImage({ Size = Vector2.new(TILE, TILE) })
        image:WritePixelsBuffer(Vector2.zero, Vector2.new(TILE, TILE), buildTile())

        -- Active = false обязателен: слой лежит поверх всего, и без этого он
        -- накрыл бы собой каждую кнопку меню.
        return U.new("ImageLabel", {
            BackgroundTransparency = 1, Active = false,
            Size = UDim2.fromScale(1, 1), ZIndex = 15,
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(TILE, TILE),
            ImageContent = Content.fromObject(image),
        }, parent)
    end)

    return ok and layer or nil
end

-- Полоса-перфорация. y -- готовая координата в окне, полоса тянется во всю
-- ширину и повторяется по горизонтали.
function T.band(parent, y)
    if not THEME.Band then return nil end

    local ok, layer = pcall(function()
        local image = AssetService:CreateEditableImage({
            Size = Vector2.new(BAND_W, BAND_H),
        })
        image:WritePixelsBuffer(Vector2.zero, Vector2.new(BAND_W, BAND_H), buildBand())

        return U.new("ImageLabel", {
            BackgroundTransparency = 1, Active = false,
            Position = UDim2.fromOffset(0, y),
            Size = UDim2.new(1, 0, 0, THEME.BandHeight),
            ZIndex = 14,
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(BAND_W, BAND_H),
            ImageContent = Content.fromObject(image),
        }, parent)
    end)

    return ok and layer or nil
end

-- Единая точка для окна: текстура, а если её собрать не вышло -- прежние
-- фреймы. Вызывающему знать, что именно получилось, не нужно.
function T.apply(parent, height)
    local layer = T.surface(parent)
    if layer then return layer end
    return U.scanlines(parent, height)
end
