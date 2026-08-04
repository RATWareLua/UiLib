--!nocheck
-- NierUI. Собрано lib\build.ps1, правки вносить в lib\NierUI\.

local NierUI = {}

--============================ NierUI/Theme.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Theme -- палитра, шрифт, размеры
--=============================================================================
--
-- Получает общий NierUI параметром, см. build.ps1.
--
-- Меняется ДО создания окна: значения читаются в момент постройки элементов,
-- задним числом уже ничего не перекрасится.

-- Шрифт NieR -- квадратная антиква. Ближайшее из встроенного -- Merriweather:
-- Bodoni точнее по контрасту, но на четырнадцати пикселях его волосяные линии
-- рассыпаются.
--
-- Кириллицу Merriweather держит -- проверено снимком экрана на живом клиенте.
-- Здесь стояло обратное («кириллицы у него нет, ставь RobotoMono»), и это была
-- неправда, перекочевавшая заодно в README: обе витрины подписаны по-русски и
-- шрифт не трогают вовсе.
--
-- Подбор идёт с откатом: если шрифта в клиенте нет, спускаемся по списку, а не
-- падаем с ошибкой.
local function pickFont(...)
    for _, name in ipairs({ ... }) do
        local ok, font = pcall(function() return Enum.Font[name] end)
        if ok and font then return font end
    end
    return Enum.Font.SourceSans
end

NierUI.Theme = {
    Bg       = Color3.fromRGB(207, 201, 176),   -- песочный
    BgSunk   = Color3.fromRGB(193, 187, 163),   -- утопленный: раскрытые блоки
    Ink      = Color3.fromRGB(69, 65, 56),      -- чернила
    InkSoft  = Color3.fromRGB(126, 120, 103),   -- второстепенный текст
    Disabled = Color3.fromRGB(163, 158, 140),   -- недоступное: бледнее второстепенного

    Font     = pickFont("Merriweather", "Bodoni", "Garamond", "SourceSans"),

    --== размеры окна ========================================================
    --
    -- Вынесены сюда, чтобы окно можно было менять одним числом, а не искать
    -- 560 и 420 по коду. Высота шапки, ширина колонки вкладок и высота нижней
    -- панели заданы в пикселях намеренно: они не должны расти вместе с окном,
    -- иначе на большом меню шапка становится вывеской.
    WindowWidth = 644,
    WindowHeight = 483,
    HeaderHeight = 52,
    TabColumnWidth = 140,
    HintHeight = 40,
    PopupTitleHeight = 22,

    RowHeight = 26,
    TextSize = 14,
    TitleSize = 20,

    --== раскладка строки ====================================================
    --
    -- Всё, что стоит в строке справа, задаётся ДОЛЯМИ ширины, а не пикселями.
    -- Раньше это были жёсткие отступы от правого края (значение -110, дорожка
    -- ползунка -218, образец цвета -108). При полной ширине страницы в 395
    -- пикселей они работали, но в половинной ячейке блока (~190) отступ в 218
    -- уходит за левый край, и дорожка легла бы поверх подписи.
    --
    -- Доли рассчитаны так, чтобы зоны не пересекались ни при 395, ни при 190:
    --     подпись   14 .. 40%
    --     дорожка   правым краем на 70%, шириной 22%
    --     значение  правым краем на -10 px, шириной 24%
    LabelFrac = 0.40,
    TrackRight = 0.70,
    TrackFrac = 0.22,
    ValueFrac = 0.24,

    -- Сколько пунктов списка показывать разом. Дальше он прокручивается, а не
    -- растёт: двадцать пять вариантов дали бы 650 пикселей при высоте панели
    -- в 420, и нижние ушли бы за её край.
    DropdownMax = 6,

    --== блоки ===============================================================
    --
    -- Подложка и собственная прокрутка у блока обязательны. Заголовок задаётся
    -- у каждого блока отдельно, разделительные линии -- флагом здесь: это
    -- решение про весь вид меню, а не про отдельную ячейку.
    BlockGap = 8,
    BlockTitleHeight = 20,
    BlockSeparators = false,

    --== поверхность =========================================================
    --
    -- Скан-линии и зерно живут в одной процедурной текстуре (см. Texture).
    -- ScanAlpha -- прозрачность линии, Grain -- разброс альфы зерна между
    -- линиями в единицах 0..255.
    --
    -- Слоёв в тайле ТРИ, а не два: ниже к ним добавилась миллиметровка. Здесь
    -- было написано «ноль в обоих даёт чистую заливку», и это перестало быть
    -- правдой ровно тогда -- сетка живёт своей альфой и гасится своей.
    Scanlines = true,
    ScanStep = 4,
    ScanAlpha = 0.9,
    Grain = 7,

    -- Миллиметровка: в оригинале фон разлинован очень бледной мелкой сеткой,
    -- из-за неё он читается как бумага, а не как заливка. Альфа в единицах
    -- 0..255, ноль убирает сетку.
    GridStep = 8,
    GridAlpha = 5,

    -- Полосы-перфорации сверху и снизу окна.
    Band = true,
    BandHeight = 12,

    --== уведомления =========================================================
    NotifyWidth = 240,
    NotifyDuration = 4,
}

end)(NierUI)

--============================ NierUI/Util.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Util -- мелочи, которыми пользуются все части
--=============================================================================

local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local THEME = NierUI.Theme
local U = {}
NierUI.util = U

function U.new(class, props, parent)
    local inst = Instance.new(class)
    for key, value in pairs(props) do
        inst[key] = value
    end
    if parent then inst.Parent = parent end
    return inst
end

function U.randomName()
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local out = {}
    for _ = 1, 16 do
        local i = math.random(1, #chars)
        out[#out + 1] = chars:sub(i, i)
    end
    return table.concat(out)
end

-- Родитель GUI: CoreGui сервер не видит. Если исполнитель не даёт в него
-- писать, откатываемся в PlayerGui -- лучше видимое меню, чем никакого.
-- CoreGui ПЕРЕД gethui, а не после, и это не вкусовщина.
--
-- gethui() у распространённых исполнителей возвращает НЕ отдельный контейнер, а
-- сам CoreGui.RobloxGui -- то есть дерево, в котором Roblox строит собственный
-- интерфейс, включая меню Escape. Замерено на живом клиенте:
--
--     gethui() == game.CoreGui.RobloxGui  -> true, ТА ЖЕ ссылка
--     детей у CoreGui: 38, у RobloxGui: 69
--
-- Класть туда чужой ScreenGui значит подсовывать его core-скриптам, которые
-- этих детей перебирают и трогают. Прятаться это не помогает ничем: игре
-- недоступны оба, и CoreGui, и RobloxGui, -- а предсказуемость разная.
--
-- Единственное, что давал gethui, -- маскировка среди семи десятков родных
-- объектов вместо отдельного ребёнка CoreGui. От рекурсивного обхода не спасает
-- ни то, ни другое, а цена выяснилась дорого.
--
-- Порядок отката: CoreGui -> gethui -> PlayerGui. Последний виден игре, поэтому
-- он крайний случай, а не выбор.
function U.guiParent()
    local ok = pcall(function() return CoreGui.Name end)
    if ok then return CoreGui end

    if type(gethui) == "function" then
        local okHui, hui = pcall(gethui)
        if okHui and typeof(hui) == "Instance" then return hui end
    end

    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
function U.tween(inst, props)
    TweenService:Create(inst, TWEEN, props):Play()
end

function U.stroke(parent, thickness, color, transparency)
    return U.new("UIStroke", {
        Thickness = thickness or 1,
        Color = color or THEME.Ink,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

-- Уголковые скобки по краям панели -- та самая рамка из оригинала.
function U.corners(parent, size, thick)
    size, thick = size or 10, thick or 2
    local spots = {
        { UDim2.fromScale(0, 0), Vector2.new(0, 0) },
        { UDim2.fromScale(1, 0), Vector2.new(1, 0) },
        { UDim2.fromScale(0, 1), Vector2.new(0, 1) },
        { UDim2.fromScale(1, 1), Vector2.new(1, 1) },
    }
    for _, spot in ipairs(spots) do
        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
            Position = spot[1], AnchorPoint = spot[2],
            Size = UDim2.fromOffset(size, thick), ZIndex = 20,
        }, parent)
        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
            Position = spot[1], AnchorPoint = spot[2],
            Size = UDim2.fromOffset(thick, size), ZIndex = 20,
        }, parent)
    end
end

-- Скан-линии. Строятся ОДИН раз и больше не трогаются: это статика, а не
-- анимация. Active = false обязателен -- иначе накрыло бы собой все кнопки.
function U.scanlines(parent, height)
    if not THEME.Scanlines then return end
    local holder = U.new("Frame", {
        BackgroundTransparency = 1, Active = false,
        Size = UDim2.fromScale(1, 1), ZIndex = 15,
        ClipsDescendants = true,
    }, parent)

    for y = 0, height, THEME.ScanStep do
        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
            BackgroundTransparency = THEME.ScanAlpha,
            Position = UDim2.fromOffset(0, y),
            Size = UDim2.new(1, 0, 0, 1), ZIndex = 15,
        }, holder)
    end
    return holder
end

--=============================================================================
-- ПОРЯДОК СЛОЁВ -- ОДНОЙ ТАБЛИЦЕЙ, А НЕ ЧИСЛАМИ ПО ФАЙЛАМ
--=============================================================================
--
-- У окна ZIndexBehavior = Sibling: номер сравнивается ГЛОБАЛЬНО, а не внутри
-- родителя. Значит все слои поверх игры стоят в одной очереди, и каждый, кто в
-- неё встаёт, обязан знать её целиком.
--
-- Держалась эта очередь комментариями в трёх файлах сразу: Panel писал «НИЖЕ
-- всплывающих окон (100) и их перехватчика (90)», Popup -- «выше 200 живут
-- уведомления», Notify молча ставил 200. Три записи одного порядка -- это две
-- строки, которые станут неправдой от первой же правки третьей.
--
--   hud     постоянный слой (счётчик кадров, список привязок). НИЖЕ меню: он
--             показывает, а не принимает, и закрывать собой меню не должен;
--   shade   перехватчик щелчков под стопкой окон. Ниже ЛЮБОЙ панели;
--   popup   первое всплывающее окно, каждое следующее на десяток выше;
--   notify  уведомления. Выше всех окон: сообщение обязано быть видно;
--   cursor  свой указатель. Поверх всего, включая уведомления, -- всплывающие
--             окна с их сотнями сюда не дотягиваются.
--
-- Корень окна стоит на 1, а декорации внутри него -- на 14..20. В эту очередь
-- они не входят: за пределы окна они не выходят.
--
-- ЖИВЁТ ЗДЕСЬ, А НЕ У ВСПЛЫВАЮЩИХ, И ЭТО НЕ ВКУСОВЩИНА. Объявленная там, она
-- существовала только начиная с пятнадцатого файла сборки: Panel читал её в
-- шапке и работал по счастливой случайности (он шестнадцатый), а Notify --
-- тринадцатый -- вынужденно лез за ней внутрь функции и объяснял это отдельным
-- комментарием. Один и тот же факт двумя способами, и один из них держался на
-- порядке строк в build.ps1.
NierUI.layers = {
    hud = 50,
    shade = 90,
    popup = 100,
    notify = 200,
    cursor = 1000000,
}

--=============================================================================
-- РАЗМЕР ЭКРАНА
--=============================================================================
--
-- Спрашивали его шесть мест подряд одной и той же строчкой с одним и тем же
-- запасным значением. Запасное тут не для красоты: CurrentCamera на первом
-- кадре бывает ещё не заведён, а раскладку считать уже надо.
--
-- Имя NierUI.viewport, а не U.viewport: зовут его и окно, и слои, и всплывающие
-- -- то есть части, которые про Util знают не все. Живёт здесь, потому что это
-- общая мелочь; объявлено было во всплывающих, и окно тянулось за ним через
-- полбиблиотеки.
function NierUI.viewport()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

-- Доля вдоль объекта по координате мыши: пригодится и ползунку, и палитре.
function U.alongX(inst, x)
    return math.clamp((x - inst.AbsolutePosition.X) / math.max(inst.AbsoluteSize.X, 1), 0, 1)
end

function U.alongY(inst, y)
    return math.clamp((y - inst.AbsolutePosition.Y) / math.max(inst.AbsoluteSize.Y, 1), 0, 1)
end

-- ПОДЪЁМ ПО ЦЕПОЧКЕ КАК ОБЫЧНЫЙ ПЕРЕБОР.
--
-- Библиотека трижды поднимается по цепочке: дважды по Parent (видим ли элемент
-- и не обрезан ли предком, глубина в дереве) и один раз по owner (чьё это
-- всплывающее окно). Все три были написаны вручную -- `while node do ... node =
-- node.Parent end`, -- то есть три копии одной бухгалтерии с курсором, за
-- которой в каждой надо следить отдельно.
--
-- step получает текущее звено и отдаёт следующее; nil и false равно означают
-- конец -- у окна «нет владельца» хранится как false, как и все отсутствующие
-- поля в состоянии окна.
function U.chain(node, step)
    return function()
        local current = node
        if current == nil or current == false then return nil end
        node = step(current)
        return current
    end
end

-- Попадает ли точка в прямоугольник элемента. Нужно там, где событие щелчка
-- само по себе не говорит, где он случился: MouseButton1Click координат не
-- несёт, а отличать «нажали по строке» от «нажали внутри раскрытой панели»
-- как-то надо.
function U.inside(frame, position)
    local p, s = frame.AbsolutePosition, frame.AbsoluteSize
    return position.X >= p.X and position.X <= p.X + s.X
       and position.Y >= p.Y and position.Y <= p.Y + s.Y
end

--=============================================================================
-- ТЕКСТ СЧИТАЕТСЯ В СИМВОЛАХ, А НЕ В БАЙТАХ
--=============================================================================
--
-- В Luau `#s` -- это длина в БАЙТАХ, а кириллическая буква в UTF-8 занимает два.
-- Отсюда три поломки подряд, найденные в один заход:
--
--   предел длины поля ввода резал русское имя вдвое короче обещанного, а на
--     границе разрубал букву пополам -- в поле вылезал знак-заменитель;
--   высота окна подтверждения прикидывалась по числу байт, и русский текст
--     давал вдвое больше строк, чем нужно;
--   список привязок обрезал имя тем же способом.
--
-- Поэтому счёт и обрезка живут ЗДЕСЬ, одним разом на всю библиотеку: три копии
-- этого разбора однажды разъехались бы, как уже разъезжался захват клавиши.

-- Длина в символах. nil -- строка не UTF-8; вызывающий решает сам, что с этим
-- делать, и обычно правильный ответ -- «не трогать».
function U.textLength(text)
    return utf8.len(text)
end

-- Обрезать до limit СИМВОЛОВ. Не UTF-8 или и так короткая -- отдаём как есть:
-- испорченный текст лучше испорченного текста, обрезанного наугад.
function U.textCut(text, limit)
    local length = utf8.len(text)
    if not length or length <= limit then return text end
    local stop = utf8.offset(text, limit + 1)
    if not stop then return text end
    return text:sub(1, stop - 1)
end

--=============================================================================
-- ПРИВЕДЕНИЕ К НИЖНЕМУ РЕГИСТРУ ЗНАЕТ ПРО КИРИЛЛИЦУ
--=============================================================================
--
-- string.lower в Lua работает только с латиницей: «АНТИАИМ» после него остаётся
-- «АНТИАИМ». Поиск в списках сравнивает как раз приведённые строки -- то есть по
-- русским названиям он был РЕГИСТРОЗАВИСИМЫМ, и набранное строчными не находило
-- ничего. Заметно это стало на своём же менеджере привязок: там поиск идёт по
-- названиям вроде «АНТИАИМ ВЛЕВО».
--
-- Таблиц не заводим -- у кириллицы регистры разведены арифметикой: А..Я лежат
-- на 0x20 ниже а..я, и отдельного разбора требует только Ё.
local function lowerCode(code)
    if code >= 65 and code <= 90 then return code + 32 end          -- A..Z
    if code >= 0x410 and code <= 0x42F then return code + 0x20 end  -- А..Я
    if code == 0x401 then return 0x451 end                          -- Ё
    return code
end

function U.lower(text)
    -- Чистая латиница -- штатным путём: обход по кодам дороже, а выигрыша нет.
    if not text:find("[\128-\255]") then return text:lower() end
    if not utf8.len(text) then return text:lower() end

    local out = {}
    for _, code in utf8.codes(text) do
        out[#out + 1] = utf8.char(lowerCode(code))
    end
    return table.concat(out)
end

function U.hex(color)
    return ("#%02X%02X%02X"):format(
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5))
end

--=============================================================================
-- ПОИСК: НЕ ОТБОР, А РАНЖИРОВАНИЕ
--=============================================================================
--
-- Первая версия была обычным поиском подстроки: совпадает где угодно внутри
-- слова -- показываем. Формально верно, а на деле странно: на «ni» выпадали
-- DENNIS, UNICORN и NIGEL вперемешку, потому что все три подстроку содержат.
-- Плохо было не то, что находилось лишнее, а то, что НИЧЕГО НЕ БЫЛО УПОРЯДОЧЕНО
-- -- совпадение в начале строки стояло наравне с совпадением в середине слова.
--
-- Поэтому не отбор, а оценка. Возвращает разряд и позицию:
--
--   0  строка целиком начинается с запроса   NI -> NIGEL
--   1  с запроса начинается какое-то слово   WO -> DENNIS / WOLF
--   2  подстрока где угодно                  NI -> DENNIS
--   3  подпоследовательность, буквы по порядку но не подряд   dnw -> DENNIS / WOLF
--
-- Разряд 3 по умолчанию выключен: он находит слишком многое и удивляет сильнее,
-- чем помогает. Включается режимом "fuzzy".
--
-- nil означает «не подходит вовсе».

function U.matchScore(text, query)
    if query == "" then return 0, 1 end

    -- Через U.lower, а не string.lower: тот знает только латиницу, и по русским
    -- названиям поиск был регистрозависимым.
    local haystack, needle = U.lower(tostring(text)), U.lower(tostring(query))
    local length = #needle

    if haystack:sub(1, length) == needle then return 0, 1 end

    -- Начало любого слова: границей считается всё, что не буква и не цифра.
    --
    -- Байты со старшим битом идут в слово наравне с %w -- иначе кириллица
    -- границей не считается вовсе, и разряд «с запроса начинается слово» для
    -- русских названий не срабатывал никогда.
    -- gmatch с позиционным захватом: перебор начал слов -- это перебор, а не
    -- ручная прокрутка курсора. Прежде здесь стоял `while true` с pos = to + 1,
    -- то есть тот же обход, но с бухгалтерией, за которой надо следить самому.
    for from in haystack:gmatch("()[%w\128-\255]+") do
        if haystack:sub(from, from + length - 1) == needle then return 1, from end
    end

    local at = haystack:find(needle, 1, true)
    if at then return 2, at end

    local cursor, first = 1, nil
    for index = 1, length do
        local found = haystack:find(needle:sub(index, index), cursor, true)
        if not found then return nil end
        first = first or found
        cursor = found + 1
    end
    return 3, first or 1
end

-- Разбор жил в двух местах сразу: в палитре и в кодеке конфига. Две копии
-- одного разбора -- это две разные трактовки короткой записи через месяц.
--
-- Принимаем #RRGGBB, RRGGBB и #RGB: короткая форма встречается в чужих
-- конфигах, и разворачивать её руками -- лишний повод ошибиться.
function U.fromHex(text)
    local hex = tostring(text):gsub("#", "")
    if #hex == 3 then
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
    end
    if #hex ~= 6 then return nil end

    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return Color3.fromRGB(r, g, b)
end

end)(NierUI)

--============================ NierUI/Texture.luau ============================
;(function(NierUI)
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

-- ПУСТО ЛИ ПОЛОТНО -- СПРАШИВАЕМ ПРО ВСЕ ТРИ СЛОЯ, А НЕ ПРО ДВА.
--
-- Здесь стояло «нет скан-линий и нет зерна -- рисовать нечего», и написано это
-- было до того, как появилась миллиметровка. Выключи в теме скан-линии и зерно
-- -- и сетка пропадала вместе с ними, хотя её никто не выключал: сама тема при
-- этом честно держит GridStep = 8. Ни ошибки, ни следа -- просто чистая заливка
-- вместо бумаги.
--
-- Условие обязано перечислять ровно те же слои, что рисует buildTile. Иначе это
-- не проверка, а частный случай, отставший от кода на одну правку.
local function tileEmpty()
    if THEME.Scanlines then return false end
    if THEME.Grain > 0 then return false end
    if THEME.GridStep > 0 and THEME.GridAlpha > 0 then return false end
    return true
end

-- parent -- на что натянуть, обычно корень окна или подложка блока.
-- Возвращает созданный слой либо nil, если не получилось.
function T.surface(parent)
    if tileEmpty() then return nil end

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

end)(NierUI)

--============================ NierUI/ColorControl.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- ColorControl -- сам выбор цвета, без привязки к строке
--=============================================================================
--
-- Вынесен отдельно, потому что мест, где он нужен, стало два: строка-палитра
-- в меню и всплывающее окно у пункта списка. Держать две копии этой геометрии
-- -- гарантированно получить две разные палитры через месяц.
--
--
-- БЕЗ ЕДИНОГО АССЕТА
--
-- Квадрат насыщенности -- три слоя, а не картинка: снизу чистый тон, поверх
-- белый с горизонтальным градиентом прозрачности (насыщенность), поверх чёрный
-- с вертикальным (яркость). Полоса тона -- один Frame с UIGradient на семь
-- опорных цветов.
--
-- Это не эстетство: загруженная картинка -- это ассет, который надо где-то
-- держать, который модерируется и который может однажды перестать грузиться.
-- Здесь всё рисует движок.
--
--
-- sink -- КУДА СКЛАДЫВАТЬ КОННЕКТЫ
--
-- Контрол слушает мышь глобально (иначе перетаскивание рвётся, стоит курсору
-- уйти за пределы квадрата), поэтому обязан уметь отключаться. Владелец
-- передаёт свой список: строка -- window.conns на всю жизнь окна, всплывающее
-- окно -- свой, который гаснет при закрытии.

local UserInputService = game:GetService("UserInputService")

local THEME = NierUI.Theme
local U = NierUI.util

local HUE_STOPS = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
})

-- parent  -- куда встроить
-- opts    -- Position (UDim2), Width, Height, Color, Callback, sink, ZIndex
-- Высота HEX-строки под квадратом. Отдаётся наружу, чтобы вызывающие
-- резервировали место числом отсюда, а не подгоняли на глаз.
local HEX_H = 22
NierUI.colorControlExtra = HEX_H

function NierUI.colorControl(parent, opts)
    local z = opts.ZIndex or 30
    local fieldHeight = opts.Height or 100
    local sink = opts.sink or {}

    local h, s, v = Color3.toHSV(opts.Color or Color3.fromRGB(255, 40, 40))

    -- Ширина: число -- пиксели, ничего -- во всю ширину родителя. Ноль тут
    -- пикселями и остаётся, потому что «во всю ширину» просят ОТСУТСТВИЕМ поля,
    -- а не нулём: строка-палитра когда-то передавала Width = 0 и тут же
    -- переписывала размер сама -- то есть просила нулевую ширину и чинила
    -- последствия следующей строкой.
    local size = opts.Width
        and UDim2.fromOffset(opts.Width, fieldHeight + HEX_H)
        or UDim2.new(1, 0, 0, fieldHeight + HEX_H)

    local holder = U.new("Frame", {
        BackgroundTransparency = 1,
        Position = opts.Position or UDim2.fromOffset(0, 0),
        Size = size,
        ZIndex = z,
    }, parent)

    -- ACTIVE = TRUE ОБЯЗАТЕЛЕН, И ЭТО НЕ МЕЛОЧЬ.
    --
    -- Frame с Active = false щелчок не перехватывает -- он проваливается
    -- насквозь к тому, что лежит ниже. В строке под палитрой ничего не было, и
    -- это сходило с рук. Во всплывающем окне ниже лежит фон-перехватчик во весь
    -- экран, и щелчок по квадрату уходил в него: окно закрывалось раньше, чем
    -- начиналось перетаскивание, выбрать цвет было невозможно в принципе.
    --
    -- То же будет с любым будущим контролом внутри всплывающего окна: не
    -- поглощаешь щелчок -- закрываешь окно вместо работы.
    local field = U.new("Frame", {
        BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0,
        Active = true, Size = UDim2.new(1, -24, 0, fieldHeight), ZIndex = z,
    }, holder)

    local white = U.new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Active = false, Size = UDim2.fromScale(1, 1), ZIndex = z + 1,
    }, field)
    U.new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, white)

    local black = U.new("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
        Active = false, Size = UDim2.fromScale(1, 1), ZIndex = z + 2,
    }, field)
    U.new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, black)

    local fieldDot = U.new("Frame", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7),
        ZIndex = z + 4,
    }, field)
    U.stroke(fieldDot, 1, Color3.new(1, 1, 1))

    local hueBar = U.new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Active = true,   -- см. field: без этого щелчок уходит в фон окна
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 14, 0, fieldHeight), ZIndex = z,
    }, holder)
    U.new("UIGradient", { Rotation = 90, Color = HUE_STOPS }, hueBar)

    local hueDot = U.new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Active = false, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(1, 4, 0, 2),
        ZIndex = z + 4,
    }, hueBar)

    --== HEX ==================================================================
    --
    -- Мышью в конкретный цвет не попасть -- это две координаты по сотне
    -- пикселей плюс тон. Поэтому цвет можно вписать кодом, и это тот же
    -- контрол, что стоит и в строке меню, и во всплывающем окне у пункта
    -- списка: пишется один раз, работает в обоих местах.

    -- Поле шириной РОВНО ПО КОДУ, а не во всю ширину контрола. Растянутое на
    -- всю строку, оно ловило щелчки далеко правее самого текста -- по пустому
    -- месту под квадратом.
    --
    -- Растёт вправо от левого края, поэтому код стоит на месте. Нижний предел
    -- нужен пустому полю: без него в него нечем попасть.
    local hexBox = U.new("TextBox", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = "", TextColor3 = THEME.Ink, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextEditable = true, ClearTextOnFocus = false,
        Position = UDim2.new(0, 0, 0, fieldHeight + 4),
        Size = UDim2.fromOffset(0, HEX_H - 4),
        AutomaticSize = Enum.AutomaticSize.X, ZIndex = z,
    }, holder)
    U.new("UISizeConstraint", { MinSize = Vector2.new(48, HEX_H - 4) }, hexBox)

    local editing = false

    -- Разрешаем решётку первым символом и до шести шестнадцатеричных цифр.
    -- Фильтруем по ходу набора: иначе набранные буквы видны, а на выходе молча
    -- превращаются в прежний цвет -- выглядит как проглоченный ввод.
    local function sanitizeHex(text)
        local out, digits = {}, 0
        for i = 1, #text do
            local ch = text:sub(i, i)
            if ch == "#" and #out == 0 then
                out[#out + 1] = ch
            elseif ch:match("[0-9a-fA-F]") and digits < 6 then
                digits = digits + 1
                out[#out + 1] = ch:upper()
            end
        end
        return table.concat(out)
    end

    -- Разбор -- в Util: тот же нужен кодеку конфига, и двух копий быть не должно.

    --=========================================================================

    local api = {}

    local function color()
        return Color3.fromHSV(h, s, v)
    end

    local function render(silent)
        field.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        fieldDot.Position = UDim2.fromScale(s, 1 - v)
        hueDot.Position = UDim2.fromScale(0.5, h)
        if not editing then hexBox.Text = U.hex(color()) end
        -- Тот же общий вызов, что у всех виджетов (см. NierUI.fire): своя копия
        -- здесь молча глотала ошибку владельца палитры.
        NierUI.fire(opts, silent, color())
    end
    render(true)

    table.insert(sink, hexBox:GetPropertyChangedSignal("Text"):Connect(function()
        if not editing then return end
        local clean = sanitizeHex(hexBox.Text)
        if clean ~= hexBox.Text then hexBox.Text = clean end
    end))

    table.insert(sink, hexBox.Focused:Connect(function()
        editing = true
    end))

    table.insert(sink, hexBox.FocusLost:Connect(function()
        editing = false
        local parsed = U.fromHex(hexBox.Text)
        if parsed then
            h, s, v = Color3.toHSV(parsed)
        end
        -- не разобралось -- render вернёт прежний код обратно в поле
        render()
    end))

    -- Одна переменная с именем активной области, а не два независимых флага:
    -- иначе нажатие в квадрате и увод курсора на полосу тянуло бы обе сразу.
    local dragging = nil

    local function applyField(x, y)
        s = U.alongX(field, x)
        v = 1 - U.alongY(field, y)
        render()
    end

    local function applyHue(y)
        h = U.alongY(hueBar, y)
        render()
    end

    table.insert(sink, field.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = "field"
        applyField(input.Position.X, input.Position.Y)
    end))

    table.insert(sink, hueBar.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = "hue"
        applyHue(input.Position.Y)
    end))

    table.insert(sink, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if dragging == "field" then
            applyField(input.Position.X, input.Position.Y)
        else
            applyHue(input.Position.Y)
        end
    end))

    table.insert(sink, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = nil end
    end))

    -- Внутренний контрол, не виджет: вызывается точкой, без self. Виджеты
    -- наружу отдают двоеточные Get/Set -- смешивать соглашения в одном файле
    -- нельзя, а разводить их по слоям можно и нужно.
    function api.Get() return color() end
    function api.Set(c, silent)
        h, s, v = Color3.toHSV(c)
        render(silent)
    end
    api.instance = holder

    return api
end

end)(NierUI)

--============================ NierUI/Row.luau ============================
;(function(NierUI)
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

end)(NierUI)

--============================ NierUI/Binds.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Binds -- ядро привязок
--=============================================================================
--
--     local fly = move:Toggle({ Text = "ПОЛЁТ", Flag = "fly", Bind = true,
--                               Callback = function(on) ... end })
--
-- Скриптер говорит, ЧТО делать. Всё остальное -- дело человека за меню, и ядро
-- ничего из этого не требует при объявлении.
--
--
--=============================================================================
-- ТРИ ВЕЩИ ПРИНАДЛЕЖАТ ЧЕЛОВЕКУ, А НЕ СКРИПТУ
--=============================================================================
--
--   КЛАВИША  какая, и есть ли вообще. По умолчанию её нет, и NONE -- рабочее
--            состояние, а не «ещё не настроено».
--
--   РЕЖИМ    ПЕРЕКЛ. или ЗАЖАТИЕ. Одному та же фича нужна тумблером, другому --
--            пока держишь клавишу. Решать это за них скриптер не может, а
--            заводить под каждый вкус по привязке -- значит удваивать список.
--
--   ПОДПИСЬ  своё имя в своём списке. Личность привязки при этом НЕ МЕНЯЕТСЯ:
--            она в Flag. Ровно поэтому подпись и разрешено трогать --
--            переименование не осиротит профиль. Тот же довод, по которому
--            папку конфигов нельзя выводить из заголовка окна.
--
-- Все три живут в профиле рядом с состоянием и правятся в двух местах: в меню
-- правой кнопки у самой строки и в менеджере привязок. Оба написаны на
-- публичных примитивах ядра -- привилегированных потребителей у него нет. Не
-- хватит чего-то стороннему менеджеру -- не хватит и встроенному, и добавится
-- это сюда, а не в вид.
--
--
-- ДЕЙСТВИЕ -- НЕ РЕЖИМ. kind = "action" человеком не выбирается и в список
-- режимов не попадает: у действия нет состояния, переключать в нём нечего и
-- удерживать нечего. Местами меняются только ПЕРЕКЛ. и ЗАЖАТИЕ, и только у той
-- привязки, у которой состояние есть.
--
--
--=============================================================================
-- ПРИВЯЗКИ РАЗЛИЧАЮТСЯ ЦЕЛЬЮ, И ЭТО ГЛАВНОЕ РАЗЛИЧЕНИЕ ЗДЕСЬ
--=============================================================================
--
-- В первом наброске нажатие переключало строку, на которой привязка объявлена.
-- Это покрывает ровно один случай -- «фича вкл/выкл клавишей» -- и делает
-- невозможным всё остальное: любая привязка рубила функцию целиком вместо того,
-- чтобы с ней РАБОТАТЬ.
--
-- Целей две, и путать их нельзя:
--
--     Bind    РУБИЛЬНИК. Цель -- сама строка: нажал, функция включилась,
--             нажал, выключилась. Ворот у него нет и быть не может --
--             выключенную строку иначе нечем было бы включить. Он один: две
--             привязки, переключающие одну строку, не значат ничего.
--
--     Binds   ВЗАИМОДЕЙСТВИЕ. Цель -- сама функция. Строка для них -- ВОРОТА:
--             пока она ON, они действуют; человек её выключил -- они безусловно
--             уходят в OFF и молчат, сколько ни жми. Строку они не трогают
--             никогда. Их сколько угодно.
--
-- Скриптер объявляет любую комбинацию: только рубильник (обычная фича), только
-- взаимодействия (строка -- чистые ворота, клавишей её не переключить), или оба
-- сразу -- одной клавишей рубим функцию, другими работаем с ней.
--
-- Отсюда и три состояния, которые видно в списке: у рубильника -- состояние
-- строки, у взаимодействия с Toggle -- своё собственное, у взаимодействия с
-- Action -- никакого, [BUTTON].
--
--
-- ГДЕ ЖИВЁТ СОСТОЯНИЕ -- РОВНО В ОДНОМ МЕСТЕ, И МЕСТО ЗАВИСИТ ОТ ЦЕЛИ
--
-- Рубильник хранит не значение, а ПАРУ ФУНКЦИЙ до строки: get и set. set при
-- этом тот же самый, что зовёт щелчок мышью, поэтому нажатие клавиши и щелчок
-- по строке буквально неразличимы -- один код, одно уведомление, одна правда.
--
-- У взаимодействия с Toggle хозяина этому «включено» обычно нет, и хранит его
-- сама запись. Скрипту уходит вызов Toggle(on); он ничего не хранит.
--
-- ОБЫЧНО -- НО НЕ ВСЕГДА, И ЭТО НЕ РЕДКИЙ СЛУЧАЙ. Бывает, что состояние держит
-- сама фича, потому что оно ей и принадлежит: захват цели либо состоялся, либо
-- нет, и решает это не нажатие, а то, есть ли кого захватывать. Такое состояние
-- ещё и пропадает БЕЗ КЛАВИШИ -- цель умерла, ушла за дистанцию, сменился
-- раунд. Тогда скриптер даёт State -- вопрос к настоящему хозяину, -- и запись
-- не хранит ничего, а спрашивает.
--
-- Хранящая копия в таком случае -- это ложь по построению, и врёт она с первого
-- же нажатия: Toggle(true) записывал «включено» ДО того, как выяснится, что
-- включать было нечего. На экране горело [ON] при пустом захвате.
--
-- Отсюда правило про уведомления: о смене сообщает ВЛАДЕЛЕЦ. Строка сообщает
-- сама, через NierUI.stateChanged; своё состояние ядро хранит и сообщает тоже
-- само; чужое сообщает тот, чьё оно, -- вызовом Sync. Двух сообщений об одной
-- смене не бывает: хозяин всегда один.
--
--
-- ОДНА ПРИВЯЗКА НА СТРОКЕ -- ПРОДОЛЖЕНИЕ СТРОКИ, НЕСКОЛЬКО -- СВОИ ЛЮДИ
--
-- Это правило про ПОКАЗ, а не про устройство, и работает в двух местах. Одна:
-- берёт подпись строки, редакторы в меню лежат плоско. Несколько: каждая
-- называет себя сама, подпись собирается из обеих, меню делится на секции.
-- Иначе список показывал бы несколько одинаковых строк подряд, а из меню было
-- бы не понять, чью клавишу правишь.
--
--
--=============================================================================
-- НИ ОДНОГО ЦИКЛА
--=============================================================================
--
-- Удержание -- InputEnded, а не опрос клавиатуры. Состояние -- ручка владельца,
-- а не сверка по таймеру. Актуальность списка -- подписка, а не перерисовка
-- каждый кадр. Ожидание нажатия -- временная подписка, а не ожидание в потоке.
-- Покадровых задач ядро не заводит вовсе.
--
--
-- ДВЕ ПОДПИСКИ НА ОКНО, А НЕ ПО ПАРЕ НА ПРИВЯЗКУ
--
-- Виджет Keybind вешал свои InputBegan и InputEnded. При десяти привязках это
-- двадцать обработчиков на КАЖДЫЙ нажатый символ, включая набор текста в поле
-- ввода. Здесь две на всё окно, а нужная запись достаётся из индекса по
-- клавише: чужое нажатие стоит трёх проверок и одной выборки из хеша.

local UserInputService = game:GetService("UserInputService")

--=============================================================================
-- Клавиша -- это KeyCode ИЛИ UserInputType
--=============================================================================
--
-- Правая и средняя кнопки мыши -- такая же привязка, как F. Кодек профиля это
-- умеет с самого начала (см. Config: у EnumItem пишется и само перечисление), а
-- вот прежний редактор принимал только Enum.KeyCode и молча превращал мышиную
-- настройку в клавиатурную.
--
-- ЛЕВАЯ КНОПКА ПРИВЯЗЫВАЕТСЯ, НО НЕ СРАБАТЫВАЕТ ПРИ ОТКРЫТОМ МЕНЮ.
--
-- Раньше она была запрещена совсем, и довод был: ею открывают само ожидание, ею
-- же водят по меню и таскают окна -- привязка на неё сделала бы меню
-- неуправляемым, а снять её было бы нечем, пришлось бы попасть по строке той же
-- кнопкой, которая в этот момент срабатывает.
--
-- Довод верен ровно наполовину: весь конфликт живёт, ПОКА МЕНЮ ОТКРЫТО. Закрыто
-- -- и левая кнопка такая же клавиша, как любая другая, а в играх она главная:
-- на ней удар, выстрел, зарядка броска. Запрещать привязку на самое нужное
-- ради состояния, в котором привязки и так не нужны, -- плохой размен.
--
-- Поэтому запрет сузился до одного правила: при открытом меню нажатие левой
-- кнопки привязке не достаётся (см. ensureInput). Меню остаётся управляемым,
-- по строке можно попасть, и снять привязку есть чем.
--
-- Отпускание при этом проходит ВСЕГДА -- иначе ЗАЖАТИЕ, начатое до открытия
-- меню, осталось бы включённым навсегда.

local MOUSE = {
    [Enum.UserInputType.MouseButton1] = true,
    [Enum.UserInputType.MouseButton2] = true,
    [Enum.UserInputType.MouseButton3] = true,
}

-- Во что превратить нажатие. nil -- привязке оно достаться не может.
local function codeOf(input)
    local source = input.UserInputType
    if source == Enum.UserInputType.Keyboard then
        local code = input.KeyCode
        return code ~= Enum.KeyCode.Unknown and code or nil
    end
    if MOUSE[source] then return source end
    return nil
end

--=============================================================================
-- Привязка
--=============================================================================

local Bind = {}
Bind.__index = Bind

local Core = {}
Core.__index = Core

-- ВЫЧЕРКНУТЬ ИЗ МАССИВА. Обход С КОНЦА, а не с начала: table.remove сдвигает
-- хвост, и прямой проход перескочил бы через соседа вычеркнутого.
--
-- Тремя копиями это лежало в трёх местах разом -- индекс по клавише, список
-- подписчиков, реестр привязок, -- и во всех трёх ошибиться можно одинаково.
local function drop(list, item)
    for i = #list, 1, -1 do
        if list[i] == item then table.remove(list, i) end
    end
end

--== индекс по клавише =======================================================
--
-- Массив, а не одна запись: две привязки на одну клавишу -- не ошибка, а
-- иногда и намерение. Арбитром ядро не выступает, срабатывают обе; увидеть это
-- можно в списке, а посчитать -- перебором All() у того, кому надо. Отдельного
-- метода под такой вопрос здесь не будет: всё, что выводится из реестра тремя
-- строками, методом ядра быть не должно.

local function unindex(core, bind)
    local list = bind.key and core.byKey[bind.key]
    if not list then return end
    drop(list, bind)
    if #list == 0 then core.byKey[bind.key] = nil end
end

local function reindex(core, bind, key)
    unindex(core, bind)
    bind.key = key
    if not key then return end

    local list = core.byKey[key]
    if not list then
        list = {}
        core.byKey[key] = list
    end
    list[#list + 1] = bind
end

--== разбор нажатия ==========================================================

local function press(core, code)
    local list = core.byKey[code]
    if not list then return end

    -- По копии: обработчик вызывающего вполне может снять привязку прямо в
    -- момент срабатывания -- кнопка «снять всё» именно это и делает.
    for _, bind in ipairs(table.clone(list)) do
        -- ВОРОТА ЗАКРЫТЫ -- НЕ ПРОИСХОДИТ НИЧЕГО, включая подсветку удержания.
        -- Мастер-свитч выключен, значит клавиша не просто бездействует, а не
        -- принадлежит привязке вовсе: мигать в списке ей нечем и незачем.
        if bind.enabled and bind:Gated() then
            bind.held = true

            -- ДЕЙСТВИЕ ВЫПОЛНЯЕТСЯ ТЕМ ЖЕ Fire, ЧТО ОТДАН НАРУЖУ. Здесь стояла
            -- его копия -- тот же pcall и то же предупреждение слово в слово, --
            -- то есть нажатие клавиши и вызов из кода расходились бы на первой
            -- же правке одного из двух.
            if bind.kind == "hold" then
                bind:Set(true)
            elseif bind.kind == "toggle" then
                bind:Set(not bind:Get())
            elseif bind.fire then
                bind:Fire()
            end

            core:notify(bind, "held")
        end
    end
end

local function release(core, code)
    local list = core.byKey[code]
    if not list then return end

    for _, bind in ipairs(table.clone(list)) do
        if bind.held then
            bind.held = false
            -- Отпустили -- ЗАЖАТИЕ гаснет всегда, даже если привязку успели
            -- выключить между нажатием и отпусканием: включённое состояние,
            -- которое человек считает отпущенным, хуже лишнего вызова.
            if bind.kind == "hold" then bind:Set(false) end
            core:notify(bind, "held")
        end
    end
end

-- ОТПУСТИТЬ УДЕРЖАНИЕ РУКАМИ, ПОТОМУ ЧТО КЛАВИША ЕГО УЖЕ НЕ ОТПУСТИТ.
--
-- Поводов четыре, и все про одно: между нажатием и отпусканием у привязки
-- поменяли то, по чему release её находит. Сменили клавишу -- InputEnded придёт
-- по старой, а привязки на ней уже нет. Выключили строку -- отпускание дойдёт,
-- но гасить будет нечего, если состояние осталось включённым. Снесли запись или
-- всё окно -- отпускание не дойдёт вовсе, подписки уже не существует.
--
-- Во всех четырёх случаях включённым осталось бы то, что человек считает
-- отпущенным, а это хуже лишнего вызова. Четырьмя копиями этот десяток строк и
-- лежал -- по одной на повод, и они уже начали расходиться: снос записи не
-- сбрасывал held, снос окна сбрасывал его после вызова, а не до.
--
-- Уведомления отсюда НЕТ намеренно: у каждого повода своё («key», «enabled»,
-- «removed»), и оно уходит следом за той правкой, которая его вызвала.
-- Отдельное «held» значило бы два сообщения об одном действии.
local function unhold(bind)
    if not bind.held then return end
    bind.held = false
    if bind.kind == "hold" then bind:Set(false) end
end

--== подписки ================================================================
--
-- Заводятся при ПЕРВОЙ привязке, а не в конструкторе окна: у меню без привязок
-- обработчиков ввода не появляется вовсе.

--== ЧЬЁ НАЖАТИЕ ============================================================
--
-- processed означает «его уже кто-то съел». Сперва мы на этом просто выходили
-- -- и это была ошибка, стоившая всех ходовых клавиш.
--
-- Замерено на живом клиенте: привязка на R не срабатывала никогда, при пустом
-- реестре ожиданий и без фокуса в поле. Разбор показал processed = true --
-- клавишу съедала САМА ИГРА, повесившая на неё своё действие. То же ждёт любую
-- клавишу, которая игре пригодилась: R, T, G, F. Человеку оставался выбор из
-- того, что игра не заняла, и объяснить ему это было нечем -- клавиша
-- назначается, в списке стоит, а не работает.
--
-- Для меню, которое ставят ПОВЕРХ игры, это ровно наоборот: наша привязка
-- обязана выигрывать у игровой. Иначе теряется весь смысл переназначения.
--
-- Настоящая причина, по которой нажатие бывает не наше, ровно одна и названа в
-- прежнем комментарии: НАБОР ТЕКСТА. Её и проверяем прямо -- есть фокус в поле,
-- значит человек печатает, и «f» в имени привязки не должна поднимать самолёт.
--
-- У МЫШИ ПРАВИЛО ПРЕЖНЕЕ. Там processed означает «щёлкнули по интерфейсу», и
-- это правда наш собственный интерфейс: нажатие по строке меню принадлежит
-- строке, а не привязке на ту же кнопку.
local function ours(input, processed)
    if UserInputService:GetFocusedTextBox() then return false end
    if input.UserInputType ~= Enum.UserInputType.Keyboard and processed then
        return false
    end
    return true
end

local function ensureInput(core)
    if core.conns then return end
    core.conns = true

    local window = core.window

    table.insert(window.conns, UserInputService.InputBegan:Connect(function(input, processed)
        if not ours(input, processed) then return end
        -- Строка ждёт назначения -- нажатие принадлежит ЕЙ. Без этого
        -- назначение занятой клавиши попутно дёргало занявшего: метишь в бинд,
        -- включается фича.
        if core.grab > 0 then return end

        local code = codeOf(input)
        if not code then return end

        -- ЛЕВАЯ КНОПКА ПРИ ОТКРЫТОМ МЕНЮ ПРИНАДЛЕЖИТ МЕНЮ, А НЕ ПРИВЯЗКЕ.
        --
        -- Ею щёлкают по строкам, таскают окна и открывают ожидание клавиши.
        -- Одного processed для этого мало: он верен, только пока меню забирает
        -- ввод себе, а при CaptureInput = false щелчок мимо окна приходит
        -- необработанным -- и привязка срабатывала бы прямо во время настройки.
        if code == Enum.UserInputType.MouseButton1 and window.visible then return end

        press(core, code)
    end))

    -- ОТПУСКАНИЕ ПРОХОДИТ ВСЕГДА: ни processed, ни захват его не отменяют.
    -- Клавишу могли зажать до того, как открылось меню или началось ожидание,
    -- и пропущенное отпускание оставило бы ЗАЖАТИЕ включённым навсегда.
    table.insert(window.conns, UserInputService.InputEnded:Connect(function(input)
        local code = codeOf(input)
        if not code then return end
        release(core, code)
    end))
end

--=============================================================================
-- Реестр
--=============================================================================

function NierUI.bindCore(window)
    return setmetatable({
        window = window,
        -- Порядок объявления: списку и менеджеру нужен устойчивый, а обход
        -- хеша в Lua не определён и перемешивал бы строки при каждом показе.
        list = {},
        byName = {},
        byKey = {},
        watchers = {},
        -- Сколько ожиданий нажатия взведено. Пока не ноль, клавиатура
        -- принадлежит им -- и привязки, и клавиша открытия меню молчат.
        grab = 0,
        -- Чем отменить текущее ожидание. Ждущий всегда ОДИН, см. capture.
        pending = false,
        conns = false,
    }, Core)
end

-- ПО КОПИИ, А НЕ ПО ЖИВОМУ СПИСКУ.
--
-- Подписчик вправе отписаться прямо в обработчике, и делает это не гипотетически:
-- менеджер привязок на "added"/"removed"/"made" пересобирает своё содержимое,
-- снос строк гасит их стоки, а в стоке каждой строки-редактора клавиши лежит её
-- собственный unwatch -- то есть table.remove из ЭТОГО списка посреди обхода.
--
-- ipairs по укорачивающемуся списку перескакивает через соседа: подписчик,
-- стоявший за менеджером, событие не получал вовсе. На экране это выглядело как
-- список привязок, отстающий на одно действие, -- добавил привязку в менеджере,
-- а в списке она появляется только после следующей правки.
--
-- Та же ошибка и то же лечение, что у обхода панелей в Window:Destroy и у
-- Core.All, который копию отдаёт ровно по этой причине.
function Core.notify(self, bind, what)
    for _, fn in ipairs(table.clone(self.watchers)) do pcall(fn, bind, what) end
end

-- what -- ровно то, что ядро умеет сообщить, и другого не бывает:
--
--     "added" "removed"    состав реестра
--     "made"               привязку создали или сняли (см. Bind.Made)
--     "key" "kind" "title" человек поправил её настройки
--     "shown"              показывать ли её в списке на экране
--     "enabled"            доступна ли строка, которой она принадлежит
--     "held"               клавишу нажали или отпустили
--     "state"              сменилось состояние -- своё или той строки, в
--                          которую привязка целится
--
-- bind == nil означает, что изменился состав реестра или что-то, чего ядро не
-- знает поимённо, -- вид пересобирается целиком. Иначе правится одна строка.
--
-- Букета сигналов не будет: виду нужен повод перерисоваться, а не двадцать
-- подписок, каждую из которых надо не забыть снять.
function Core.Changed(self, fn)
    table.insert(self.watchers, fn)
    return function() drop(self.watchers, fn) end
end

-- КОПИЯ, а не живой список: вид перебирает его и вполне может по дороге снять
-- привязку -- менеджер это и делает.
function Core.All(self)
    return table.clone(self.list)
end

function Core.Get(self, name)
    return self.byName[name]
end

--=============================================================================
-- ИМЕНА ПОЛЕЙ ЗДЕСЬ ТЕ ЖЕ, ЧТО ПИШЕТ СКРИПТЕР
--=============================================================================
--
--   Text     подпись; человек её потом может сменить
--   Flag     имя, по которому привязку находят. Нет имени -- работает, но
--            найти её через binds:Get нельзя
--   Key      стартовая клавиша. Нет -- NONE, и это рабочее состояние
--   Kind     "toggle" | "hold" | "action"; по умолчанию выводится из действия
--   Toggle   function(on) -- у привязки СВОЁ вкл/выкл, хранит его запись
--   State    function() -> boolean -- ...если только хозяин не снаружи: тогда
--            запись не хранит ничего и спрашивает. Только вместе с Toggle
--   Action   function()   -- сработало и всё, состояния нет
--
-- и внутреннее, что дописывает виджет, -- строчными, как sink у палитры:
--
--   get/set  пара до строки. Так объявляется РУБИЛЬНИК: цель -- сама строка
--   gate     function() -> boolean. Ворота: пока false, привязка инертна
--   row      строка меню, если привязка объявлена на ней
--   rowTitle подпись строки, чтобы собрать из двух свою
--
-- Перевода из одних имён в другие нет нигде: и Toggle, и Button, и win:Bind
-- зовут это тем же набором, который человек написал в объявлении. Слой перевода
-- -- ровно то место, где однажды разъедутся два написания одного поля.
function Core.Add(self, opts)
    local name = opts.Flag or false
    if name and self.byName[name] then
        error(("[NierUI] привязка «%s» уже объявлена"):format(tostring(name)), 3)
    end

    --== чем управляет ========================================================
    --
    -- Пара get/set либо приходит снаружи (рубильник целится в строку), либо
    -- заводится здесь (у привязки своё состояние, и другого хозяина у него
    -- нет). Третий случай -- Action -- состояния не имеет вовсе.

    local get, set, owns = opts.get, opts.set, false

    if opts.Toggle then
        if get then
            error("[NierUI] привязка либо переключает строку, либо имеет своё "
                .. "состояние (Toggle) -- не то и другое разом", 3)
        end
        owns = true

        if opts.State then
            --== ХОЗЯИН СНАРУЖИ: СПРАШИВАЕМ, А НЕ ХРАНИМ =====================
            --
            -- Своей копии тут нет НАМЕРЕННО, и дело не в экономии. Копия
            -- расходится с правдой двумя разными способами сразу:
            --
            --   включение может НЕ СОСТОЯТЬСЯ -- в круге никого, цеплять
            --   нечего, -- а записанное «включено» уже легло;
            --
            --   состояние может пропасть БЕЗ НАС -- цель умерла, ушла за
            --   дистанцию, сменился раунд, -- и копия об этом не узнает вовсе.
            --
            -- Спрашивая, мы не можем ошибиться ни в том, ни в другом: ответ
            -- всегда сегодняшний. Цена -- вызов на каждую перерисовку списка,
            -- и это ровно тот обмен, который библиотека делает везде (см.
            -- Gated и «НИЧЕГО НЕ КЕШИРУЕМ» в Hud).
            get = opts.State
            set = function(on) opts.Toggle(on) end
        else
            local own = false
            get = function() return own end
            set = function(on)
                own = on
                opts.Toggle(on)
            end
        end
    elseif opts.State then
        -- State ОТВЕЧАЕТ НА ВОПРОС, а переключать состояние нечем -- такая
        -- привязка была бы вечно inertна: нажали, спросили, ничего не
        -- изменилось. У рубильника же хозяин известен и так -- это строка.
        error("[NierUI] State без Toggle: спрашивать состояние есть у кого, а "
            .. "переключать его нечем. Рубильнику State не нужен -- у него "
            .. "хозяин строка", 3)
    end

    local stateful = get ~= nil and set ~= nil

    if stateful and opts.Action then
        error("[NierUI] привязка либо имеет состояние, либо это действие "
            .. "(Action) -- не то и другое разом", 3)
    end

    local kind = opts.Kind or (stateful and "toggle" or "action")
    if stateful == (kind == "action") then
        error(("[NierUI] режим «%s» не сходится с тем, что привязка умеет: "
            .. "состояние есть -- значит toggle или hold, нет -- значит action")
            :format(tostring(kind)), 3)
    end

    --== МОЖНО ЛИ ИГРОКУ МЕНЯТЬ РЕЖИМ ========================================
    --
    -- ОТДЕЛЬНОЕ РЕШЕНИЕ СКРИПТЕРА, А НЕ СЛЕДСТВИЕ ЧЕГО-ЛИБО.
    --
    -- Сперва строка выбора появлялась сама у всякой привязки с состоянием. То
    -- есть право игрока крутить режим выводилось из того, каким полем скриптер
    -- записал колбэк, -- он о таком решении даже не знал, что не мешало ему это
    -- решение принять.
    --
    -- Теперь молчание значит молчание: не сказал ChangeModeInGame -- режим
    -- стоит там, куда его поставили в коде, и в меню его нет. Из кода при этом
    -- SetKind работает всегда: флаг про ЧЕЛОВЕКА за меню, а не про API.
    --
    -- ДЕЙСТВИЮ ЭТОТ ФЛАГ -- ОШИБКА, А НЕ МОЛЧАЛИВЫЙ ОТКАЗ. Одноразовая привязка
    -- -- отдельный вид: она срабатывает и кончается, состояния у неё нет.
    -- Удерживать нечего, переключать нечего, и выбор из двух пустых вариантов
    -- обещал бы игроку то, чего не существует. Молча проглотить флаг хуже:
    -- скриптер будет уверен, что дал выбор, а его не будет.
    if opts.ChangeModeInGame and not stateful then
        error("[NierUI] ChangeModeInGame у действия: удерживать и переключать "
            .. "нечего, выбора из двух пустых вариантов не бывает. Нужен режим "
            .. "-- объяви привязку через Toggle, у неё есть состояние.", 3)
    end

    --== ВОРОТА ==============================================================
    --
    -- Чьё состояние держит привязку закрытой. У РУБИЛЬНИКА их нет и быть не
    -- может: он и есть то, что за воротами стоит, повесь их на него -- и
    -- выключенную строку нечем будет включить. Рубильник узнаётся по тому, что
    -- пара get/set пришла снаружи, а своего состояния у него нет.
    --
    -- ЧЕРЕЗ if, А НЕ ЧЕРЕЗ and/or. Здесь стояло
    --
    --     (not owns and opts.get) and false or (opts.gate or false)
    --
    -- и защиты не было вовсе: при ИСТИННОМ условии `X and false` даёт false, а
    -- `false or Y` возвращает Y -- то есть обе ветки давали одно и то же,
    -- `opts.gate`. Ровно та ловушка, на которой библиотека уже горела дважды:
    -- у Backspace в захвате клавиши и в GetSetting списка.
    --
    -- Не стреляло только потому, что ни один нынешний вызывающий не даёт get и
    -- gate разом. Но своему виджету заводить запись велено руками (см.
    -- docs/extending.md), и там это выстрелило бы молча.
    local gate = opts.gate or false
    if not owns and opts.get then gate = false end

    -- ОДНА ПРОВЕРКА НА ДВА ВЫВОДА. «Скриптер дал клавишу» отвечает разом на два
    -- вопроса -- создана ли привязка и что класть в индекс, -- и считалось это
    -- дважды, в двух местах, четырнадцатью строками друг от друга. Разъезжаются
    -- такие пары молча: поправят одну, и запись окажется созданной, но
    -- неиндексированной -- в списке стоит, а клавиша не работает.
    local hasKey = typeof(opts.Key) == "EnumItem"

    local bind = setmetatable({
        core = self,
        name = name,
        -- Две подписи: данная скриптером и данная человеком. Держим обе, чтобы
        -- переименование можно было ОТМЕНИТЬ -- иначе исходную было бы негде
        -- взять, и «вернуть как было» делалось бы перезапуском.
        given = opts.Text or false,
        rowTitle = opts.rowTitle or false,
        titled = false,
        key = nil,
        kind = kind,
        -- Режим, с которым привязку объявили. Нужен сбросу: «как было» иначе
        -- негде взять, и вернуть заводское получалось бы только перезапуском.
        kind0 = kind,
        held = false,
        switchable = opts.ChangeModeInGame == true,
        -- Показывать ли в списке привязок. Скриптеру этого поля не выдано: он
        -- решает, ЧТО привязка делает, а не что человеку видеть на своём
        -- экране. Правится только из менеджера.
        listed = true,
        -- СОЗДАНА ЛИ ПРИВЯЗКА -- отдельно от того, есть ли у неё клавиша.
        --
        -- Сперва «создана» выводилось из клавиши, и это ломалось ровно на
        -- добавлении: человек добавляет привязку в менеджере, клавиши у неё
        -- ещё нет, и по такому правилу она тут же исчезала из списка, в который
        -- её только что положили.
        --
        -- Скриптер дал клавишу -- привязка готова сразу. Дал Bind = true --
        -- объявил ВОЗМОЖНОСТЬ, а создаст её человек.
        made = hasKey,
        enabled = opts.Enabled ~= false,
        row = opts.row or false,
        gate = gate,   -- посчитаны выше, вместе с разбором почему
        owns = owns,
        -- Состояние живёт СНАРУЖИ и меняется мимо нас. Нужно ровно одному --
        -- Sync: сообщать о чужой смене вправе только тот, кто её не хранит.
        external = opts.Toggle ~= nil and opts.State ~= nil,
        get = get, set = set,
        fire = (not stateful) and opts.Action or nil,
    }, Bind)

    self.list[#self.list + 1] = bind
    if name then self.byName[name] = bind end
    reindex(self, bind, hasKey and opts.Key or nil)

    ensureInput(self)
    self:notify(bind, "added")
    return bind
end

-- Снять всё. Зовётся из Window:Destroy.
function Core.Destroy(self)
    if self.pending then pcall(self.pending) end

    -- ОТПУСКАЕМ УДЕРЖАНИЯ, А ТУМБЛЕРЫ НЕ ТРОГАЕМ.
    --
    -- Сперва здесь стояло «выключить всё включённое»: меню сносится -- фичи
    -- гаснут. Это неверно ровно там, где меню сносят и строят заново (так
    -- делает пересборка), -- человек ничего выключать не просил, а получил бы
    -- сброс всего накрученного на каждой пересборке.
    --
    -- Залипшее же удержание -- не его решение, а наша недоделка: отпускание
    -- придёт в подписку, которой уже нет, и включённым останется то, что
    -- человек считает отпущенным.
    --
    -- Через pcall: снос обязан дойти до конца списка, а обработчик вызывающего
    -- вправе упасть на любой записи.
    for _, bind in ipairs(self.list) do pcall(unhold, bind) end

    table.clear(self.list)
    table.clear(self.byName)
    table.clear(self.byKey)
    table.clear(self.watchers)
    self.pending = false
    -- Сами подписки лежат в window.conns и гаснут вместе с окном.
    self.conns = false
end

--=============================================================================
-- Ручка привязки
--=============================================================================

function Bind.Name(self) return self.name or nil end
function Bind.Row(self) return self.row or nil end
function Bind.Kind(self) return self.kind end

-- Разрешил ли скриптер человеку крутить режим В МЕНЮ СТРОКИ. Менеджер этого не
-- спрашивает: он высшая инстанция и разрешает то, чего не разрешил скриптер.
function Bind.CanChangeMode(self) return self.switchable end

function Bind.Made(self) return self.made end

-- Создать или убрать привязку. Убранная возвращается в список того, что можно
-- привязать, -- сама возможность никуда не девается (см. Bind.Reset).
--
-- УБРАЛИ -- ЗНАЧИТ И КЛАВИШИ НЕТ. Иначе получалась привязка, которой «не
-- существует» -- её нет ни в менеджере, ни в ДОБАВИТЬ, -- а клавишу она
-- продолжает слушать и в списке на экране стоит. Одно «создана» на два разных
-- ответа: два хозяина у одного факта, и разошлись бы они на первом же снятии.
--
-- Обратное неверно: создать привязку -- не значит выдать ей клавишу. Её человек
-- назначает сам, и NONE у только что созданной -- рабочее состояние.
function Bind.SetMade(self, on)
    on = on ~= false
    if on == self.made then return end
    if not on then self:SetKey(nil) end
    self.made = on
    self.core:notify(self, "made")
end

function Bind.Shown(self) return self.listed end

function Bind.SetShown(self, on)
    on = on ~= false
    if on == self.listed then return end
    self.listed = on
    self.core:notify(self, "shown")
end
function Bind.Held(self) return self.held end
function Bind.Enabled(self) return self.enabled end

-- ВОРОТА ОТКРЫТЫ? У рубильника и у привязки без строки их нет вовсе -- такая
-- всегда действует. Спрашивается на каждое нажатие и на каждую перерисовку:
-- состояние строки меняется мимо нас, и копия разошлась бы.
function Bind.Gated(self)
    if not self.gate then return true end
    local ok, open = pcall(self.gate)
    return ok and open and true or false
end

-- Одна привязка на строке -- подпись строки; несколько -- своя, через пробел от
-- строчной. См. шапку: это правило про показ, и оно же в меню.
function Bind.Title(self)
    if self.titled then return self.titled end
    if self.given and self.rowTitle then
        return tostring(self.rowTitle) .. " " .. tostring(self.given)
    end
    return self.given or self.rowTitle or self.name or "привязка"
end

-- nil или пустая строка возвращают подпись, которую дал скриптер.
function Bind.SetTitle(self, text)
    local own = text ~= nil and tostring(text) or ""
    self.titled = own ~= "" and own or false
    self.core:notify(self, "title")
    return self:Title()
end

function Bind.Key(self) return self.key end

-- Готовая подпись клавиши. Здесь, а не в каждом виде: иначе «NONE» пишется
-- трижды и однажды разойдётся.
function Bind.KeyName(self)
    return self.key and self.key.Name or "NONE"
end

function Bind.KeyType(self)
    if not self.key then return nil end
    return self.key.EnumType == Enum.KeyCode and "Keyboard" or "Mouse"
end

function Bind.SetKey(self, key)
    if key ~= nil and typeof(key) ~= "EnumItem" then
        error("[NierUI] SetKey ждёт EnumItem или nil, получено: " .. typeof(key), 2)
    end
    if key == self.key then return end

    unhold(self)

    reindex(self.core, self, key)
    -- Назначили клавишу той, которой ещё не существовало, -- значит создали.
    -- Иначе SetKey из кода давал бы работающую привязку, которой нет ни в одном
    -- списке.
    if key ~= nil and not self.made then
        self.made = true
        self.core:notify(self, "made")
    end
    self.core:notify(self, "key")
end

function Bind.SetKind(self, kind)
    if self.kind == "action" or kind == "action" then
        error("[NierUI] режим есть только у привязки с состоянием: действию "
            .. "нечего переключать и нечего удерживать", 2)
    end
    if kind ~= "toggle" and kind ~= "hold" then
        error(("[NierUI] режим бывает «toggle» или «hold», получено: %s")
            :format(tostring(kind)), 2)
    end
    if kind == self.kind then return end

    self.kind = kind

    --== СМЕНА РЕЖИМА СОГЛАСУЕТ СОСТОЯНИЕ С КЛАВИШЕЙ =========================
    --
    -- В ЗАЖАТИИ состояние ПРИНАДЛЕЖИТ клавише: включено -- значит её держат. В
    -- ПЕРЕКЛ. не принадлежит: там держать нечего. Момент смены -- единственный,
    -- когда эти два правила встречаются, и согласовать их больше негде.
    --
    -- Здесь стояла половина этого правила -- только про ПЕРЕКЛ., -- и вторая
    -- половина ловилась руками: включил тумблером, переставил в ЗАЖАТИЕ -- и
    -- фича висит в ON, хотя клавишу никто не держит. Погасить её можно было
    -- только нажав и отпустив клавишу ещё раз.
    --
    -- Обратный случай -- сменили на ПЕРЕКЛ., пока клавишу держат: отпускание до
    -- состояния уже не дойдёт (release гасит только ЗАЖАТИЕ), и включённым
    -- останется то, что человек считает отпущенным.
    --
    -- Оба случая -- одно условие: удержание обязано сойтись с новым режимом.
    --
    -- ГАСИМ, НО НЕ ЗАЖИГАЕМ. Обратное -- включить фичу оттого, что человек
    -- ткнул в «режим», -- ошибка куда дороже: выключенное он увидит и включит
    -- сам, а включившееся само по себе объяснить нечем.
    if self.held ~= (kind == "hold") then self:Set(false) end

    self.core:notify(self, "kind")
end

function Bind.SetEnabled(self, on)
    on = on ~= false
    if on == self.enabled then return end
    self.enabled = on

    if not on then unhold(self) end

    self.core:notify(self, "enabled")
end

-- nil у привязки без состояния -- это ДЕЙСТВИЕ, а не «выключено». Список
-- показывает ему [BUTTON]: [OFF] читалось бы как отключённое, [ON] обещало бы
-- состояние, которого нет.
function Bind.Get(self)
    if not self.get then return nil end
    local ok, value = pcall(self.get)
    if not ok then return false end
    return value and true or false
end

-- О СМЕНЕ СООБЩАЕТ ВЛАДЕЛЕЦ.
--
-- Рубильник целится в строку -- она и сообщит, через NierUI.stateChanged, как и
-- о щелчке мышью по себе же. Добавь мы сюда своё -- одна смена слала бы два
-- уведомления, и различить их было бы нечем.
--
-- А вот собственное состояние привязки не знает никто, кроме нас: скрипту ушёл
-- вызов Toggle(on), и он ничего не хранит. Значит и сообщаем сами.
function Bind.Set(self, on)
    if not self.set then return end
    on = on and true or false
    if on == self:Get() then return end

    local ok, err = pcall(self.set, on)
    if not ok then
        warn(("[NierUI] привязка %s: %s"):format(self:Title(), tostring(err)))
        return
    end
    if self.owns then self.core:notify(self, "state") end
end

-- СОСТОЯНИЕ ПОМЕНЯЛОСЬ МИМО ПРИВЯЗКИ -- ХОЗЯИН ГОВОРИТ ОБ ЭТОМ САМ.
--
--     spear.watchTarget(function() bind:Sync() end)
--
-- Значение сюда не передаётся и не нужно: хранить его тут нечего, а спросить
-- есть у кого. Sync -- это «правда изменилась, перечитайте», а не «вот новая».
--
-- Есть только у привязки с State, и это не придирка. У остальных о смене
-- сообщает тот, кто состояние хранит: строка -- через NierUI.stateChanged, своё
-- -- само ядро в Set. Разреши мы Sync им, одна смена слала бы два уведомления,
-- и правило «хозяин всегда один» держалось бы на честном слове вызывающего.
--
-- Без этого экран отстаёт ровно там, где отставать больнее всего: цель умерла,
-- захвата нет, а в списке горит [ON] -- до следующего нажатия чего угодно.
function Bind.Sync(self)
    if not self.external then
        error("[NierUI] Sync есть только у привязки, чьё состояние живёт "
            .. "снаружи (State): у остальных о смене сообщает тот, кто её "
            .. "хранит, -- строка или само ядро", 2)
    end
    self.core:notify(self, "state")
end

-- ВОРОТА ЗАКРЫЛИСЬ -- ГАСИМ БЕЗУСЛОВНО.
--
-- Не «перестаём слушать», а именно гасим: человек выключил функцию целиком, и
-- оставшееся включённым взаимодействие с ней -- это включённое, до которого
-- больше не дотянуться. Возврата тоже нет: открыли ворота обратно -- привязка
-- осталась в OFF, потому что включал её человек клавишей, а не строкой.
function Bind.Shut(self)
    if self.held then
        self.held = false
        self.core:notify(self, "held")
    end
    if self.set and self:Get() then self:Set(false) end
end

-- Выполнить действие, как будто нажали клавишу. Есть только у привязки без
-- состояния: у той, у которой оно есть, для этого есть Set -- второго способа
-- сделать то же самое заводить незачем.
function Bind.Fire(self)
    if not self.fire then
        error("[NierUI] Fire есть только у привязки-действия; "
            .. "у привязки с состоянием -- Set", 2)
    end
    local ok, err = pcall(self.fire)
    if not ok then
        warn(("[NierUI] привязка %s: %s"):format(self:Title(), tostring(err)))
    end
end

--=============================================================================
-- СБРОС -- СТЕРЕТЬ НАСТРОЙКИ, А НЕ САМУ ВОЗМОЖНОСТЬ
--=============================================================================
--
-- Снимает клавишу, своё имя, свой режим и скрытие -- привязка пропадает из
-- списка на экране, потому что нажимать в ней больше нечего, и назначается
-- заново с нуля там же, в менеджере.
--
-- ЭТО НЕ Destroy, И РАЗНИЦА ПРИНЦИПИАЛЬНАЯ. Здесь сперва стоял именно он, и
-- это была ошибка: запись заводит скриптер при постройке меню, и снесённая не
-- появлялась обратно ничем, кроме перезапуска. То есть «убрать привязку»
-- убирало САМУ ВОЗМОЖНОСТЬ привязать -- фича оставалась, а дотянуться до неё
-- клавишей было уже нельзя.
--
-- Destroy остаётся в API: он для скрипта, который убирает фичу целиком. Человеку
-- за меню он не предлагается нигде -- у него нет способа вернуть убранное.
function Bind.Reset(self)
    -- Клавишу снимает сам SetMade: «не создана» и «слушает клавишу» -- не
    -- сочетаются, и держать это правило в двух местах значит однажды его
    -- разъединить.
    self:SetMade(false)
    self:SetKey(nil)
    self:SetTitle(nil)
    -- У действия режима нет -- и трогать его нечем.
    if self.kind ~= "action" and self.kind ~= self.kind0 then
        self:SetKind(self.kind0)
    end
    self:SetShown(true)
end

function Bind.Destroy(self)
    local core = self.core
    unhold(self)

    unindex(core, self)
    if self.name then core.byName[self.name] = nil end
    drop(core.list, self)
    core:notify(nil, "removed")
end

--=============================================================================
-- ОЖИДАНИЕ НАЖАТИЯ -- ЗДЕСЬ И ТОЛЬКО ЗДЕСЬ
--=============================================================================
--
--     local cancel = bind:Capture(function(key) ... end)   -- key = nil -- сняли
--
-- Копий этого танца в библиотеке было две -- в виджете Keybind и в окне
-- настроек, -- и они успели разойтись: вторая принимала только Enum.KeyCode и
-- не умела снимать привязку вовсе. Третьей копией стал бы любой сторонний
-- менеджер. Поэтому примитив, а не приём.
--
--     любая клавиша, правая или средняя мыши -- назначить
--     Escape                                 -- отменить, оставить как было
--     Backspace                              -- снять привязку совсем
--
--
-- ЖДУЩИЙ ВСЕГДА ОДИН, И ЭТО ИСПРАВЛЕНИЕ, А НЕ УДОБСТВО.
--
-- Раньше каждая строка ждала сама по себе и о соседях не знала. Щёлкнул одну,
-- передумал, щёлкнул другую -- ждут обе, и одно нажатие назначалось ОБЕИМ.
-- Ловилось это только глазами и выглядело как «клавиша сама себя куда-то ещё
-- прописала».

function Core.Capture(self, done)
    -- Новое ожидание ОТМЕНЯЕТ прежнее, а не встаёт вторым.
    if self.pending then pcall(self.pending) end

    self.grab = self.grab + 1

    local finished = false
    local conn = false

    local function stop()
        if finished then return end
        finished = true

        if conn then
            conn:Disconnect()
            conn = false
        end
        if self.pending == stop then self.pending = false end

        -- ОТПУСКАЕМ СО СЛЕДУЮЩЕГО КАДРА. То же самое нажатие ещё расходится по
        -- остальным подписчикам, и снятый прямо здесь признак они прочли бы уже
        -- снятым -- то есть ровно та гонка, ради которой он и заведён. Порядок
        -- обработчиков в Roblox не определён, расстановкой подписок не решается.
        task.defer(function()
            self.grab = math.max(0, self.grab - 1)
        end)
    end

    self.pending = stop

    conn = UserInputService.InputBegan:Connect(function(input)
        local code = codeOf(input)
        if not code then return end

        stop()

        -- Escape отменяет назначение, а не назначает Escape.
        if code == Enum.KeyCode.Escape then return end

        -- ЧЕРЕЗ if, А НЕ ЧЕРЕЗ and/or.
        --
        -- Здесь стояло `done(cleared and nil or code)` -- и Backspace назначал
        -- сам себя вместо того, чтобы снять привязку: `X and nil` даёт nil, а
        -- `nil or code` возвращает code обратно. Ровно та же ловушка, на
        -- которой библиотека уже горела в GetSetting у списка, только зеркальная.
        local assigned = code
        if code == Enum.KeyCode.Backspace then assigned = nil end

        -- НАЗНАЧЕНИЕ ВСТУПАЕТ В СИЛУ СО СЛЕДУЮЩЕГО КАДРА: нажатие, которым
        -- клавишу назначают, ещё идёт по подписчикам, и настроенная прямо здесь
        -- привязка сработала бы от него же.
        task.defer(function()
            done(assigned)
        end)
    end)

    return stop
end

function Bind.Capture(self, fn)
    return self.core:Capture(function(key)
        self:SetKey(key)
        if fn then pcall(fn, key) end
    end)
end

--=============================================================================
-- РЕДАКТОРЫ ПРИВЯЗКИ -- ТО, ЧТО ЯДРО КЛАДЁТ В МЕНЮ СТРОКИ САМО
--=============================================================================
--
-- Объявил Bind -- получил и клавишу, и режим, ничего для этого не написав.
-- Строит их ядро, а не виджет: набор редакторов -- это свойство привязки, и
-- повторять его в каждом виджете значит однажды забыть очередной.
--
-- Подписи здесь НЕТ намеренно, хотя менять её человек тоже вправе. В меню
-- строки она видна и так -- переименовывать её там незачем; нужно это в общем
-- списке, где строк много и они из разных вкладок. Там же и стоит.
--=============================================================================
-- У СТРОКИ КЛАВИШИ ДВЕ РЕАКЦИИ, И ЭТО РАЗДЕЛЕНИЕ, А НЕ ПЕРЕГРУЗКА
--=============================================================================
--
--     левая    назначить клавишу
--     правая   настройки ЭТОЙ привязки: как её зовут и как она срабатывает
--
-- Сперва режим и имя стояли соседними строками в том же меню. На одной привязке
-- это выглядело сносно, на трёх -- девять строк подряд, из которых половина
-- «ИМЯ», и понять, чьё именно, можно только по счёту сверху.
--
-- Настройки привязки к КЛАВИШЕ и не относятся: клавиша -- это чем вызвать, а
-- режим и подпись -- про саму привязку. Разные вещи -- разные нажатия.

function NierUI.bindRows(container, binds)
    -- Одна привязка на строке -- она и есть эта строка, подписи ей хватит
    -- общей. Несколько -- каждая называет себя сама, иначе из трёх подряд
    -- идущих КЛАВИША не понять, чью правишь.
    local one = #binds == 1
    for _, bind in ipairs(binds) do
        container:Keybind({
            Text = one and "КЛАВИША" or (bind.given or bind:Title()),
            Desc = "Левая -- назначить клавишу. Правая -- режим и имя.",
            bind = bind,
        })
    end
end

--=============================================================================
-- СЛЕДИТЬ ЗА ОДНОЙ ПРИВЯЗКОЙ -- ПРИМИТИВ, А НЕ ПРИЁМ
--=============================================================================
--
-- Всякий редактор привязки показывает то, что правится и НЕ ЗДЕСЬ тоже: клавишу
-- меняют из менеджера, режим -- из меню строки, подпись -- загрузкой профиля, и
-- любое из трёх ещё и вызовом из кода. Ничего не кешируем -- перерисовываемся
-- по поводу, а повод один на все источники, потому что источник правды один.
--
-- Разбор повода везде выходил дословно один и тот же -- «не моё событие --
-- мимо; не моя привязка -- мимо; nil значит всех» -- плюс укладка снятия в сток
-- контейнера. Копий набралось три: режим и имя здесь, клавиша в виджете
-- Keybind. Средняя строка в них самая коварная: забудешь `changed ~= nil` --
-- и вид перестанет обновляться на общих пересборках, забудешь `changed ~= bind`
-- -- и каждая строка станет перерисовываться от чужих правок.
--
-- Снятие уезжает в сток КОНТЕЙНЕРА, а не окна: меню правой кнопки и список
-- менеджера пересобираются, и подписка снесённого редактора иначе осталась бы в
-- ядре навсегда, держа за собой уничтоженные объекты (см. NierUI.sink).
function NierUI.bindWatch(container, bind, what, fn)
    local unwatch = bind.core:Changed(function(changed, event)
        if event ~= what then return end
        if changed ~= nil and changed ~= bind then return end
        fn()
    end)
    table.insert(NierUI.sink(container), { Disconnect = unwatch })
    return unwatch
end

-- Что открывается по правой кнопке у строки клавиши. Здесь, а не в виджете:
-- набор настроек -- свойство ПРИВЯЗКИ, и виджет о нём знать не должен.
--
-- manage -- строка МЕНЕДЖЕРА, а не строка меню. Разница в правах, и она
-- намеренная: в меню строки человек видит то, что ему оставил скриптер, а
-- менеджер -- высшая инстанция и разрешает всё, что привязка вообще умеет.
function NierUI.bindOptions(container, bind, manage)
    -- РЕЖИМ.
    --
    -- В МЕНЮ СТРОКИ -- только если скриптер разрешил: не разрешил, значит
    -- строки нет вовсе. Серая строка, по которой нельзя щёлкнуть, обещает
    -- настройку, которой не будет, и объяснить это человеку нечем.
    --
    -- В МЕНЕДЖЕРЕ -- всегда, чьё бы это ни было решение. Скриптер знает свою
    -- фичу, но не знает, как человеку удобнее её вызывать, и последнее слово
    -- тут не за ним.
    --
    -- КРОМЕ ДЕЙСТВИЯ, и это не полномочия, а физика: у него нет состояния,
    -- удерживать нечего и переключать нечего. Высшая инстанция тоже не может
    -- разрешить то, чего не существует.
    if bind:Kind() ~= "action" and (manage or bind:CanChangeMode()) then
        local mode = container:Segmented({
            Text = "РЕЖИМ", Options = { "ПЕРЕКЛ.", "ЗАЖАТИЕ" },
            Default = bind:Kind() == "hold" and "ЗАЖАТИЕ" or "ПЕРЕКЛ.",
            Desc = "ПЕРЕКЛ. -- нажал и отпустил. ЗАЖАТИЕ -- пока держишь.",
            -- Без Flag: режим уходит в профиль вместе с самой привязкой, а не
            -- отдельным значением. Два хозяина у одного факта -- и при загрузке
            -- побеждает тот, кого профиль применил последним.
            Callback = function(value)
                bind:SetKind(value == "ЗАЖАТИЕ" and "hold" or "toggle")
            end,
        })

        -- Режим могли сменить НЕ ЗДЕСЬ, и это не редкость, а обычный ход дел: у
        -- одной привязки таких выключателей два -- в меню её строки и в
        -- менеджере, -- плюс загрузка профиля и SetKind из кода. Без слежения
        -- второй показывал бы прежнее значение до перезапуска, а щелчок по нему
        -- возвращал бы режим назад, ничего об этом не сказав.
        NierUI.bindWatch(container, bind, "kind", function()
            mode:Set(bind:Kind() == "hold" and "ЗАЖАТИЕ" or "ПЕРЕКЛ.", true)
        end)
    end

    --== ИМЯ =================================================================
    --
    -- Личность привязки не меняется: она в Flag, а подпись -- то, как её зовут
    -- в списке. Ровно поэтому её и можно трогать.
    --
    -- Пустое поле ВОЗВРАЩАЕТ подпись, которую дал скриптер, -- она же стоит
    -- подсказкой. Иначе «вернуть как было» делалось бы перезапуском.
    local name = container:InputText({
        Text = "ИМЯ",
        Default = bind.titled or "",
        Placeholder = bind.given or bind.rowTitle or "",
        MaxLength = 24,
        -- По завершении ввода, а не на каждую букву: иначе список привязок
        -- перерисовывался бы на каждое нажатие клавиши.
        Callback = function(text) bind:SetTitle(text) end,
    })

    -- Подпись могли сменить не здесь: загрузкой профиля, вызовом SetTitle из
    -- кода, менеджером привязок.
    NierUI.bindWatch(container, bind, "title", function()
        name:Set(bind.titled or "", true)
    end)

    --== ДАЛЬШЕ -- ТОЛЬКО ИЗ МЕНЕДЖЕРА =======================================
    --
    -- Показ в списке и снятие привязки -- решения ПРО СВОЙ ЭКРАН и про свой
    -- набор клавиш, а не про фичу. Скриптеру их не выдано вовсе, и в меню
    -- строки их нет: там человек распоряжается тем, что ему оставили.
    if not manage then return end

    container:Divider()

    container:Toggle({
        Text = "В СПИСКЕ", Default = bind:Shown(),
        Desc = "Показывать ли эту привязку в списке на экране.",
        Callback = function(on) bind:SetShown(on) end,
    })

    container:Button({
        Text = "СНЕСТИ", Value = "X",
        Desc = "Снять клавишу и все настройки. Привязка пропадёт из списка, "
            .. "назначить заново можно здесь же.",
        Callback = function()
            -- СПРАШИВАЕМ, хотя это и обратимо: назначить заново можно, а вот
            -- подобранную клавишу, своё имя и режим человек восстанавливает
            -- руками. Терять их промахом мыши обидно.
            container.window:Confirm({
                Title = "СНЕСТИ ПРИВЯЗКУ",
                Text = ("Снять клавишу и настройки «%s»? Назначить заново "
                    .. "можно будет здесь же."):format(bind:Title()),
                Confirm = "ДА", Cancel = "НЕТ",
                -- Reset, а НЕ Destroy: снести надо настройки, а не саму
                -- возможность привязать. См. Bind.Reset.
                OnConfirm = function() bind:Reset() end,
            })
        end,
    })
end

--=============================================================================
-- МЕНЕДЖЕР ПРИВЯЗОК
--=============================================================================
--
--     system:Binds()
--
-- Строка, по которой ВЫПАДАЕТ окно со всеми привязками сразу: назначить
-- клавишу, сменить режим, переименовать, убрать из списка, снести совсем.
-- Страницей во вкладке это быть не может -- привязок бывает три десятка, и
-- вкладку они вытеснили бы целиком.
--
-- МЕНЕДЖЕР -- ВЫСШАЯ ИНСТАНЦИЯ, и это его определение, а не оговорка.
--
-- В меню строки человек распоряжается тем, что ему оставил скриптер: режим
-- меняется, только если тот разрешил (ChangeModeInGame). Здесь -- всем, что
-- привязка вообще умеет. Скриптер знает свою фичу, но не знает, как человеку
-- удобнее её вызывать и что ему держать на экране, и последнее слово не за ним.
--
-- Не отменяет это ровно одного -- физики. У действия нет состояния, и режима у
-- него не появится ни по чьему разрешению: удерживать нечего.
--
-- НАПИСАН ТЕМИ ЖЕ ПРИМИТИВАМИ, ЧТО ОТКРЫТЫ НАРУЖУ: All(), Changed() и виджет
-- Keybind с готовой записью. Сторонний менеджер пишется ровно так же, и это не
-- обещание, а проверка: не хватит чего-то ему -- не хватит и встроенному,
-- потому что сверх публичного он не использует ничего.
--
-- СОБИРАЕТСЯ ОТЛОЖЕННО. Окно возвращается пустым, вкладки и строки вызывающий
-- добавляет следом, и на момент объявления менеджера привязок нет ещё ни одной.
-- window.deferred ждёт ровно до конца постройки -- без опроса и без таймера.

-- `or {}`, а не пустая таблица, и по той же причине, что в Window: ядро
-- привязок собирается РАНЬШЕ окна (см. build.ps1), поэтому таблицу заводит вот
-- эта строка, а окно её потом подхватывает. Присвоение пустой с любой из сторон
-- затирало бы чужие методы молча -- метод не находился бы при том, что файл на
-- месте. Разбор целиком -- у объявления в Window.
NierUI.containerMethods = NierUI.containerMethods or {}

function NierUI.containerMethods.Binds(self, opts)
    opts = opts or {}
    local window = self.window

    local row, _, value, _, setHeld, rowApi = NierUI.makeRow(
        self, opts.Text or "ПРИВЯЗКИ",
        opts.Desc or "Все привязки разом. ЛКМ -- клавиша, ПКМ -- всё остальное.",
        nil, opts)

    -- Содержимое живёт на стоянке и переезжает в окно при открытии -- как у
    -- любого меню правой кнопки (см. Panel). Пересоздавать его на каждое
    -- открытие значило бы заводить заново все подписки строк.
    local panel = NierUI.panel(window, { Width = opts.Width or 260 })
    local U = NierUI.util

    --== ДВА КУСКА СТРАНИЦЫ ==================================================
    --
    -- Верхний строится ОДИН раз -- в нём добавление. Нижний пересобирается на
    -- каждое изменение реестра. Складывать их вместе нельзя: пересборка сносила
    -- бы и список выбора, а его подписки живут в собственном стоке виджета и с
    -- уничтожением кадров не гаснут -- то есть текли бы на каждую правку.
    local head = U.new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1,
    }, panel.page)
    U.new("UIListLayout", {
        Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
    }, head)

    local body = U.new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2,
    }, panel.page)
    U.new("UIListLayout", {
        Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
    }, body)

    local top = NierUI.makeSub(panel, head)

    -- У СПИСКА СВОЙ СТОК ПОДПИСОК, А НЕ ПАНЕЛЬНЫЙ.
    --
    -- Он пересобирается на каждую правку реестра, и каждая его строка кладёт
    -- туда свои подписки -- наведение, уход, нажатие, слежение за клавишей.
    -- Панельный сток не укорачивается никогда, поэтому при общем стоке они
    -- копились бы на каждую пересборку вместе со ссылками на уничтоженные
    -- строки. Ровно та беда, ради которой у контейнера вообще завёлся свой сток
    -- (см. NierUI.sink), только на этот раз внутри одного контейнера.
    --
    -- Подсовываем makeSub заглушку вместо родителя: ему нужны от него только
    -- окно, сток и владелец.
    local listConns = {}
    local list = NierUI.makeSub(
        { window = window, conns = listConns, owner = false }, body)
    local listed = {}

    -- ЧТО МОЖНО ПРИВЯЗАТЬ -- то, у чего клавиши ещё нет. Список считается
    -- заново при каждом показе: привязку могли снести или назначить не отсюда.
    local function free()
        local out = {}
        for _, bind in ipairs(window.binds:All()) do
            if not bind:Made() then
                out[#out + 1] = { Text = bind:Title(), Key = bind }
            end
        end
        return out
    end

    local function clear()
        for _, entry in ipairs(listed) do
            -- Меню строки живёт на стоянке в gui, а не внутри неё: уничтожение
            -- строки его не заберёт, и на каждой пересборке они копились бы.
            -- pcall без замыкания: пересборка идёт на каждую правку реестра, и
            -- новая функция на каждую строку тут ни к чему. См. NierUI.drain.
            if entry.handle.menu then
                pcall(entry.handle.menu.Destroy, entry.handle.menu)
            end
        end
        table.clear(listed)

        for _, child in ipairs(body:GetChildren()) do
            if child:IsA("GuiObject") then
                -- Цель правой кнопки снимается ВМЕСТЕ со строкой: реестр иначе
                -- рос бы на каждую пересборку.
                NierUI.contextForget(window, child)
                child:Destroy()
            end
        end

        -- И подписки снесённых строк -- туда же. Объекты уничтожены, а подписки
        -- на них живут в стоке своей жизнью и держат их за собой.
        NierUI.drain(listConns)

        list.rows = 0
    end

    local adder

    local function build()
        clear()

        -- ЗДЕСЬ ТОЛЬКО СОЗДАННЫЕ. Остальное -- не привязки, а возможности, и
        -- лежат они в ДОБАВИТЬ. Раньше показывалось всё, что объявил скриптер,
        -- и снесённая привязка оставалась висеть в списке, хотя нажимать в ней
        -- было уже нечего.
        local made = {}
        for _, bind in ipairs(window.binds:All()) do
            if bind:Made() then made[#made + 1] = bind end
        end

        value.Text = ("%d"):format(#made)
        if adder then adder:Refresh(free()) end

        if #made == 0 then
            list:Label({ Text = opts.Empty or "привязок нет" })
            return
        end

        for _, bind in ipairs(made) do
            listed[#listed + 1] = {
                bind = bind,
                -- manage -- те самые абсолютные права, см. bindOptions.
                handle = list:Keybind({
                    Text = bind:Title(), bind = bind, manage = true,
                }),
            }
        end
    end

    --== ДОБАВИТЬ ============================================================
    --
    -- ЩЁЛКНУЛ ФУНКЦИЮ -- ПРИВЯЗКА СОЗДАНА. Без клавиши, без вопросов, без
    -- второго шага: она просто появляется в списке ниже, а клавиша, режим и имя
    -- настраиваются уже там -- левой и правой кнопкой по её строке.
    --
    -- Сперва добавление сразу ждало нажатие клавиши. Понять это было нельзя
    -- ничем: список закрывался, меню молча ждало, и человек не знал ни что
    -- произошло, ни чего от него хотят. Одно действие -- один понятный
    -- результат, а настройка идёт отдельно и там, где её видно.
    --
    -- Default = false, а не nil: список без указанного выбора отмечает первый
    -- пункт сам, и строка выглядела бы так, будто функция уже выбрана.
    adder = top:Dropdown({
        Text = "ДОБАВИТЬ", Default = false, Options = free(), Search = true,
        Desc = "Что ещё можно привязать. Щёлкни -- появится в списке ниже.",
        Callback = function(bind)
            if type(bind) ~= "table" or not bind.SetMade then return end
            bind:SetMade(true)
        end,
    })
    top:Divider()

    -- Состав реестра меняется -- пересобираем; переименовали -- правим подпись
    -- НА МЕСТЕ. Пересборка ради одной подписи захлопнула бы меню под руками у
    -- того, кто прямо сейчас в нём и печатает это самое имя.
    -- Состав списка решает «создана», поэтому пересобираемся и на неё: добавили
    -- -- появилась, снесли -- ушла обратно в ДОБАВИТЬ.
    local unwatch = window.binds:Changed(function(bind, what)
        if what == "added" or what == "removed" or what == "made" then
            build()
        elseif what == "title" then
            for _, entry in ipairs(listed) do
                if bind == nil or entry.bind == bind then
                    entry.handle:SetText(entry.bind:Title())
                end
            end
        end
    end)

    -- Снос менеджера снимает и слежение, и подписки его строк. Ядро переживает
    -- отдельную панель: снесли её одну -- подписка осталась бы и пересобирала
    -- уничтоженный список на каждую правку привязок.
    panel:OnDestroy(function()
        unwatch()
        clear()
    end)

    local open = false
    NierUI.connect(self, row.MouseButton1Click, rowApi.gate(function()
        if open then
            panel:Close()
            return
        end
        open = true
        setHeld(true)
        panel:Open({
            Anchor = row, Title = opts.Title or "ПРИВЯЗКИ",
            Place = "binds\0" .. U.randomName(),
            OnClose = function()
                open = false
                setHeld(false)
            end,
        })
    end))

    table.insert(window.deferred, build)
    return panel
end

--=============================================================================
-- «СЕЙЧАС ЖДУТ НАЖАТИЕ» -- для тех, кто слушает клавиатуру мимо привязок
--=============================================================================
--
-- Спрашивают перед тем, как что-то делать: клавиша открытия меню (см. Window) и
-- сторож Escape у всплывающих окон (см. Popup). Пока ждут, нажатие принадлежит
-- ждущему и больше никому.
--
-- Взводить признак отдельно больше нечем и незачем: сюда вело NierUI.keyGrab,
-- парное к нему, и обоих его вызывающих -- виджет Keybind и окно настроек --
-- заменил Capture, который взводит признак сам. Оставленная «на всякий случай»
-- вторая дверь в захват клавиатуры -- ровно тот способ однажды получить
-- взведённый навсегда счётчик, ради отсутствия которого всё и переносилось.

-- Ядра может не быть вовсе: конструктор окна ставит его строкой ПОСЛЕ
-- setmetatable, и до неё в поле лежит false. Читаем rawget'ом и отсутствие
-- переносим -- «никто не ждёт» правдивый ответ и для окна на полпути к жизни.
function NierUI.keyGrabbed(window)
    local core = window and rawget(window, "binds")
    if not core then return false end
    return core.grab > 0
end

end)(NierUI)

--============================ NierUI/Window.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Window -- окно, вкладки и реестр виджетов
--=============================================================================
--
-- ЗДЕСЬ НЕТ НИ ОДНОГО ЦИКЛА И НИ ОДНОГО task.spawn. Всё на событиях, анимация
-- на TweenService. Каждый коннект пишется в window.conns, Destroy гасит все и
-- уничтожает ScreenGui -- после него не остаётся ничего.
--
-- Это прямой ответ на то, чем болел CompKiller: одиннадцать вечных
-- `while true do task.wait() end` переживали снос интерфейса, и каждая
-- пересборка добавляла около тринадцати тысяч таблиц и двух с половиной тысяч
-- функций, а один из потоков создавал Tween каждый кадр -- по разу на каждый
-- мёртвый экземпляр.

local UserInputService = game:GetService("UserInputService")

local THEME = NierUI.Theme
local U = NierUI.util

--=============================================================================
-- Реестр виджетов
--=============================================================================
--
-- Файл виджета вызывает NierUI.widget("Toggle", builder), и метод tab:Toggle()
-- появляется сам. Добавление элемента -- это ровно один новый файл, ничего
-- редактировать не нужно.

NierUI.widgets = {}

function NierUI.widget(name, builder)
    NierUI.widgets[name] = builder
end

--=============================================================================
-- ПРИВЯЗКА К КОНФИГУ
--=============================================================================
--
-- Виджет с полем Flag попадает в реестр окна и начинает сохраняться. Без
-- Flag он остаётся безымянным и в конфиг не идёт -- разметку и кнопки хранить
-- незачем.
--
-- Реестр держит ИМЕННО handle виджета, а не значение: сохранение спрашивает
-- Get, загрузка зовёт Set. Значит любой новый виджет становится сохраняемым
-- сам по себе, если умеет эту пару, и ничего дописывать в кодек не нужно.
--
-- Повторный Flag -- ошибка, а не тихая замена: два элемента под одним именем
-- значат, что один затрёт другой при загрузке, а найти это потом почти нечем.

--=============================================================================
-- ИМЯ И СОХРАНЕНИЕ -- РАЗНЫЕ ВЕЩИ
--=============================================================================
--
-- Сперва Flag делал две работы разом: служил именем для поиска
-- (win.flags.profileName:Get()) и одновременно означал «сохраняй меня». Развести
-- их было нечем, и получались нелепости: поле с именем профиля попадало в
-- каждый профиль, счётчик нажатий ехал в набор настроек.
--
-- Теперь Flag -- это только ИМЯ. Сохранением управляет Save:
--
--     Flag = "walkSpeed"                  именуется и сохраняется
--     Flag = "clickCount", Save = false    именуется, но в профиль не идёт
--     без Flag                             ни того, ни другого
--
-- Умолчание -- сохранять: настроек в меню несравнимо больше, чем счётчиков.
--
--
--=============================================================================
-- НАСТРОЙКА И КОМАНДА -- ТОЖЕ РАЗНЫЕ ВЕЩИ
--=============================================================================
--
--     Flag = "mask", Apply = false        значение помнится, но при загрузке
--                                         профиля обратный вызов НЕ зовётся
--
-- Загрузка профиля намеренно зовёт обратные вызовы: профиль должен
-- ПРИМЕНЯТЬСЯ, а не только отображаться (см. Config). Для настройки это верно
-- всегда -- скорость, цвет, радиус живут ровно в том значении, которое видно.
--
-- Но иногда за строкой стоит не настройка, а КОМАНДА, и её значение -- выбор
-- «что сделать, когда попросят», а не «как сейчас есть». Такую строку загрузка
-- профиля выполнять не должна: человек выбирал маску, а не просил надевать её
-- при каждом запуске. Замерено на живом хабе: подъём мастер-профиля надевал
-- маску сам, до единого щелчка, потому что выбор и действие были одним и тем же.
--
-- Отличить одно от другого может только тот, кто строку объявил: снаружи и
-- команда, и настройка выглядят одинаково -- значение и обратный вызов.
--
-- Save и Apply независимы. Save = false -- «не помни»; Apply = false -- «помни,
-- но не выполняй». Умолчание у обоих -- да: настроек несравнимо больше.

function NierUI.bindFlag(window, flag, handle, level, save, apply)
    if not flag or not handle then return handle end
    if window.flags[flag] then
        error(("[NierUI] Flag «%s» уже занят другим элементом"):format(tostring(flag)),
            level or 3)
    end
    window.flags[flag] = handle
    if save == false then window.noSave[flag] = true end
    if apply == false then window.noApply[flag] = true end
    return handle
end

function NierUI.bind(container, opts, handle)
    if not opts then return handle end
    return NierUI.bindFlag(container.window, opts.Flag, handle, 4,
        opts.Save, opts.Apply)
end

--=============================================================================

local Window = {}
Window.__index = Window

-- Класс отдаётся наружу под ОТДЕЛЬНЫМ именем: NierUI.Window -- это
-- конструктор, вызываемый через двоеточие, и положить туда же таблицу класса
-- значило бы сломать сам вызов.
NierUI.WindowClass = Window

local Tab = {}

--=============================================================================
-- КОНТЕЙНЕР
--=============================================================================
--
-- Виджеты НЕ ЗНАЮТ, что такое вкладка. Каждый работает с чем угодно, у чего
-- есть .page (куда класть строки), .rows (счётчик порядка) и .window (куда
-- складывать коннекты). Вкладка -- контейнер, блок -- тоже контейнер, и это
-- единственная причина, по которой блоки не потребовали править ни один
-- виджет.
--
-- На неизвестное имя ругаемся ВНЯТНО. Молчаливый nil давал «attempt to call a
-- nil value» без намёка, где именно опечатка, -- а имена виджетов строковые.

-- Методы, общие для всех контейнеров: секции, колонки и прочее, что не
-- является ни виджетом, ни особенностью вкладки или блока. Лежат отдельно,
-- чтобы не дублировать их в каждом классе контейнера.
-- `or {}`, а не пустая таблица: методы сюда кладут и части, загруженные РАНЬШЕ
-- окна (ядро привязок с его менеджером). Присвоение пустой затирало бы их
-- молча, и метод просто не находился бы -- при том, что файл на месте.
NierUI.containerMethods = NierUI.containerMethods or {}

--=============================================================================
-- СТОК КОННЕКТОВ -- У КОНТЕЙНЕРА, А НЕ У ОКНА
--=============================================================================
--
-- Виджеты писали подписки прямо в window.conns. Для вкладки это верно: она
-- живёт столько же, сколько окно, и гаснет вместе с ним в Destroy.
--
-- Но список этот НИКОГДА НЕ УКОРАЧИВАЕТСЯ, и стоит контейнеру стать временным,
-- как это перестаёт быть верным. Список пунктов уже наступил на это
-- однажды: он пересобирается на каждое изменение источника, и его подписки
-- пришлось уводить в собственный itemConns -- вручную, отдельным механизмом,
-- потому что общего не было.
--
-- Меню правой кнопки наступит на это второй раз и куда сильнее: ползунок кладёт
-- туда три подписки, палитра две, и каждое открытие меню добавляло бы их
-- заново, навсегда, вместе со ссылками на уничтоженные объекты.
--
-- Поэтому у контейнера есть свой сток. Нет своего -- берётся у окна, и для
-- вкладки, блока и секции ничего не меняется. Появился временный контейнер --
-- он заводит свой список и гасит его при закрытии, а виджеты об этом не знают
-- вовсе: они и так не знают, куда их кладут.

function NierUI.sink(container)
    return container.conns or container.window.conns
end

function NierUI.connect(container, signal, fn)
    local conn = signal:Connect(fn)
    table.insert(NierUI.sink(container), conn)
    return conn
end

-- ПОГАСИТЬ СТОК И ОПУСТОШИТЬ ЕГО.
--
-- Приём один и тот же везде, где сток кончается: снос окна, снос панели,
-- пересборка списка, смена набора пунктов. Копий этого цикла набралось семь, и
-- в каждой один и тот же pcall -- подписка на уничтоженный объект отвечает
-- ошибкой, а погасить надо ОСТАЛЬНЫЕ, а не бросить их на половине списка.
--
-- В стоке лежат не только Connection: снятие подписки ядра привязок кладётся
-- сюда же таблицей { Disconnect = unwatch }. Утиная типизация здесь не
-- вольность, а условие -- сток обязан гасить всё, что умеет гаснуть.
--
-- pcall БЕЗ ЗАМЫКАНИЯ. Привычное `pcall(function() conn:Disconnect() end)`
-- заводит новую функцию на КАЖДУЮ подписку, а самые частые стоки тут -- список
-- пунктов и меню привязок, которые пересобираются на каждую букву в поиске и на
-- каждую правку реестра. `pcall(conn.Disconnect, conn)` делает ровно то же
-- самое: вызов через двоеточие и есть передача себя первым аргументом.
function NierUI.drain(list)
    for _, conn in ipairs(list) do
        pcall(conn.Disconnect, conn)
    end
    table.clear(list)
end

--=============================================================================
-- ЗАХВАТ КЛАВИШИ переехал в ядро привязок (см. Binds).
--=============================================================================
--
-- Спрашивают его именно привязки, и второго счётчика на это быть не должно:
-- NierUI.keyGrabbed объявлен там же, где живёт сам счётчик. Парного ему
-- «взвести снаружи» больше нет вовсе -- взводит его Capture и только он.

--=============================================================================
-- «У МЕНЯ ИЗМЕНИЛОСЬ» -- СООБЩАЕТ ТОТ, У КОГО ИЗМЕНИЛОСЬ, И КАНАЛ ОДИН
--=============================================================================
--
-- Список привязок показывает чужое состояние: включён ли тумблер, которому
-- принадлежит клавиша. Узнать о его смене можно двумя способами, и один из них
-- негодный.
--
-- Негодный -- спрашивать по таймеру. Он был здесь написан, и это прямое
-- нарушение того, на чём стоит вся библиотека: ничего не работает, пока ничего
-- не происходит. Опрос работает ВСЕГДА, в том числе когда не меняется ничего,
-- и ради одной строки на экране заводит постоянную нагрузку.
--
-- Годный -- сообщать. Тумблер и так знает момент, когда его переключили: он
-- ровно там зовёт свой Callback. Пусть заодно скажет и окну.
--
-- Ядро привязок состоянием НЕ ВЛАДЕЕТ -- владеет тот, чью пару get/set ему
-- отдали, то есть строка меню. Значит и о смене состояния сообщает он же, вот
-- этим самым вызовом, которым и так сообщал.
--
-- КАНАЛ РОВНО ОДИН -- подписчики ядра. Рядом стоял второй, собственный список
-- наблюдателей окна (onStateChange/stateWatchers): его завели, когда список
-- привязок сидел на окне напрямую, а после переезда на ядро он остался ПУСТЫМ
-- -- ни одного подписчика на всю библиотеку. Вторая дверь к одному и тому же
-- уведомлению -- ровно тот способ однажды получить два сообщения об одной
-- смене и не суметь их различить. Понадобится наблюдатель за виджетом, а не за
-- привязкой, -- он подпишется на ядро, как все остальные.
--
-- bind = nil означает «поимённо не знаем, пересоберись».
function NierUI.stateChanged(window)
    if not window then return end

    local core = rawget(window, "binds")
    if core then core:notify(nil, "state") end
end

function NierUI.containerIndex(class)
    return function(self, key)
        local own = rawget(class, key)
        if own then return own end

        local shared = NierUI.containerMethods[key]
        if shared then return shared end

        local builder = NierUI.widgets[key]
        if builder then
            -- ЕДИНСТВЕННАЯ ВОРОНКА, ЧЕРЕЗ КОТОРУЮ ПРОХОДИТ КАЖДЫЙ ВИДЖЕТ.
            --
            -- Здесь и только здесь известны разом три вещи: имя виджета, его
            -- настройки и готовый handle. Поэтому пометки ставятся тут, а не в
            -- двадцати местах: новый виджет получает их просто потому, что он
            -- виджет.
            return function(_, opts)
                opts = opts or {}
                local handle = builder(self, opts)

                if type(handle) == "table" then
                    -- ПРИВЯЗКА ДАРОМ НЕ ДОСТАЁТСЯ, И МОЛЧАТЬ ОБ ЭТОМ НЕЛЬЗЯ.
                    --
                    -- Каркас строки читает Bind и Binds ровно для одного --
                    -- понять, что меню строит виджет сам (см. makeRow). Саму
                    -- запись заводит виджет: ядру нужна пара get/set до его
                    -- состояния, а что считать состоянием, знает только он.
                    --
                    -- Значит виджет, который эти поля не разбирает, получал бы
                    -- их МОЛЧА: привязки нет, в списке пусто, клавиша ничего не
                    -- делает -- и вдобавок пропало собственное меню строки,
                    -- потому что каркас решил, что виджет построит его сам.
                    --
                    -- Проверяем здесь: только тут известны разом и настройки, и
                    -- готовый handle. Признак -- поле binds: кто привязки
                    -- поддерживает, тот его выставляет всегда, пусть и пустым.
                    if (opts.Bind ~= nil or opts.Binds ~= nil)
                        and rawget(handle, "binds") == nil then
                        error(("[NierUI] %s не умеет привязок, а ему передали "
                            .. "Bind/Binds -- строка «%s». Их разбирают Toggle, "
                            .. "Button и Keybind; своему виджету заведите запись "
                            .. "сами через window.binds:Add и верните её в поле "
                            .. "binds."):format(key, tostring(opts.Text or "?")), 0)
                    end

                    -- kind нужен списку привязок, чтобы отличить Keybind от
                    -- всего остального, text -- чтобы было чем подписать строку.
                    if handle.kind == nil then handle.kind = key end
                    -- opts здесь ВСЕГДА таблица: воронка подставила пустую
                    -- строкой выше. Проверка типа стояла ещё от той поры, когда
                    -- подстановки не было, и с тех пор ни разу не сработала.
                    if handle.text == nil then handle.text = opts.Text end

                    -- МЕНЮ УЗНАЁТ СВОЕГО ВЛАДЕЛЬЦА ТОЛЬКО ЗДЕСЬ.
                    --
                    -- Строится оно внутри makeRow, то есть ДО того, как виджет
                    -- вернул handle: в тот момент владельца ещё не существует.
                    -- Знать его надо списку привязок -- клавиша, объявленная в
                    -- меню тумблера ПОЛЁТ, включена ровно тогда, когда включён
                    -- сам ПОЛЁТ.
                    local pending = rawget(self, "pendingMenu")
                    if pending then
                        pending.owner = handle
                        -- Ссылка на меню нужна и наружу: динамический список
                        -- пересобирает свои строки, и меню снесённой строки
                        -- надо снести вместе с ней -- иначе контейнеры меню
                        -- копились бы на окне без всякой связи с видимым.
                        handle.menu = pending
                        self.pendingMenu = false
                    end

                    -- НАСТРОЙКИ СТРОКИ -- ТОЖЕ ЗДЕСЬ, И ПО ТОЙ ЖЕ ПРИЧИНЕ.
                    --
                    -- Каркас строит их в makeRow, то есть ДО того, как виджет
                    -- вернул handle, а в профиль они уходят именно через него.
                    -- Раньше пару Get/SetSetting выписывал у себя переключатель
                    -- -- единственный, кто вообще звал настройки. Повторять это
                    -- в каждом виджете значит однажды забыть очередной, чем и
                    -- кончилось: у ползунка, палитры, списка и поля ввода поле
                    -- Settings не работало вовсе.
                    local extra = rawget(self, "pendingSettings")
                    if extra then
                        local state, onChange = extra.state, extra.onChange
                        self.pendingSettings = false

                        -- SettingsFlat: у строки уровень один, а у списка
                        -- настройки разложены по пунктам. См. Config.
                        handle.SettingsFlat = true
                        handle.SettingsMap = function() return state end
                        handle.GetSetting = function(_, field) return state[field] end
                        handle.SetSetting = function(_, field, value)
                            state[field] = value
                            -- Загрузка профиля обязана ПРИМЕНИТЬ настройку, а не
                            -- только запомнить: иначе меню показывает новое
                            -- значение, а работает старое.
                            if onChange then pcall(onChange, field, value) end
                        end
                    end
                end

                return handle
            end
        end

        -- Ругаться можно БЕЗУСЛОВНО, потому что контейнер не читает полей,
        -- которых у него нет: всё внутреннее состояние заводится при создании,
        -- отсутствие оси -- это false, а не nil.
        --
        -- Первая версия ругани ломала раскладку блоков ровно на этом: __index
        -- срабатывает на любое отсутствующее поле, а `if tab.grid then` до
        -- первого присваивания читало честный nil. Затыкать это проверкой «имя
        -- с большой буквы» значило бы держать соглашение об именах вместо
        -- инварианта. Инвариант надёжнее.
        local known = {}
        for name in pairs(NierUI.widgets) do known[#known + 1] = name end
        table.sort(known)
        error(("[NierUI] нет такого элемента: %s. Есть: %s")
            :format(tostring(key), table.concat(known, ", ")), 2)
    end
end

Tab.__index = NierUI.containerIndex(Tab)
NierUI.TabClass = Tab

--=============================================================================
-- Окно
--=============================================================================

function NierUI:Window(opts)
    opts = opts or {}

    -- Состояние заводится ЦЕЛИКОМ здесь. Ни одно поле не появляется по ходу
    -- дела: диспетчер контейнера ругается на любое отсутствующее, и «ещё не
    -- присвоено» от «опечатка» иначе не отличить.
    local self = setmetatable({
        tabs = {},
        conns = {},
        popups = {},
        -- ЯДРО ПРИВЯЗОК. Заводится пустым и подписок на ввод не создаёт, пока
        -- не объявлена первая привязка: у меню без них обработчиков ввода не
        -- появляется вовсе. Ставится ниже, сразу после setmetatable -- ядру
        -- нужно само окно, а его в этой таблице ещё нет.
        binds = false,
        -- Разбор нажатия правой кнопки один на всё окно, а не по подписке на
        -- каждый элемент: пока открыто всплывающее окно, его фон-перехватчик
        -- забирает правую кнопку себе и до элементов она не доходит. См.
        -- Context.
        m2 = {},
        popupInput = false,
        -- Контейнеры меню правой кнопки. Их содержимое живёт на стоянке в gui,
        -- а подписки -- в собственных стоках, до которых оконный Destroy сам не
        -- достаёт. Поэтому список: снять надо каждый.
        panels = {},
        -- Отложенное на конец постройки. Виджеты добавляются ПОСЛЕ того, как
        -- окно вернулось, поэтому всё, чему нужен полный их список -- менеджер
        -- привязок, мастер-профиль, -- ждёт здесь.
        deferred = {},
        -- Перехватчик щелчков ОДИН на всю стопку всплывающих окон, а не по
        -- одному на окно. См. Popup.
        popupShade = false,
        -- Где какое окно настроек стояло в прошлый раз. Живёт столько же,
        -- сколько окно, и в профиль не идёт: положение панели -- это привычка
        -- рук на один сеанс, а не настройка, которую хотят получить обратно
        -- через неделю на другом мониторе.
        popupPlaces = {},
        flags = {},
        noSave = {},
        -- Строки, которые загрузка профиля ставит МОЛЧА: значение поднимается,
        -- обратный вызов не зовётся. См. «настройка и команда» выше.
        noApply = {},
        notifyLayer = false,
        notifications = {},
        triggerSeq = 0,
        -- Папку конфигов задаёт ТОЛЬКО вызывающий. Выводить её из заголовка
        -- окна нельзя: заголовок меняется по вкусу, и каждая его правка
        -- оставляла бы на диске новую папку с осиротевшими профилями.
        configFolder = opts.ConfigFolder or false,

        -- МАСТЕР-ПРОФИЛЬ: какой набор настроек поднимать при каждом запуске.
        --
        -- false означает не «нет мастера», а «в коде не назван» -- тогда имя
        -- берётся из файла рядом с профилями, куда его кладёт SetMaster. Так
        -- назначить главный профиль можно из самого меню, не трогая скрипт.
        --
        -- AutoLoad = false выключает подъём целиком: он нужен тому, кто грузит
        -- профиль сам и в свой момент.
        master = opts.MasterProfile or false,
        autoMaster = opts.AutoLoad ~= false,

        -- Перехват ввода на время, пока меню открыто. По умолчанию включён:
        -- меню, по которому нельзя щёлкнуть в бою, бесполезно.
        captureInput = opts.CaptureInput ~= false,
        captured = false,
        -- Исходное состояние мыши хранится НЕ здесь, а на библиотеке, и
        -- снимается один раз за сеанс: копия на окно записывала бы не исходное
        -- значение, а следы предыдущего окна -- в том числе такого, которое
        -- умерло, не убравшись за собой. См. Capture.
        captureAction = false,
        -- Слежение за системным меню Roblox: пока оно открыто, поглотитель
        -- отпускается. См. Capture.
        captureMenu = false,

        -- Свой указатель вместо системного. См. Cursor: системный в бою не
        -- показывается, сколько его ни включай.
        drawCursor = opts.Cursor ~= false,
        cursor = false,
        cursorParts = false,
        cursorOn = false,
        cursorConns = false,
        current = false,
        -- Заводится ЗАКРЫТЫМ и открывается в конце конструктора через Toggle.
        --
        -- Раньше здесь стояло true, а Toggle не звался вовсе: окно оказывалось
        -- видимым, но БЕЗ перехвата ввода и без своего указателя -- и то и
        -- другое живёт только внутри Toggle. Курсора нет, щелчки уходят в игру,
        -- а первое нажатие клавиши открытия меню ПРЯЧЕТ. Проходить через один
        -- и тот же путь надёжнее, чем повторять его половину в конструкторе.
        visible = false,
        -- Точка последнего нажатия. MouseButton1Click координат не несёт, а
        -- отличать нажатие по строке от нажатия внутри её раскрытой панели
        -- необходимо: раскрытая панель лежит ВНУТРИ строки, и щелчок по
        -- палитре доходил до строки и схлопывал её.
        lastPress = Vector2.zero,
        toggleKey = opts.ToggleKey or Enum.KeyCode.Delete,
        -- Открылось или закрылось меню -- зовётся с true/false.
        --
        -- Нужен вызывающему, а не библиотеке: закрытие меню -- естественная
        -- точка, где настройки пора записать на диск. Само оно этого не делает
        -- и делать не должно -- КОГДА сохранять решает тот, кто знает, что за
        -- настройки и куда их класть.
        onToggle = opts.OnToggle or false,
    }, Window)

    -- Ядру нужно окно, поэтому не в таблице выше, а сразу после неё. Раньше
    -- этой строки привязок не существует, и NierUI.keyGrabbed честно отвечает
    -- «никто не ждёт»: он читает ядро через rawget и отсутствие переносит.
    self.binds = NierUI.bindCore(self)

    -- Размер зажимается по экрану. Умолчание в 644x483 рассчитано на монитор, а
    -- на телефоне в альбомной ориентации логическая высота бывает и 414 -- окно
    -- вылезло бы за край вместе с нижней панелью и кнопкой закрытия. Запас в 16
    -- пикселей, чтобы рамка не упиралась в самый край.
    local view = NierUI.viewport()
    local width = math.min(opts.Width or THEME.WindowWidth, view.X - 16)
    local height = math.min(opts.Height or THEME.WindowHeight, view.Y - 16)

    self.gui = U.new("ScreenGui", {
        Name = U.randomName(),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999,
        IgnoreGuiInset = true,
    }, U.guiParent())

    self.root = U.new("Frame", {
        BackgroundColor3 = THEME.Bg, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = opts.Position or UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(width, height),
        ClipsDescendants = true,
    }, self.gui)
    U.stroke(self.root, 2)

    --== шапка ===============================================================

    local headerH = THEME.HeaderHeight
    local hintH = THEME.HintHeight
    local colW = THEME.TabColumnWidth

    -- Полосы-перфорации съедают высоту у содержимого, поэтому границы области
    -- считаются от них, а не от шапки напрямую. Band = false -- и всё
    -- сходится обратно само, без отдельной ветки раскладки.
    local bandH = THEME.Band and THEME.BandHeight or 0
    local top = headerH + 1 + bandH
    local bottom = hintH + bandH

    local header = U.new("Frame", {
        BackgroundTransparency = 1, Active = true,
        Size = UDim2.new(1, 0, 0, headerH),
    }, self.root)

    U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = opts.Title or "NieR", TextColor3 = THEME.Ink,
        TextSize = THEME.TitleSize, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 22),
    }, header)

    U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = opts.Subtitle or "", TextColor3 = THEME.InkSoft,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(17, 33), Size = UDim2.new(1, -32, 0, 12),
    }, header)

    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, headerH), Size = UDim2.new(1, 0, 0, 1),
    }, self.root)

    --== колонка вкладок =====================================================

    local tabCol = U.new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, top),
        Size = UDim2.new(0, colW, 1, -top - bottom),
    }, self.root)
    U.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, tabCol)
    U.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8) }, tabCol)
    self.tabCol = tabCol

    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        BackgroundTransparency = 0.6,
        Position = UDim2.fromOffset(colW, top),
        Size = UDim2.new(0, 1, 1, -top - bottom),
    }, self.root)

    --== содержимое ==========================================================

    self.body = U.new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(colW + 1, top),
        Size = UDim2.new(1, -(colW + 1), 1, -top - bottom),
    }, self.root)

    --== панель описания =====================================================

    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        BackgroundTransparency = 0.6,
        Position = UDim2.new(0, 0, 1, -hintH), Size = UDim2.new(1, 0, 0, 1),
    }, self.root)

    -- Полосы по краям содержимого: одна сразу под чертой шапки, вторая над
    -- панелью описания.
    NierUI.texture.band(self.root, headerH + 1)
    NierUI.texture.band(self.root, height - hintH - bandH)

    self.desc = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = opts.Hint or "", TextColor3 = THEME.InkSoft,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Position = UDim2.new(0, 16, 1, -(hintH - 6)),
        Size = UDim2.new(1, -32, 0, hintH - 12),
    }, self.root)

    U.corners(self.root)
    NierUI.texture.apply(self.root, height)

    --== перетаскивание ======================================================
    --
    -- Через события, без покадрового опроса. Мышь опрашивается сотни раз в
    -- секунду, но пока не тянут -- обработчик выходит первой строкой.

    local dragging, dragStart, startPos = false, nil, nil

    table.insert(self.conns, header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging, dragStart, startPos = true, input.Position, self.root.Position
    end))

    table.insert(self.conns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = input.Position - dragStart
        -- Округляем: дробная позиция окна размазывает все однопиксельные линии
        -- между соседними пикселями, и рамки начинают выглядеть неровными.
        self.root.Position = UDim2.new(
            startPos.X.Scale, math.floor(startPos.X.Offset + delta.X + 0.5),
            startPos.Y.Scale, math.floor(startPos.Y.Offset + delta.Y + 0.5))
    end))

    table.insert(self.conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))

    --== клавиша открытия ====================================================

    table.insert(self.conns, UserInputService.InputBegan:Connect(function(input, processed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.lastPress = input.Position
        end

        -- ПРАВАЯ КНОПКА РАЗБИРАЕТСЯ ЗДЕСЬ, А НЕ НА ЭЛЕМЕНТЕ, И ДО ПРОВЕРКИ
        -- processed.
        --
        -- Фон-перехватчик всплывающего окна поглощает щелчок целиком, поэтому
        -- на элементе MouseButton2Click при открытом окне не срабатывает вовсе
        -- -- ни на той же строке, ни на любой другой. Отсюда и невозможность
        -- открыть настройки двух пунктов рядом. UserInputService нажатие
        -- получает в любом случае, а кому оно предназначалось, считает Context.
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            if self.visible then NierUI.contextDispatch(self, input.Position) end
            return
        end

        -- PROCESSED ДЛЯ КЛАВИАТУРЫ ИГНОРИРУЕМ -- ровно как ядро привязок.
        --
        -- Здесь стояло безусловное `if processed then return end`, и клавиша
        -- открытия жила по другим правилам, чем все остальные привязки: игра
        -- вешает свои действия на клавиши и съедает их первой, и меню тогда не
        -- открывалось вовсе, а выглядело это как «клавиша не работает».
        -- Обоснование то же, что в docs/binds.md: меню ставят ПОВЕРХ игры.
        --
        -- Настоящая причина «нажатие не наше» одна -- набор текста, и она
        -- проверяется прямо.
        if UserInputService:GetFocusedTextBox() then return end
        -- Строка ждёт клавишу -- нажатие принадлежит ЕЙ. Иначе назначение
        -- клавиши открытия закрывало бы окно тем же самым нажатием, которым её
        -- назначают, и увидеть результат было бы уже негде.
        if NierUI.keyGrabbed(self) then return end
        if input.KeyCode == self.toggleKey then self:Toggle() end

    end))

    -- Открываем через тот же путь, которым пользуется клавиша: вместе с окном
    -- поднимаются перехват ввода и указатель. Visible = false заводит окно
    -- спрятанным -- скрипту, который показывает меню сам, это удобнее, чем
    -- моргнуть им при загрузке.
    self:Toggle(opts.Visible ~= false)

    -- Мастер-профиль поднимается ПОСЛЕ того, как вызывающий закончил постройку.
    --
    -- Прямо здесь его поднимать бессмысленно: окно возвращается пустым, вкладки
    -- и виджеты добавляются следующими строками, и в реестре флагов пока пусто
    -- -- применять было бы нечего. task.defer ждёт ровно до конца текущего
    -- потока, без опроса и без таймера.
    -- ПОРЯДОК ЗДЕСЬ ВАЖЕН: сперва достраиваем, потом применяем профиль.
    --
    -- Менеджер привязок заводит по тумблеру на каждую привязку, и у них есть
    -- флаги. Примени мы профиль раньше -- этих флагов в реестре ещё нет, и
    -- сохранённые значения достались бы некому. Одна отложенная задача на всё,
    -- а не по одной на каждого: две задачи не дают никакого порядка между собой.
    task.defer(function()
        if not self.gui or not self.gui.Parent then return end
        -- Ошибку здесь НЕ ГЛОТАЕМ молча. Отложенное строит настоящие строки
        -- меню, и упавший построитель выглядит как «раздела просто нет» -- ни
        -- ошибки, ни намёка, где искать. Одна отвалившаяся часть при этом не
        -- должна утаскивать за собой остальные, поэтому pcall с жалобой.
        for _, fn in ipairs(self.deferred) do
            local ok, err = pcall(fn)
            if not ok then warn("[NierUI] отложенная постройка: " .. tostring(err)) end
        end
        table.clear(self.deferred)
        if self.autoMaster then pcall(self.LoadMaster, self) end
    end)

    return self
end

function Window:Hint(text)
    self.desc.Text = text or ""
end

--=============================================================================
-- ПРИВЯЗКА БЕЗ СТРОКИ
--=============================================================================
--
--     win:Bind({ Text = "СНЯТЬ ВСЁ", Flag = "panic", Key = Enum.KeyCode.G,
--                Action = unloadAll })
--
-- Привязка, у которой нет ни строки, ни ворот: показывать нечего и гасить
-- нечему. Годится и Toggle -- тогда состояние своё, как у взаимодействия, --
-- но воротами ей никто не управляет, потому что мастер-свитча над ней нет.
--
-- Делегат в одну строку, а не второй способ объявить: набор полей тот же самый,
-- что у Core.Add, и перевода имён между ними нет.
function Window:Bind(opts)
    return self.binds:Add(opts or {})
end

--=============================================================================
-- КЛАВИША ОТКРЫТИЯ
--=============================================================================
--
-- Меняется на лету и без переподписки: обработчик ввода один и сравнивает с
-- текущим значением при каждом нажатии. Пересоздавать подписку ради смены
-- клавиши значило бы получить окно, у которого на секунду нет ни старой
-- клавиши, ни новой.
--
-- Поле toggleKey намеренно не объявлено «внутренним»: менять его напрямую
-- сработает, но проверки типа не будет, а Enum.KeyCode легко перепутать с
-- Enum.UserInputType -- тогда меню просто перестанет открываться, молча.

function Window:SetToggleKey(key)
    if typeof(key) ~= "EnumItem" or key.EnumType ~= Enum.KeyCode then
        error("[NierUI] SetToggleKey ждёт Enum.KeyCode, получено: "
            .. typeof(key), 2)
    end
    self.toggleKey = key
    return key
end

function Window:GetToggleKey()
    return self.toggleKey
end

-- Прячем КОРЕНЬ окна, а не весь ScreenGui.
--
-- Раньше гасился gui целиком, и вместе с меню исчезали бы уведомления --
-- а они обязаны показываться при закрытом меню, иначе бесполезны. Всплывающие
-- окна при закрытии гасим явно: висеть поверх спрятанного меню им незачем.
function Window:Toggle(state)
    if state == nil then state = not self.visible end
    self.visible = state
    self.root.Visible = state
    if not state then self:ClosePopups() end

    -- Пока меню открыто, ввод принадлежит ему: курсор виден, щелчки и движение
    -- в игру не уходят. См. Capture.
    -- Перехват берём и отпускаем ДО того, как сообщить: подписчик закрытия
    -- вправе тут же сохранить профиль или снять окно, и состояние ввода к этому
    -- моменту обязано быть уже приведённым.
    if self.captureInput then
        if state then self:StartCapture() else self:StopCapture() end
    end

    if self.onToggle then pcall(self.onToggle, state) end
end

function Window:Destroy()
    -- Всплывающие окна и уведомления живут своей жизнью на ScreenGui, гасим их
    -- первыми: у уведомлений вдобавок висят отложенные задержки, которым иначе
    -- достались бы уже уничтоженные объекты.
    --
    -- БЕЗ ПРОВЕРКИ «А ЕСТЬ ЛИ ТАКОЙ МЕТОД». Здесь стояло `if self.ClosePopups
    -- then`, будто части библиотеки бывают не загружены, -- а сборка кладёт их
    -- все и всегда (см. build.ps1), да и Toggle зовёт ClosePopups со
    -- StopCapture безусловно. Условие, которое не бывает ложным, -- это не
    -- страховка, а обещание конфигурации, которой нет: не хватит части -- пусть
    -- падает громко и на первом же вызове, а не тихо не убирается за собой.
    self:ClosePopups()
    self:ClearNotifications()

    -- Ядро привязок: отменить ожидание нажатия и отпустить удержания. Сами
    -- подписки лежат в self.conns и гаснут ниже вместе со всеми, но залипшее
    -- ЗАЖАТИЕ они не отпустят -- отпускание придёт в подписку, которой уже нет.
    if self.binds then self.binds:Destroy() end
    -- Перехват ввода надо снять обязательно: он живёт в сервисах, а не в нашем
    -- дереве, и уничтожение ScreenGui его не отпустит -- курсор остался бы
    -- висеть, а управление в игре не вернулось бы вовсе.
    self:StopCapture()

    -- Контейнеры меню держат подписки в своих стоках, а не в оконном -- гасим
    -- каждый явно. Стоянки лежат в gui и ушли бы с ним, но подписки нет.
    --
    -- ОБХОД ПО КОПИИ, А НЕ ПО ЖИВОМУ СПИСКУ. Panel.Destroy вычёркивает себя
    -- отсюда же, и ipairs по списку, который под ним укорачивается,
    -- ПЕРЕСКАКИВАЕТ ЧЕРЕЗ СОСЕДА: из {A,B,C} уничтожались A и C, а B оставался
    -- жив -- и тут же терялся, потому что следом список чистится целиком.
    --
    -- Цена была не косметическая. У пропущенной панели остаются висеть её
    -- глобальные подписки на ввод, а cleanups не зовутся вовсе -- то есть
    -- счётчик кадров ПРОДОЛЖАЕТ считать каждый кадр после сноса окна. Ровно
    -- тот вечный поток, ради отсутствия которого написана вся библиотека.
    for _, panel in ipairs(table.clone(self.panels)) do
        pcall(function() panel:Destroy() end)
    end
    table.clear(self.panels)

    NierUI.drain(self.conns)
    self.popupInput = false
    self.popupShade = false
    table.clear(self.popupPlaces)
    -- Реестр правой кнопки держит СИЛЬНЫЕ ссылки на элементы (слабые ключи по
    -- Instance в Lua не работают так, как хочется, -- см. README), поэтому
    -- чистится руками, как и всё остальное.
    table.clear(self.m2)
    pcall(function() self.gui:Destroy() end)
    self.tabs, self.current = {}, nil
end

--=============================================================================
-- Вкладки
--=============================================================================

function Window:Tab(name)
    -- Как и у окна: всё состояние заводится сразу. grid и blocks появляются
    -- только когда вкладку делят на блоки, но читаются раньше -- значит должны
    -- существовать со дня рождения.
    local tab = setmetatable({
        window = self, rows = 0,
        -- Своего стока у вкладки нет: она живёт столько же, сколько окно, и
        -- заводить ей отдельный список значило бы гасить его ровно тогда же,
        -- когда гаснет оконный. false -- «беру у окна», см. NierUI.sink.
        conns = false,
        -- Владелец: у вкладки его нет. Есть у меню правой кнопки -- это строка,
        -- из которой оно открыто (см. воронку в containerIndex).
        owner = false,
        pendingMenu = false,
        pendingSettings = false,
        grid = false, blocks = false,
        layoutQueued = false, separators = {},
    }, Tab)

    tab.button = U.new("TextButton", {
        BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Font = THEME.Font, Text = "  " .. (name or "TAB"),
        TextColor3 = THEME.Ink, TextSize = THEME.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -8, 0, THEME.RowHeight),
        LayoutOrder = #self.tabs + 1,
    }, self.tabCol)

    tab.page = U.new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1), Visible = false,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = THEME.Ink,
        ScrollBarImageTransparency = 0.4,
    }, self.body)
    U.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, tab.page)
    U.new("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8),
    }, tab.page)

    table.insert(self.conns, tab.button.MouseEnter:Connect(function()
        if self.current ~= tab then U.tween(tab.button, { BackgroundTransparency = 0.85 }) end
    end))
    table.insert(self.conns, tab.button.MouseLeave:Connect(function()
        if self.current ~= tab then U.tween(tab.button, { BackgroundTransparency = 1 }) end
    end))
    table.insert(self.conns, tab.button.MouseButton1Click:Connect(function()
        self:Select(tab)
    end))

    table.insert(self.tabs, tab)
    if not self.current then self:Select(tab) end
    return tab
end

function Window:Select(tab)
    for _, other in ipairs(self.tabs) do
        local on = other == tab
        other.page.Visible = on
        U.tween(other.button, { BackgroundTransparency = on and 0 or 1 })
        other.button.TextColor3 = on and THEME.Bg or THEME.Ink
    end
    self.current = tab
end

end)(NierUI)

--============================ NierUI/Block.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Block -- деление вкладки на ячейки 2x2
--=============================================================================
--
--     tab:Block("Left", "Up", "COMBAT")   левая верхняя клетка, с заголовком
--     tab:Block("Right")                  вся правая полоса
--     tab:Block("Down")                   вся нижняя полоса
--     tab:Block()                         единственный, на всю страницу
--
-- Порядок аргументов свободный: ось узнаётся по самому слову, а не по месту.
-- Left/Right -- ось X, Up/Down -- ось Y, любая другая строка -- заголовок.
-- Поэтому tab:Block("Up") работает так же, как tab:Block(nil, "Up").
--
-- Блок -- такой же КОНТЕЙНЕР, что и вкладка (см. Window.containerIndex): у него
-- есть .page, .rows и .window, и виджеты не отличают его от вкладки. Ни один
-- виджет ради блоков править не пришлось.
--
--
--=============================================================================
-- ПРАВИЛО РАЗМЕЩЕНИЯ
--=============================================================================
--
-- Разрешение идёт ПО КОНКРЕТНОСТИ, а не по порядку объявления. Блок,
-- объявленный двухсотым, получит ровно то же, что получил бы первым.
--
--   1. Кто назвал ОБЕ оси -- получает ровно свою клетку. Только её: блок
--      Left+Up никогда не претендует на Left+Down.
--   2. Кто назвал ОДНУ ось -- берёт всю свою полосу, но только из того, что
--      осталось свободным после шага 1. Заявивший права на конкретную клетку
--      её и получает, не заявлявший -- уступает.
--   3. Кто не назвал ничего -- занимает страницу целиком, но только если он
--      один. Вместе с любым другим блоком -- ошибка.
--
-- ЯВНАЯ ОШИБКА, А НЕ РАЗМЕЩЕНИЕ НАУГАД, во всех спорных случаях:
--   * две клетки с одинаковыми полными координатами;
--   * два односторонних на одной и той же стороне (Up и Up);
--   * два односторонних на РАЗНЫХ осях, спорящих за одну свободную клетку
--     (Left и Up): прав на неё не заявлял ни один, отдавать некому;
--   * односторонний, которому не осталось ни одной свободной клетки;
--   * безпараметрный рядом с кем угодно.

local THEME = NierUI.Theme
local U = NierUI.util
local Tab = NierUI.TabClass

local X_WORDS = { left = "Left", right = "Right" }
local Y_WORDS = { up = "Up", down = "Down" }

local Block = {}
Block.__index = NierUI.containerIndex(Block)

--=============================================================================
-- Разбор аргументов
--=============================================================================

-- Разбирается ТОЛЬКО строка: ось или заголовок. Здесь же собиралась четвёртая
-- величина -- таблица «дополнительно», -- которую никто никогда не читал:
-- Tab:Block забирал её в локальную и на этом всё. Пустое обещание в разборе
-- аргументов хуже отсутствующего: снаружи оно выглядит настройкой.
local function parseArgs(...)
    local x, y, title
    for index = 1, select("#", ...) do
        local arg = select(index, ...)
        if type(arg) == "string" then
            local word = arg:lower()
            if X_WORDS[word] then
                if x then
                    error(("[NierUI] Block: ось X задана дважды (%s и %s)")
                        :format(x, X_WORDS[word]), 3)
                end
                x = X_WORDS[word]
            elseif Y_WORDS[word] then
                if y then
                    error(("[NierUI] Block: ось Y задана дважды (%s и %s)")
                        :format(y, Y_WORDS[word]), 3)
                end
                y = Y_WORDS[word]
            elseif title == nil then
                title = arg
            end
        end
    end
    return x, y, title
end

local function describe(block)
    local parts = {}
    if block.x then parts[#parts + 1] = block.x end
    if block.y then parts[#parts + 1] = block.y end
    if #parts == 0 then parts[1] = "без параметров" end
    local name = block.title and (" «" .. block.title .. "»") or ""
    return table.concat(parts, "+") .. name
end

--=============================================================================
-- Раскладка
--=============================================================================

local function cellKey(x, y) return x .. "|" .. y end

local function bandOf(block)
    if block.x and not block.y then
        return { cellKey(block.x, "Up"), cellKey(block.x, "Down") }
    end
    return { cellKey("Left", block.y), cellKey("Right", block.y) }
end

-- Доля и отступ по одной оси. Две колонки с зазором G между ними: каждая
-- шириной (W-G)/2, то есть 0.5 доли минус половина зазора.
local function span(index, cells, gap)
    if cells == 2 then
        return UDim.new(0, 0), UDim.new(1, 0)
    end
    if index == 0 then
        return UDim.new(0, 0), UDim.new(0.5, -gap / 2)
    end
    return UDim.new(0.5, gap / 2), UDim.new(0.5, -gap / 2)
end

local function place(block, col, row, wide, tall)
    local gap = THEME.BlockGap
    local px, pw = span(col, wide, gap)
    local py, ph = span(row, tall, gap)
    block.frame.Position = UDim2.new(px.Scale, px.Offset, py.Scale, py.Offset)
    block.frame.Size = UDim2.new(pw.Scale, pw.Offset, ph.Scale, ph.Offset)
end

local function rectOf(cells)
    local minC, maxC, minR, maxR = 2, -1, 2, -1
    for _, key in ipairs(cells) do
        local cx, cy = key:match("^(%a+)|(%a+)$")
        local col = cx == "Left" and 0 or 1
        local rowIndex = cy == "Up" and 0 or 1
        minC, maxC = math.min(minC, col), math.max(maxC, col)
        minR, maxR = math.min(minR, rowIndex), math.max(maxR, rowIndex)
    end
    return minC, minR, maxC - minC + 1, maxR - minR + 1
end

--=============================================================================
-- РАЗДЕЛИТЕЛИ РИСУЮТСЯ ПО ГРАНИЦАМ, А НЕ ПО ВСЕЙ СЕТКЕ
--=============================================================================
--
-- Сначала линии были сплошные: есть где-то деление по X -- вертикаль во всю
-- высоту, есть по Y -- горизонталь во всю ширину. При раскладке Left+Up плюс
-- Right это резало правый блок пополам: он занимает обе правые клетки, границы
-- внутри него нет, а линия через него всё равно шла.
--
-- Линия существует там, где встречаются ДВА РАЗНЫХ блока. Поэтому вертикаль
-- считается отдельно для верхней и нижней строки, горизонталь -- отдельно для
-- левой и правой колонки. Пустая клетка линии не даёт: отделять блок от
-- пустоты незачем.

-- РАЗДЕЛИТЕЛИ СТАВЯТСЯ В ЦЕЛЫХ ПИКСЕЛЯХ, А НЕ ДОЛЯМИ.
--
-- Доля 0.5 на нечётной стороне даёт половину пикселя: при сетке 479x374 центр
-- по Y приходился на 186.5, и однопиксельная линия размазывалась между двумя
-- рядами -- горизонталь выглядела заметно толще и мягче вертикали. Замеры при
-- этом показывали честную единицу у обеих.
--
-- Поэтому положение считается от абсолютного размера сетки с округлением вниз,
-- и пересчитывается при её изменении. Обе половины каждой оси упираются в одну
-- и ту же целую координату центра, так что узел смыкается точно.

local function layoutSeparators(tab)
    local size = tab.grid.AbsoluteSize
    local w, h = math.floor(size.X), math.floor(size.Y)
    local cx, cy = math.floor(w / 2), math.floor(h / 2)

    for _, spec in ipairs(tab.separators) do
        if spec.vertical then
            local from = spec.second and cy or 0
            local to = spec.second and h or cy
            spec.frame.Position = UDim2.fromOffset(cx, from)
            spec.frame.Size = UDim2.fromOffset(1, to - from)
        else
            local from = spec.second and cx or 0
            local to = spec.second and w or cx
            spec.frame.Position = UDim2.fromOffset(from, cy)
            spec.frame.Size = UDim2.fromOffset(to - from, 1)
        end
    end
end

local function edge(tab, vertical, second)
    tab.separators[#tab.separators + 1] = {
        vertical = vertical, second = second,
        frame = U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
            BackgroundTransparency = 0.65, ZIndex = 5,
        }, tab.grid),
    }
end

local ROWS = { "Up", "Down" }
local COLS = { "Left", "Right" }

-- ОТРЕЗКИ ИДУТ ОТ КРАЯ СЕТКИ ДО ЕЁ ЦЕНТРА, а не до края клетки.
--
-- Первая версия обрывала их по границе клетки, и линии не смыкались: горизонталь
-- заканчивалась на 236, вертикаль стояла на 240 -- четыре пикселя зазора между
-- ними, ровно в узле. Половинки одной оси при этом тоже не сходились.
--
-- Все разделители лежат на двух центральных осях, поэтому соседние по одной оси
-- сливаются в сплошную линию, а перпендикулярные пересекаются в центре. Узел
-- замкнут по построению, а не подгонкой.
local function drawSeparators(tab, final)
    -- Без pcall с замыканием: Destroy на живом объекте не падает, а замыкание
    -- заводилось бы на каждую линию при каждой пересборке раскладки.
    for _, spec in ipairs(tab.separators) do
        spec.frame:Destroy()
    end
    table.clear(tab.separators)
    if not THEME.BlockSeparators then return end

    -- вертикальные: по строке, если слева и справа разные блоки
    for index, yWord in ipairs(ROWS) do
        local left = final[cellKey("Left", yWord)]
        local right = final[cellKey("Right", yWord)]
        if left and right and left ~= right then
            edge(tab, true, index == 2)
        end
    end

    -- горизонтальные: по колонке, если сверху и снизу разные блоки
    for index, xWord in ipairs(COLS) do
        local up = final[cellKey(xWord, "Up")]
        local down = final[cellKey(xWord, "Down")]
        if up and down and up ~= down then
            edge(tab, false, index == 2)
        end
    end

    layoutSeparators(tab)
end

local function resolve(tab)
    local blocks = tab.blocks
    if #blocks == 0 then return end

    --== без параметров ======================================================

    for _, block in ipairs(blocks) do
        if not block.x and not block.y then
            if #blocks > 1 then
                error(("[NierUI] блок без параметров занимает всю страницу и не "
                    .. "уживается с другими; рядом объявлено ещё %d")
                    :format(#blocks - 1), 0)
            end
            place(block, 0, 0, 2, 2)
            drawSeparators(tab, {})
            return
        end
    end

    --== шаг 1: полные координаты ============================================

    local owner = {}
    for _, block in ipairs(blocks) do
        if block.x and block.y then
            local key = cellKey(block.x, block.y)
            if owner[key] then
                error(("[NierUI] две клетки с одинаковыми координатами: %s и %s")
                    :format(describe(owner[key]), describe(block)), 0)
            end
            owner[key] = block
            block.cells = { key }
        end
    end

    --== шаг 2: одна ось =====================================================
    --
    -- Свободные клетки считаются ПОСЛЕ шага 1 и независимо от того, в каком
    -- порядке блоки объявлены. Спор двух односторонних за одну и ту же
    -- свободную клетку разрешать нечем -- прав на неё не заявлял ни один.

    local wants = {}
    for _, block in ipairs(blocks) do
        if (block.x and not block.y) or (block.y and not block.x) then
            local free = {}
            for _, key in ipairs(bandOf(block)) do
                if not owner[key] then
                    free[#free + 1] = key
                    local other = wants[key]
                    if other then
                        error(("[NierUI] %s и %s спорят за свободную клетку %s; "
                            .. "уточните вторую ось хотя бы одному")
                            :format(describe(other), describe(block), key), 0)
                    end
                    wants[key] = block
                end
            end
            if #free == 0 then
                error(("[NierUI] %s: свободных клеток в его полосе не осталось")
                    :format(describe(block)), 0)
            end
            block.cells = free
        end
    end

    --== геометрия ===========================================================

    -- Итоговая карта «клетка -> хозяин»: полные блоки из шага 1 плюс то, что
    -- разобрали односторонние. По ней и считаются границы.
    local final = {}
    for key, block in pairs(owner) do final[key] = block end
    for key, block in pairs(wants) do final[key] = block end

    for _, block in ipairs(blocks) do
        place(block, rectOf(block.cells))
    end
    drawSeparators(tab, final)
end

-- Геометрия считается ОТЛОЖЕННО: односторонний блок обязан ужаться под полный
-- независимо от того, кто объявлен раньше, а значит решать можно только когда
-- объявлены все.
local function schedule(tab)
    if tab.layoutQueued then return end
    tab.layoutQueued = true
    task.defer(function()
        tab.layoutQueued = false
        resolve(tab)
    end)
end

--=============================================================================
-- Сетка вкладки
--=============================================================================

local function ensureGrid(tab)
    if tab.grid then return tab.grid end

    -- Строки и блоки в одной вкладке несовместимы: страница раскладывает детей
    -- списком сверху вниз, и сетка встала бы в этот же поток, ниже строк, с
    -- непредсказуемой высотой. Лучше сказать об этом сразу.
    if tab.rows > 0 then
        error("[NierUI] во вкладке уже есть строки; блоки и строки в одной "
            .. "вкладке несовместимы -- положите строки внутрь блока", 3)
    end

    -- Страница вкладки раскладывает строки списком сверху вниз и растит
    -- полотно под них. Для блоков это не нужно: они позиционируются сами, а
    -- прокрутка живёт внутри каждого. Автополотно выключаем, иначе сетка
    -- высотой в долю от страницы и растущее под неё полотно тянули бы друг
    -- друга по кругу.
    tab.page.AutomaticCanvasSize = Enum.AutomaticSize.None
    tab.page.CanvasSize = UDim2.new()

    tab.grid = U.new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
    }, tab.page)
    tab.blocks = {}

    -- Разделители стоят в целых пикселях, значит зависят от размера сетки:
    -- меняется окно -- пересчитываем, иначе линии разъедутся от центра.
    NierUI.connect(tab, tab.grid:GetPropertyChangedSignal("AbsoluteSize"), function()
        layoutSeparators(tab)
    end)

    return tab.grid
end

--=============================================================================

function Tab:Block(...)
    local x, y, title = parseArgs(...)

    -- Нормализуем СРАЗУ, до всех сравнений. В блоке отсутствие оси хранится
    -- как false, и сравнение сырого nil с сохранённым false ложно -- на этом
    -- молча не срабатывала проверка «две одинаковые полосы»: Up и Up
    -- проходили без ошибки.
    x, y, title = x or false, y or false, title or false

    local grid = ensureGrid(self)

    --== проверки, которые можно сделать сразу ===============================
    --
    -- Здесь ловится всё, что не зависит от ещё не объявленных блоков: так
    -- ошибка указывает на нужную строку. Спор за свободную клетку сюда не
    -- относится -- он зависит от полных блоков, которые могут появиться позже.

    for _, other in ipairs(self.blocks) do
        if (not other.x and not other.y) or (not x and not y) then
            error("[NierUI] блок без параметров занимает всю страницу и не "
                .. "уживается с другими", 2)
        end
        if x and y and other.x == x and other.y == y then
            error(("[NierUI] клетка %s+%s уже занята"):format(x, y), 2)
        end
        if not (x and y) and not (other.x and other.y)
            and other.x == x and other.y == y then
            error(("[NierUI] две одинаковые полосы: %s"):format(describe(other)), 2)
        end
    end

    --== сам блок ============================================================

    -- Отсутствие оси -- false, а НЕ nil: диспетчер контейнера ругается на
    -- любое отсутствующее поле, и `if block.x then` обязано читать
    -- существующее значение.
    local block = setmetatable({
        window = self.window, rows = 0,
        -- Сток НАСЛЕДУЕТСЯ от вкладки: блок живёт ровно столько же, сколько
        -- она, а внутри временного контейнера обязан гаснуть вместе с ним.
        conns = self.conns,
        owner = self.owner, pendingMenu = false, pendingSettings = false,
        x = x, y = y, title = title,
        cells = false,
    }, Block)

    block.frame = U.new("Frame", {
        BackgroundColor3 = THEME.BgSunk, BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 0), ClipsDescendants = true,
    }, grid)

    local top = 0
    if title then
        U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = title, TextColor3 = THEME.InkSoft, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(10, 5),
            Size = UDim2.new(1, -20, 0, 12), ZIndex = 2,
        }, block.frame)
        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
            BackgroundTransparency = 0.65,
            Position = UDim2.fromOffset(0, THEME.BlockTitleHeight),
            Size = UDim2.new(1, 0, 0, 1), ZIndex = 2,
        }, block.frame)
        top = THEME.BlockTitleHeight + 1
    end

    -- Своя прокрутка: содержимое длиннее ячейки не обрезается, а листается.
    -- Раскрытый список внутри блока тоже уезжает сюда, поэтому высота ячейки
    -- ему не помеха.
    block.page = U.new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, top),
        Size = UDim2.new(1, 0, 1, -top),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = THEME.Ink,
        ScrollBarImageTransparency = 0.4,
    }, block.frame)
    U.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, block.page)
    U.new("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6),
    }, block.page)

    table.insert(self.blocks, block)
    schedule(self)
    return block
end

end)(NierUI)

--============================ NierUI/Section.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Section и Split -- вложенные контейнеры
--=============================================================================
--
--     local group = tab:Section("PASSIVE")        складная группа
--     group:Toggle({ ... })
--
--     local left, right = tab:Split(2)            колонки в одной строке
--     left:Toggle({ ... })  right:Slider({ ... })
--
-- Оба возвращают КОНТЕЙНЕР -- то же, что вкладка и блок. Виджеты не заметят
-- разницы, потому что знают только про .page, .rows и .window.
--
--
-- ПОЧЕМУ SPLIT, А НЕ SameLine
--
-- В imgui несколько элементов в строке ставятся через SameLine -- пометку
-- «следующий рядом с предыдущим». Здесь это не годится: каждый виджет строит
-- СВОЮ строку во всю ширину и сам расставляет подпись, дорожку и значение по
-- долям. Чтобы SameLine заработал, пришлось бы вскрыть все виджеты и научить
-- их делить строку -- то есть переписать ровно то, что мы только что привели в
-- порядок.
--
-- Split решает ту же задачу снаружи: делит МЕСТО, а не строку. Виджеты внутри
-- колонки продолжают считать, что занимают всю ширину, потому что для них это
-- правда -- просто ширина теперь другая. Ни один виджет не тронут.

local THEME = NierUI.Theme
local U = NierUI.util
local C = NierUI.containerMethods

local Sub = {}
Sub.__index = NierUI.containerIndex(Sub)

local function makeSub(parent, page)
    return setmetatable({
        window = parent.window, rows = 0, page = page,
        -- Сток НАСЛЕДУЕТСЯ, а не берётся у окна: секция внутри временного
        -- контейнера обязана гаснуть вместе с ним. Взяв оконный, она пережила
        -- бы своего родителя вместе со всеми подписками виджетов внутри.
        conns = parent.conns,
        -- Владелец тоже наследуется: привязка в секции внутри меню принадлежит
        -- той же строке, что и меню.
        owner = parent.owner, pendingMenu = false, pendingSettings = false,
    }, Sub)
end

-- Наружу: динамическому списку нужен собственный кусок страницы, который можно
-- чистить целиком, не задевая соседей по контейнеру.
NierUI.makeSub = makeSub

--=============================================================================
-- Секция
--=============================================================================

function C.Section(self, title, opts)
    opts = opts or {}
    self.rows = self.rows + 1

    local holder = U.new("Frame", {
        BackgroundTransparency = 1, ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, THEME.RowHeight),
        LayoutOrder = self.rows,
    }, self.page)

    local header = U.new("TextButton", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "",
        Size = UDim2.new(1, 0, 0, THEME.RowHeight),
    }, holder)

    -- Указатель состояния: заполненный квадрат -- раскрыто, пустой -- свёрнуто.
    -- Значок вместо стрелки, чтобы не заводить ещё один шрифт ради глифа.
    local mark = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.fromOffset(6, 6), ZIndex = 3,
    }, header)

    local label = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = tostring(title or ""), TextColor3 = THEME.InkSoft, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -26, 0, THEME.RowHeight), ZIndex = 3,
    }, header)

    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        BackgroundTransparency = 0.75,
        Position = UDim2.new(0, 0, 0, THEME.RowHeight - 1),
        Size = UDim2.new(1, 0, 0, 1), ZIndex = 2,
    }, header)

    local body = U.new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, THEME.RowHeight),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, holder)
    U.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    U.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, body)

    local open = opts.Open ~= false

    -- Высота держателя считается ЯВНО: свёрнутая секция должна занимать ровно
    -- заголовок, а AutomaticSize учитывает и невидимых детей, из-за чего
    -- свёрнутая группа продолжала бы раздвигать соседей.
    local function relayout()
        holder.Size = UDim2.new(1, 0, 0,
            THEME.RowHeight + (open and body.AbsoluteSize.Y or 0))
        mark.BackgroundTransparency = open and 0 or 0.6
        body.Visible = open
    end

    NierUI.connect(self, body:GetPropertyChangedSignal("AbsoluteSize"), relayout)

    NierUI.connect(self, header.MouseButton1Click, function()
        open = not open
        relayout()
    end)
    NierUI.connect(self, header.MouseEnter, function()
        label.TextColor3 = THEME.Ink
    end)
    NierUI.connect(self, header.MouseLeave, function()
        label.TextColor3 = THEME.InkSoft
    end)

    relayout()

    local sub = makeSub(self, body)
    sub.SetOpen = function(_, state) open = state ~= false relayout() end
    sub.IsOpen = function(_) return open end
    return sub
end

--=============================================================================
-- Колонки
--=============================================================================

function C.Split(self, count, opts)
    opts = opts or {}
    count = math.max(2, math.min(count or 2, 4))
    self.rows = self.rows + 1

    local gap = opts.Gap or 6

    local holder = U.new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self.rows,
    }, self.page)

    local columns = {}
    local share = 1 / count

    -- ЗАЗОР ДЕЛИТСЯ ПО ЧИСЛУ ЩЕЛЕЙ, А ОТСТУП КОЛОНКИ РАСТЁТ ВМЕСТЕ С НОМЕРОМ.
    --
    -- Раньше отступ был один и тот же (gap/2) у всех колонок кроме первой, а
    -- ширина уменьшалась на gap*(count-1)/count. На двух колонках это сходилось
    -- точно и потому не вызывало вопросов; на трёх зазоры выходили 7 и 4, на
    -- четырёх расходились ещё сильнее -- колонки визуально разъезжались, хотя
    -- ширина у всех была одинаковой.
    --
    -- Щелей ровно count-1, каждая шириной gap. Колонка отдаёт долю зазора,
    -- пропорциональную числу щелей, а её левый край сдвигается на столько
    -- зазоров, сколько щелей осталось слева.
    local shrink = gap * (count - 1) / count

    for index = 1, count do
        local column = U.new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(share * (index - 1),
                gap * (index - 1) - shrink * (index - 1), 0, 0),
            Size = UDim2.new(share, -shrink, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        }, holder)
        U.new("UIListLayout", {
            Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
        }, column)

        columns[index] = makeSub(self, column)
    end

    return table.unpack(columns)
end

end)(NierUI)

--============================ NierUI/Cursor.luau ============================
;(function(NierUI)
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
    -- Поверх всего своего: у окна ZIndexBehavior = Sibling, число сравнивается
    -- глобально, и всплывающие окна с их сотнями сюда не дотягиваются.
    --
    -- Само число -- в общей таблице порядка слоёв (см. NierUI.layers в Util),
    -- иначе оно жило бы в двух местах.
    local Z = NierUI.layers.cursor

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
    -- Сверху 4 -- на случай, когда логический экран КРУПНЕЕ физического
    -- (масштаб меньше 100%; через настройки Windows такого не выставить, но
    -- драйверы и правка реестра позволяют).
    --
    -- Шаг больше логического пикселя принимаем только после восьми движений, и
    -- это не перестраховка: НОД сходится СВЕРХУ, и на первых сдвигах он вполне
    -- может оказаться равным трём. Приняв это сразу, мы бы на секунду раздули
    -- указатель втрое.
    --
    -- СНИЗУ 0.25, А НЕ 0.1, И ЭТО ИСПРАВЛЕНИЕ, А НЕ ВКУСОВЩИНА.
    --
    -- 0.1 задумывалось как запас «на масштаб 1000%», но такого экрана не
    -- существует, а вот СБИТЫЙ ЗАМЕР выглядит ровно так же. Наблюдалось вживую:
    -- НОД сложился в 0.2 при истинных 0.8, и указатель схлопнулся в точку два
    -- на два пикселя. Заметить это можно только глазами -- ошибки нет, курсор
    -- «есть», просто его не видно.
    --
    -- Хуже того, snap() такое значение УЗАКОНИВАЕТ: 0.2 -- честная дробь 1/5,
    -- он подтягивает к ней и придаёт мусору вид измеренной величины.
    --
    -- 0.25 -- это плотность 4x, крайний из случаев, на которых указатель
    -- проверялся. Всё, что мельче, физического смысла не имеет, а как признак
    -- испорченного замера -- имеет вполне. НОД умеет только уменьшаться, и один
    -- сбитый сдвиг иначе портит замер до конца сеанса: сам он оттуда не
    -- вернётся, поможет только переоткрытие меню.
    local acc = nil
    local function observe(at)
        if last then
            moves = moves + 1
            acc = fold(fold(acc, math.abs(at.X - last.X)), math.abs(at.Y - last.Y))
            local trusted = acc and acc >= 0.25
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

    -- Размер, от которого считаем «экран изменился». ПЕРВОЕ присвоение размера
    -- холдеру -- не изменение экрана, а его рождение, и сбрасывать по нему
    -- замер незачем: при каждом новом окне общий NierUI.pixelStep обнулялся бы
    -- в единицу, и указатель до первого движения мыши оказывался бы крупнее
    -- нужного. Замерено: после пары созданных окон шаг стоял 1 при истинных 0.8.
    local known = holder.AbsoluteSize

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
            local size = holder.AbsoluteSize
            if size.X <= 0 or size.Y <= 0 then return end

            local born = known.X <= 0 or known.Y <= 0
            if not born and size == known then return end
            known = size

            -- Сбрасываем замер только при НАСТОЯЩЕЙ смене размера экрана: у
            -- другого монитора другой физический пиксель, а НОД умеет только
            -- уменьшаться и сам бы туда не вернулся. Рождение холдера такой
            -- сменой не является.
            if not born then
                acc, last, moves = nil, nil, 0
                step = 1
                NierUI.pixelStep = 1
            end

            layout()
            place(UserInputService:GetMouseLocation())
        end),
    }
end

function Window:HideCursor()
    if not self.cursorOn then return end
    self.cursorOn = false

    if self.cursorConns then NierUI.drain(self.cursorConns) end
    self.cursorConns = false

    if self.cursor then self.cursor.Visible = false end
end

end)(NierUI)

--============================ NierUI/Capture.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Capture -- меню забирает ввод себе, пока открыто
--=============================================================================
--
-- Открыл меню посреди боя -- курсор появился, щелчки идут в меню, а не в игру.
-- Закрыл -- всё вернулось ровно как было.
--
-- Выключается опцией окна: NierUI:Window({ CaptureInput = false }).
--
--
-- НИ ЦИКЛА, НИ СТОРОЖА -- ЗАПИСЬ ОДИН РАЗ
--
-- Режим мыши и видимость указателя выставляются на входе и возвращаются на
-- выходе. Всё.
--
-- Здесь по очереди были опробованы и убраны два способа удерживать своё против
-- игры. Покадровое удержание -- это постоянный поток ради того, что меняется
-- раз в десять минут, и первый такой поток в библиотеке. Подписка на изменение
-- свойства выглядит дешевле, но это та же гонка, только на событиях: две
-- подписки на окно, взаимная правка свойств, и состояние, которое невозможно
-- объяснить, если подписки снесут снаружи -- у исполнителей есть
-- getconnections, и любая чужая «уборка подписок» рубит наши вместе со своими.
--
-- Спор этот к тому же изначально проигрышный: игра прячет указатель не одним
-- свойством, и выигранная строчка кода не делает меню рабочим.
--
-- Поэтому системный указатель ГАСИТСЯ на входе, а вместо него рисуется свой
-- (см. Cursor). Режим мыши ставится в Default по той же причине: в LockCenter
-- указатель прибит к середине экрана и ни до одной строки не доедет.
--
-- Игру, переставившую своё ПОКА меню открыто, мы всё-таки не теряем: за режимом
-- следит наблюдатель, который только читает и запоминает (см. StartCapture).
-- Записи против игры по-прежнему нет ни одной -- разница между «наблюдать» и
-- «держать» здесь и проходит.
--
-- Видимость указателя так не подхватить: MouseIconEnabled не шлёт сигнала
-- изменения вовсе. Она возвращается такой, какой была на момент открытия, и это
-- записанная граница, а не недосмотр.
--
-- Приоритет поглотителя заведомо выше игровых: у Roblox штатные привязки живут
-- около двух тысяч, берём с запасом. Что именно поглощается -- у SINK.

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local U = NierUI.util
local Window = NierUI.WindowClass

local PRIORITY = 5000

--=============================================================================
-- «КАК БЫЛО» -- ОДНО НА ВСЮ БИБЛИОТЕКУ, А НЕ ПО КОПИИ НА ОКНО
--=============================================================================
--
-- Сперва каждое окно запоминало состояние мыши себе. С одним окном это верно, а
-- со вторым ломается наглухо и молча.
--
-- Разбор: окно A захватывает, честно сохраняет icon = true и ставит false. Пока
-- оно держит, появляется окно B -- и сохраняет «как было» уже ИСПОРЧЕННОЕ,
-- icon = false. Дальше неважно, кто уйдёт последним: возвращён будет false.
-- Системный указатель выключен, свой погашен вместе с окном, и курсора в игре
-- нет ни одного. Вернуть его нечем -- значение, которое было настоящим, никто
-- больше не помнит.
--
-- Ловилось это тем хуже, что окно долго не захватывало ввод при создании (оно
-- вообще не звало Toggle), и двум окнам столкнуться было негде.
--
-- Поэтому счётчик: исходное состояние записывает ПЕРВЫЙ захвативший, возвращает
-- ПОСЛЕДНИЙ отпустивший. Живёт на самой библиотеке -- она кешируется в
-- окружении, и запись переживает и пересоздание окна, и перезапуск скрипта.
--
--
--=============================================================================
-- УМЕРШЕЕ ОКНО НЕ ОТПУСКАЕТ НИЧЕГО. ВОТ ЭТО И БЫЛО ПРИЧИНОЙ.
--=============================================================================
--
-- Перехват живёт НЕ в нашем дереве: привязка в ContextActionService и два
-- сторожа на свойствах мыши. Уничтожение ScreenGui их не трогает -- снимает их
-- только StopCapture.
--
-- Значит окно, умершее мимо Destroy -- скрипт упал, исполнитель выгрузили,
-- getgenv почистили, gui снесли руками, -- оставляет за собой:
--
--   привязку CAS, которая ПРОДОЛЖАЕТ ГЛОТАТЬ мышь и WASD. Меню закрыто, а
--     управление в игре не работает;
--   сторожа, который ПРОДОЛЖАЕТ ГАСИТЬ системный указатель. Свой курсор при
--     этом спрятан вместе с окном -- на экране не остаётся ни одного.
--
-- Замерено на живом клиенте: две брошенные привязки и два брошенных сторожа.
-- Снять их было нечем: ссылки на окно больше нет ни у кого.
--
-- Отсюда правило: держателем считается только ЖИВОЙ, а за мёртвого прибираемся
-- мы. Набор вместо счётчика именно поэтому -- по числу не понять, кто именно
-- держит, и уж тем более нечего у него отобрать.
--
-- ТОЧКА ОТСЧЁТА -- НА ЭПИЗОД ЗАХВАТА, А НЕ НА СЕАНС.
--
-- Снимает её тот, кто взял ввод, когда до него не держал никто; второе окно
-- поверх первого её не трогает -- иначе записало бы наше состояние вместо
-- игрового.
--
-- Раз за сеанс -- была прямая ошибка. Режим мыши у игры не постоянный: замерено
-- в [CURE] Violence District, за выжившего в матче это LockCenter, в лобби и в
-- третьем лице Default, на зажатой правой LockCurrentPosition. Открыл меню
-- первый раз в лобби -- и Default возвращался до конца сеанса, сколько бы
-- матчей человек ни сыграл. Ровно отсюда бралось «курсор остаётся разлоченным
-- всё время».
--
-- Довод против («на экране могут быть наши же следы») снят уборкой: мёртвых
-- держателей выметает holders() прямо перед снимком, а живой держатель снимок
-- вообще не даёт обновить.
NierUI.captureHolders = NierUI.captureHolders or {}
NierUI.captureBase = NierUI.captureBase or false
NierUI.captureWatch = NierUI.captureWatch or false

--=============================================================================
-- ЧТО МЫ СТАВИМ СЕБЕ НА ВРЕМЯ ЗАХВАТА
--=============================================================================
--
-- Хранилось это изменяемым полем на библиотеке (`captureOurs`), одним на все
-- окна, и обе половинки лежали там неправильно.
--
-- РЕЖИМ -- КОНСТАНТА. Он всегда Default: в LockCenter указатель прибит к
-- середине экрана и ни до одной строки не доедет. Наблюдатель сравнивал с полем,
-- которое никогда не менялось, -- то есть с константой, записанной в переменную.
--
-- ВИДИМОСТЬ -- У КАЖДОГО ОКНА СВОЯ, и общее поле здесь было прямой ошибкой. Окно
-- со своим указателем системный гасит, окно с Cursor = false -- показывает.
-- Открой их два, и ВТОРОЕ переписывало бы значение первого; дальше уступка
-- системному меню (см. yieldToMenu) возвращала бы окну не то, что оно себе
-- ставило, -- курсор то пропадал бы, то двоился, и виновата была бы «какая-то
-- другая настройка».
--
-- Своё от чужого мы по-прежнему отличаем сравнением с ЭТИМ значением: точнее
-- нельзя, Roblox не сообщает, кто менял свойство.
local OUR_BEHAVIOR = Enum.MouseBehavior.Default

-- Свой указатель -- значит системный лишний: два курсора хуже, чем ни одного.
-- Отказались от своего -- пробуем показать системный, больше нам предложить
-- нечего.
local function ourIcon(window)
    return not window.drawCursor
end

--=============================================================================
-- ПОГЛОТИТЕЛЬ СНИМАЕТСЯ И СТАВИТСЯ ОБРАТНО, А НЕ ТОЛЬКО В КОНЦЕ
--=============================================================================
--
-- Пока открыто СИСТЕМНОЕ меню Roblox (Escape), ввод принадлежит ему. Наша
-- привязка стоит на приоритете 5000 и глотает кнопки мыши -- то есть ровно те
-- щелчки, которыми человек и пользуется в системном меню. Со стороны это
-- выглядит как «меню Escape сломалось».
--
-- Поэтому на время системного меню поглотитель отпускается и ставится обратно,
-- когда оно закроется. По событию, без опроса: MenuIsOpen -- обычное свойство
-- GuiService, и сигнал у него есть (в отличие от MouseIconEnabled, см. ниже).

-- ЧТО ИМЕННО ПОГЛОЩАЕТСЯ. Объявлено ЗДЕСЬ, а не ниже у StartCapture: bindSink
-- читает этот список, и лежащее ниже по файлу досталось бы ей как nil -- ровно
-- на этом сборка один раз и упала, «invalid argument #1 to unpack».
--
-- Кнопки мыши и клавиши движения -- то, чем в бою стреляют и ездят. Не вся
-- клавиатура: под перехватом остались бы и наши собственные поля ввода.
local SINK = {
    Enum.UserInputType.MouseButton1,
    Enum.UserInputType.MouseButton2,
    Enum.UserInputType.MouseButton3,
    Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
    Enum.KeyCode.Q, Enum.KeyCode.E,
    Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.LeftControl,
}

local function unbindSink(window)
    if not window.captureAction then return end
    pcall(function() ContextActionService:UnbindAction(window.captureAction) end)
    window.captureAction = false
end

local function bindSink(window)
    if window.captureAction then return end
    if not (window.gui and window.gui.Parent) then return end
    -- Имя привязки -- имя нашего ScreenGui. Не украшение: по нему и только по
    -- нему уборка отличает брошенную привязку от чужой живой. См. sweepOrphans.
    window.captureAction = "NierUI_" .. window.gui.Name
    ContextActionService:BindActionAtPriority(
        window.captureAction,
        function() return Enum.ContextActionResult.Sink end,
        false, PRIORITY, table.unpack(SINK))
end

-- Снять всё, чем окно держит ввод и указатель. Годится и для живого (StopCapture),
-- и для мёртвого -- разницы для сервисов нет.
local function release(window)
    unbindSink(window)
    if window.captureMenu then
        pcall(function() window.captureMenu:Disconnect() end)
        window.captureMenu = false
    end
end

-- Наблюдатель за чужими правками. Живёт ровно один эпизод захвата: заводится с
-- первым держателем, снимается с последним -- и за мёртвым тоже, иначе пережил
-- бы своё меню и писал в чужую точку отсчёта.
local function unwatch()
    if not NierUI.captureWatch then return end
    NierUI.drain(NierUI.captureWatch)
    NierUI.captureWatch = false
end

--=============================================================================
-- КОНЕЦ ЭПИЗОДА -- ВЕРНУТЬ ИГРЕ ЕЁ СОСТОЯНИЕ
--=============================================================================
--
-- Вынесено из StopCapture, потому что зовущих ДВОЕ, и второй -- уборка за
-- окном, умершим мимо Destroy. У такого StopCapture не позовёт уже никто, а на
-- экране осталось НАШЕ состояние: свободный курсор и погашенный указатель.
--
-- Раньше уборка снимала за мёртвым только поглотитель ввода. Мышь оставалась
-- нашей навсегда, и дальше эта неправильность сама себя удерживала: следующий
-- захват видел «держателей ноль», снимал ТЕКУЩЕЕ за игровое -- то есть наши же
-- руины, -- и честно возвращал их при каждом закрытии меню. Снаружи это ровно
-- «курсор отклеился и больше не запирается», и происхождение у него неочевидное:
-- меню в этот момент работает правильно, оно возвращает то, что ему показали.
--
-- Точку отсчёта гасим ЗДЕСЬ ЖЕ. Двух возвратов одного эпизода не бывает: второй
-- вернул бы то, что уже вернули, поверх успевшего смениться игрового.
local function restore()
    local base = NierUI.captureBase
    if not base then return end
    NierUI.captureBase = false

    -- ВОЗВРАЩАЕМ ПАРУ -- И ЭТОГО ДОСТАТОЧНО, ПОЗИЦИЮ ТРОГАТЬ НЕ НАДО.
    --
    -- Запирание само определяет, где указатель окажется: вернули LockCenter --
    -- движок утащил его в середину. Замерено за выжившего в матче: игра держит
    -- LockCenter + скрытый указатель ровно в центре (768,432 при вьюпорте
    -- 1536x864); меню разлочило и увело его в 738,429; вернули пару -- и он
    -- встал обратно в 768,432, отклонение НОЛЬ.
    --
    -- Была версия, которая возвращала ещё и точку -- через VirtualInputManager,
    -- с отложенным на кадр запиранием и разной целью на каждый режим. Она вся
    -- оказалась лишней: работу делает сам режим.
    UserInputService.MouseBehavior = base.behavior

    -- ВИДИМОСТЬ ВЫВОДИМ ИЗ РЕЖИМА, А НЕ ДОСТАЁМ ИЗ СНИМКА.
    --
    -- Снимок видимости протухает НАПОЛОВИНУ, и это не теория. За режимом следит
    -- наблюдатель и подхватывает чужую правку; за видимостью следить нечем --
    -- MouseIconEnabled не шлёт сигнала изменения вовсе. Игра переключилась в
    -- матч, пока меню открыто: режим мы подхватили, видимость осталась старой.
    --
    -- Замерено ровно это: на выходе получалась пара «LockCenter + курсор виден»,
    -- которой в игре не бывает. А дальше она самоподдерживается -- следующий
    -- снимок берёт уже её, и курсор не прячется никогда.
    --
    -- Запертый указатель ВСЕГДА спрятан: игра его прибивает и не показывает
    -- (замерено за выжившего в матче -- LockCenter при MouseIconEnabled = false).
    -- Значит видимость из режима выводится однозначно, и хранить её незачем.
    -- Свободный курсор -- другое дело: там прячет или показывает игра по своим
    -- причинам, и вот тут снимок и есть единственный источник правды.
    --
    -- Тот же приём, что с позицией указателя: воспроизводим СМЫСЛ режима, а не
    -- запомненное число.
    UserInputService.MouseIconEnabled =
        (base.behavior == Enum.MouseBehavior.Default) and base.icon or false
end

local function holders()
    local alive, swept = 0, false
    for window in pairs(NierUI.captureHolders) do
        if window.captured and window.gui and window.gui.Parent then
            alive = alive + 1
        else
            -- Прибираемся ЗА него: сам он уже не сможет.
            release(window)
            NierUI.captureHolders[window] = nil
            swept = true
        end
    end

    if alive == 0 then
        -- Не осталось никого живого -- наблюдателю тоже незачем жить.
        unwatch()

        -- ЗА МЁРТВЫМ ВОЗВРАЩАЕМ И МЫШЬ. Только за мёртвым: живой отпускающий
        -- вернёт её сам, в StopCapture, и делать это дважды нельзя.
        --
        -- Возврат идёт ДО того, как вызывающий снимет свою точку отсчёта (см.
        -- порядок в StartCapture), -- иначе снимком станут наши остатки.
        --
        -- Чужой экземпляр библиотеки так не вылечить, и это честная граница:
        -- реестр держателей у каждого загрузившего свой, а КАКОЕ состояние было
        -- у игры до чужого захвата, знает только он сам. Брошенный поглотитель
        -- ввода опознаётся по экрану и снимается у всех (см. sweepOrphans);
        -- режим мыши по экрану не опознать никак.
        if swept then restore() end
    end
    return alive
end

--=============================================================================
-- БРОШЕННУЮ ПРИВЯЗКУ ОПОЗНАЁТ ЭКРАН, А НЕ РЕЕСТР
--=============================================================================
--
-- Перехват живёт в ContextActionService и уничтожение ScreenGui его не трогает.
-- Значит окно, умершее мимо Destroy, оставляет за собой привязку, которая
-- ПРОДОЛЖАЕТ ГЛОТАТЬ мышь и WASD при закрытом меню. Снять её через release
-- нечем: ссылки на такое окно больше нет ни у кого.
--
-- Спрашивать при этом РЕЕСТР -- нельзя, и вот почему. Реестр держателей лежит на
-- таблице библиотеки, а её у каждого загрузившего своя: перезапустили скрипт --
-- таблица новая, загрузили вторую копию рядом -- таблица вторая. Прежде здесь
-- снималось всё, чего в реестре нет, и второй ЖИВОЙ экземпляр библиотеки
-- оставался без мыши и без WASD посреди работы -- ровно та беда, которую эта
-- уборка и должна была чинить.
--
-- Поэтому доказательство жизни -- САМ ScreenGui, и привязка называется его
-- именем. Жив он -- жив и держатель, кто бы его ни создал и в какой бы копии
-- библиотеки тот ни жил. Нет его -- отпустить привязку больше некому, она наша
-- и она брошена.
--
-- Упавший скрипт под это не попадает намеренно: его меню осталось на экране и
-- продолжает работать -- подписки живы, пока живо дерево, -- а значит закрытие
-- меню честно снимет перехват само.
--
-- Имя мы даём сами и больше никто, спутать не с чем.
local function sweepOrphans(home)
    local ok, bound = pcall(function()
        return ContextActionService:GetAllBoundActionInfo()
    end)
    if not ok or type(bound) ~= "table" then return end

    for name in pairs(bound) do
        local gui = tostring(name):match("^NierUI_(.+)$")
        if gui and not (home and home:FindFirstChild(gui)) then
            pcall(function() ContextActionService:UnbindAction(name) end)
        end
    end
end

-- Где лежат наши ScreenGui. У своего окна спрашиваем напрямую: если исполнитель
-- не дал в gethui и окно уехало в PlayerGui, искать соседей надо там же, где
-- стоит оно само.
local function homeOf(window)
    return window.gui and window.gui.Parent or U.guiParent()
end

--=============================================================================

function Window:StartCapture()
    if self.captured then return end

    -- БЕЗ МЫШИ ПЕРЕХВАТЫВАТЬ НЕЧЕГО. На телефоне, планшете и консоли касание и
    -- так достаётся тому, по чему нажали, а поглощать WASD и кнопки мыши там
    -- бессмысленно: экранные органы управления -- это тот же интерфейс, и в
    -- ContextActionService они не приходят.
    --
    -- Хуже того, режим мыши там трогать нельзя вовсе: на консоли Default
    -- отвяжет прицел от стика.
    if not UserInputService.MouseEnabled then return end

    -- ПЕРЕД тем как брать своё -- прибрать за мёртвыми. holders() выметает
    -- держателей этого экземпляра, sweepOrphans -- всех прочих, чьё окно уже не
    -- на экране. Оба до снятия точки отсчёта: иначе запомним не «как было», а
    -- наши же руины.
    --
    -- ПОРЯДОК ЗДЕСЬ -- ЧАСТЬ ЛЕЧЕНИЯ, а не оформление. Выметая мёртвого,
    -- holders() ВОЗВРАЩАЕТ игре её мышь, и только поэтому строчкой ниже мы
    -- снимаем игровое состояние, а не оставленное покойником.
    local alive = holders()
    sweepOrphans(homeOf(self))

    self.captured = true

    -- Снимок делает ПЕРВЫЙ захвативший в эпизоде. Держит кто-то живой -- значит
    -- на экране уже наше состояние, и записывать его как «игровое» нельзя.
    if alive == 0 then
        NierUI.captureBase = {
            behavior = UserInputService.MouseBehavior,
            icon = UserInputService.MouseIconEnabled,
        }
    end
    NierUI.captureHolders[self] = true

    -- Ставим ОДИН РАЗ, без сторожа.
    --
    -- Раньше на оба свойства висели подписки, возвращавшие наше значение всякий
    -- раз, когда игра его переписывала. Спор этот всё равно проигрышный: игра
    -- прячет указатель не одним свойством, а держать своё против чужого кода --
    -- это гонка без конца.
    UserInputService.MouseBehavior = OUR_BEHAVIOR
    UserInputService.MouseIconEnabled = ourIcon(self)

    -- НАБЛЮДАТЕЛЬ, А НЕ СТОРОЖ: ОН ТОЛЬКО ЧИТАЕТ.
    --
    -- Снимок в момент открытия -- намерение игры на тот момент, и он протухает,
    -- если игра переставит своё, ПОКА меню открыто. Так и было: настройки
    -- правились из системного меню, за это время игра поменяла режим, а
    -- закрытие вернуло снятое до того -- курсор оставался разлоченным.
    --
    -- Отвергнутый когда-то сторож ПИСАЛ наше значение поверх игрового -- вот это
    -- и была гонка без конца. Здесь записи нет ни одной: увидели чужое значение
    -- -- запомнили как новое намерение игры, и всё. Своё от чужого отличаем
    -- сравнением с OUR_BEHAVIOR; точнее нельзя, Roblox не сообщает, кто менял.
    --
    -- СЛЕДИМ ТОЛЬКО ЗА РЕЖИМОМ: MouseIconEnabled не шлёт
    -- GetPropertyChangedSignal вовсе -- замерено, шесть правок подряд дали ноль
    -- срабатываний у него и три из трёх у MouseBehavior. Подписка на него была
    -- бы мёртвым кодом, выглядящим как работающий.
    --
    -- Отсюда честная граница: режим подхватывается, даже если игра переставила
    -- его при открытом меню; видимость возвращается такой, какой была НА МОМЕНТ
    -- ОТКРЫТИЯ. Опрашивать её каждый кадр ради этого не станем -- это опрос,
    -- ровно то, чего в библиотеке нет.
    if alive == 0 then
        local base = NierUI.captureBase
        NierUI.captureWatch = {
            UserInputService:GetPropertyChangedSignal("MouseBehavior")
                :Connect(function()
                    local now = UserInputService.MouseBehavior
                    if now == OUR_BEHAVIOR then return end
                    base.behavior = now
                end),
        }
    end

    if self.drawCursor then self:ShowCursor() end

    bindSink(self)

    -- СИСТЕМНОЕ МЕНЮ ЗАБИРАЕТ ВВОД СЕБЕ, И СПОРИТЬ С НИМ НЕЧЕГО.
    --
    -- Открылось -- отпускаем поглотитель и прячем свой указатель: щелчки в нём
    -- предназначены ему, а наш крест поверх него только мешает. Закрылось --
    -- берём обратно, если меню всё ещё открыто.
    --
    -- Замерено: пока MenuIsOpen, до скрипта доходит одно событие движения мыши
    -- за всё окно вместо сотен -- то есть держать перехват в это время не
    -- просто вредно, а бессмысленно.
    -- СИСТЕМНОМУ МЕНЮ НУЖЕН КУРСОР, А МЫ ОБА ВЫКЛЮЧИЛИ.
    --
    -- Пока держим захват, системный указатель погашен (рисуем свой). Открылось
    -- меню Escape -- свой мы прячем, потому что поверх него он только мешает, и
    -- на экране не остаётся НИ ОДНОГО курсора: щёлкать в системном меню нечем.
    -- Со стороны это ровно «меню Escape сломалось».
    --
    -- Поэтому на время системного меню системный указатель ВОЗВРАЩАЕТСЯ, а
    -- закроется -- снова гасится. Это единственное место, где мы трогаем чужое
    -- свойство не на границе захвата, и трогаем ровно потому, что сами его и
    -- выключили.
    -- ВОЗВРАЩАЕМ СВОЁ, А НЕ ДЕРЖИМ ЧУЖОЕ. Это разные вещи, и путать их дорого.
    --
    -- УДЕРЖАНИЕ -- это переставлять ИГРОВОЕ значение поверх игры: гонка, исход
    -- которой решает тот, кто записал последним. Такого здесь нет.
    --
    -- А НАШЕ состояние на время захвата (см. ourIcon) уступка системному меню
    -- временно снимает: поглотитель, свой указатель, погашенный системный.
    -- Закрылось меню -- возвращаем всё три, симметрично. Поглотитель мы так и
    -- возвращаем, и указатель обязан возвращаться так же.
    --
    -- Не вернуть -- значит оставить включённым системный указатель, а следующее
    -- открытие снимет ЕГО как «игровое» состояние, и дальше эта неправильность
    -- самоподдерживается: игра прячет курсор однократно и сама обратно не
    -- прячет. Ровно та же ловушка, что была с режимом мыши.
    --
    -- Игровое значение живёт отдельно, в снимке, и возвращается один раз -- на
    -- выходе из захвата.
    local function yieldToMenu(open)
        if open then
            unbindSink(self)
            if self.drawCursor then self:HideCursor() end
            -- системному меню нужен курсор, а мы его погасили
            UserInputService.MouseIconEnabled = true
        else
            UserInputService.MouseIconEnabled = ourIcon(self)
            bindSink(self)
            if self.drawCursor then self:ShowCursor() end
        end
    end

    self.captureMenu = GuiService:GetPropertyChangedSignal("MenuIsOpen")
        :Connect(function()
            if not self.captured then return end
            yieldToMenu(GuiService.MenuIsOpen)
        end)

    -- Меню могли открыть ДО нас: тогда сигнала не будет, а уступать надо.
    if GuiService.MenuIsOpen then yieldToMenu(true) end
end

function Window:StopCapture()
    if not self.captured then return end
    self.captured = false

    self:HideCursor()
    -- Привязку снимает release -- то же самое, что делается за мёртвым
    -- держателем. Две копии этого кода однажды разошлись бы.
    release(self)

    -- Возвращает ПОСЛЕДНИЙ отпустивший. Пока держит хоть кто-то ЖИВОЙ, возвращать
    -- нечего: он на это состояние и рассчитывает. Мёртвые из набора выметаются
    -- прямо здесь, поэтому окно, умершее без Destroy, никого не блокирует.
    NierUI.captureHolders[self] = nil
    if holders() > 0 then return end

    -- НИКТО БОЛЬШЕ НЕ ДЕРЖИТ -- ЗНАЧИТ НАШИХ ПРИВЯЗОК БЫТЬ НЕ ДОЛЖНО ВОВСЕ.
    --
    -- release снимает привязку ТОЛЬКО у себя, а осиротевшую -- от окна, которого
    -- в реестре уже нет, -- снять было некому: подметание стояло лишь на входе,
    -- то есть срабатывало при ОТКРЫТИИ меню. Закрыл меню -- и чужая привязка
    -- продолжает глотать мышь и WASD, пока меню не откроют снова.
    --
    -- Замерено ровно в этом состоянии: captured = false, а привязок живых две.
    -- Ни нажать, ни пойти.
    sweepOrphans(homeOf(self))

    -- Наблюдателя снимаем ДО возврата: иначе он запишет наш же возврат как
    -- «новое намерение игры» -- и следующий эпизод начнётся с нашего значения,
    -- выданного за игровое.
    unwatch()

    -- Возврат и гашение точки отсчёта -- в restore: то же самое делает уборка за
    -- окном, умершим мимо Destroy, и двух копий этого кода быть не должно.
    restore()
end

end)(NierUI)

--============================ NierUI/Config.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Config -- сохранение и загрузка настроек
--=============================================================================
--
--     win:Save("default")      записать профиль
--     win:Load("default")      применить
--     win:Profiles()           список имён
--     win:DeleteProfile(name)
--
-- Сохраняются только элементы с полем Flag. Разметку, кнопки и подписи хранить
-- незачем, а безымянный элемент невозможно потом найти при загрузке.
--
--
-- ЧТО ИМЕННО СОХРАНЯЕТСЯ
--
-- Реестр окна держит handle виджета, а не значение. Сохранение спрашивает Get,
-- загрузка зовёт Set. Значит новый виджет становится сохраняемым сам по себе,
-- если умеет эту пару, и кодек трогать не нужно.
--
--
-- ПОЧЕМУ НУЖЕН КОДЕК
--
-- JSON знает числа, строки, булевы и таблицы -- и больше ничего. А у нас в
-- значениях лежат Color3 (палитра) и EnumItem (привязка клавиши). Отдать их в
-- JSONEncode как есть нельзя: Color3 превратился бы в пустой объект, EnumItem
-- уронил бы кодирование.
--
-- Поэтому каждое непростое значение заворачивается в пометку типа:
--     Color3        -> { __t = "c", v = "#RRGGBB" }
--     EnumItem      -> { __t = "k", e = "KeyCode", v = "LeftShift" }
-- Разворачивается обратно по той же пометке. Обычные таблицы (набор
-- множественного выбора, настройки пунктов) проходят рекурсией как есть.
--
-- У EnumItem пишется и САМО ПЕРЕЧИСЛЕНИЕ: без него разбор был зашит на
-- Enum.KeyCode, и любой другой EnumItem возвращался чужим или никаким. Записи
-- без поля e -- профили прежнего формата, там это всегда клавиша.
--
--
-- ЗАГРУЗКА ЗОВЁТ ОБРАТНЫЕ ВЫЗОВЫ, И ЭТО НАМЕРЕННО
--
-- Молча выставить значения означало бы, что меню показывает включённое, а
-- фичи выключены. Профиль должен ПРИМЕНЯТЬСЯ, а не только отображаться.
--
-- Исключение объявляет тот, кто строку и завёл: Apply = false. За такой строкой
-- стоит КОМАНДА, а не настройка, и её значение -- «что сделать, когда попросят».
-- Разобрать это снаружи нельзя: и то и другое выглядит как значение с обратным
-- вызовом. См. «настройка и команда» в Window.

local HttpService = game:GetService("HttpService")

local U = NierUI.util
local Window = NierUI.WindowClass

local ROOT = "NierUI"

--=============================================================================
-- Файлы
--=============================================================================
--
-- Функции записи есть не у всякого исполнителя, поэтому каждая проверяется
-- отдельно. Нет их -- сохранение просто не работает, а не роняет меню.

local function canWrite()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function ensureFolder(path)
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return end
    if not isfolder(path) then makefolder(path) end
end

-- Папку задаёт вызывающий, и её отсутствие -- ОШИБКА, а не повод придумать
-- имя самому. Придуманное имя означает, что при первой же смене заголовка окна
-- профили окажутся в новой папке, а старые останутся лежать сиротами.
local function folderOf(window)
    local folder = window.configFolder
    if not folder or folder == "" then
        error("[NierUI] не задана папка конфигов -- "
            .. "NierUI:Window({ ConfigFolder = \"myscript\" })", 3)
    end

    -- Имя попадает в путь, поэтому чистим всё, что не годится в имя файла.
    local safe = tostring(folder):gsub("[^%w _%-]", "")
    if safe == "" then
        error(("[NierUI] в ConfigFolder «%s» не осталось ни одного пригодного символа")
            :format(tostring(folder)), 3)
    end
    return ROOT .. "/" .. safe
end

local function pathOf(window, profile)
    return folderOf(window) .. "/" .. tostring(profile) .. ".json"
end

--=============================================================================
-- Кодек
--=============================================================================

--=============================================================================
-- ЧИСЛОВОЙ КЛЮЧ JSON НЕ ПЕРЕЖИВАЕТ, И ЭТО НЕ МЕЛОЧЬ
--=============================================================================
--
-- В JSON ключ объекта -- всегда строка. Таблица { [12345] = {...} } уходит как
-- {"12345": {...}} и возвращается со СТРОКОВЫМ ключом. Дальше SetSetting ищет
-- settings[12345], не находит settings["12345"] и молча выходит.
--
-- Молча -- потому что настройки применяются через pcall и отсутствие ключа
-- ошибкой не считается. Внешне это выглядело так: белый список сохраняется,
-- загружается, отметки на месте, а цвета у пунктов сброшены на умолчания.
--
-- Задевало это ровно ту форму, которую README рекомендует как основную там, где
-- подписи могут совпадать: { Text = "Игрок", Key = 12345 }.
--
-- Массивы (набор множественного выбора) при этом обязаны остаться массивами --
-- у них ключи 1..n и JSON их не портит. Поэтому разделяем: массив идёт как
-- массив, чисто строковый хеш -- как объект, а хеш с любым другим ключом
-- пишется парами, где ключ проходит через тот же кодек, что и значение.

local function isArray(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count == #t
end

local function encode(value)
    local kind = typeof(value)

    if kind == "Color3" then
        return { __t = "c", v = U.hex(value) }
    elseif kind == "EnumItem" then
        -- ИМЯ ПЕРЕЧИСЛЕНИЯ ПИШЕТСЯ РЯДОМ СО ЗНАЧЕНИЕМ.
        --
        -- Раньше писалось только имя элемента, а разбор шёл всегда через
        -- Enum.KeyCode -- в кодек была зашита догадка, что EnumItem бывает
        -- только клавишей. Догадка неверная: Settings выводит контрол из типа
        -- значения, и туда кладут что угодно. Enum.UserInputType.MouseButton2
        -- возвращался из профиля как Enum.KeyCode.MouseButton2, то есть nil, и
        -- настройка молча пропадала -- pcall в apply отсутствие ключа ошибкой
        -- не считает.
        return { __t = "k", e = tostring(value.EnumType), v = value.Name }
    elseif kind == "table" then
        if isArray(value) then
            local out = {}
            for index, v in ipairs(value) do out[index] = encode(v) end
            return out
        end

        local plain = true
        for k in pairs(value) do
            if type(k) ~= "string" then plain = false break end
        end

        if plain then
            local out = {}
            for k, v in pairs(value) do out[k] = encode(v) end
            return out
        end

        local entries = {}
        for k, v in pairs(value) do
            entries[#entries + 1] = { k = encode(k), v = encode(v) }
        end
        return { __t = "m", v = entries }
    end

    return value
end

local function decode(value)
    if type(value) ~= "table" then return value end

    if value.__t == "c" then
        return U.fromHex(value.v)
    end

    if value.__t == "k" then
        -- Профили СТАРОГО ФОРМАТА имени перечисления не несут. Тогда в этой
        -- пометке могла лежать только клавиша -- ею и разбираем, иначе всё
        -- сохранённое до этой правки перестало бы читаться.
        local kind = value.e or "KeyCode"
        -- Элемент мог исчезнуть между версиями движка -- pcall, а не вера.
        local ok, item = pcall(function() return Enum[kind][value.v] end)
        return ok and item or nil
    end

    -- Хеш с нестроковыми ключами: разворачиваем пары обратно. Ключ проходит
    -- через тот же кодек -- им может быть не только число.
    if value.__t == "m" then
        local out = {}
        for _, pair in ipairs(value.v or {}) do
            local k = decode(pair.k)
            if k ~= nil then out[k] = decode(pair.v) end
        end
        return out
    end

    local out = {}
    for k, v in pairs(value) do out[k] = decode(v) end
    return out
end

--=============================================================================
-- Сбор и применение
--=============================================================================

local function collect(window)
    local data = {}
    for flag, handle in pairs(window.flags) do
        -- Помеченное Save = false именуется, но в профиль не идёт: счётчики,
        -- служебные поля и прочее состояние, которое настройкой не является.
        local ok, value = false, nil
        if not window.noSave[flag] then
            ok, value = pcall(handle.Get, handle)
        end
        if ok then
            local entry = { value = encode(value) }

            -- Настройки живут отдельно от значения: без них сохранённый набор
            -- вернулся бы без цветов, клавиш и флагов.
            --
            -- Форм две, и виджет сообщает свою сам. У списка настройки лежат по
            -- пунктам -- это два уровня; у строки уровень один. Догадываться по
            -- виду таблицы нельзя: настройка пункта сама может быть таблицей.
            if handle.SettingsMap then
                local okS, map = pcall(handle.SettingsMap, handle)
                if okS and next(map) ~= nil then
                    entry.settings = encode(map)
                    entry.flat = handle.SettingsFlat == true
                end
            end

            -- ПРИВЯЗКИ ЕДУТ ВМЕСТЕ СО СТРОКОЙ, А НЕ ОТДЕЛЬНЫМИ ФЛАГАМИ.
            --
            -- Клавиша, режим и подпись -- настройки ОДНОГО пункта меню, ровно
            -- как цвет и число в settings. Заведи мы им свои флаги, пришлось бы
            -- выдумывать каждому имя и следить, чтобы оно не столкнулось с чужим.
            --
            -- МАССИВОМ, ПО ПОРЯДКУ ОБЪЯВЛЕНИЯ: у строки бывает рубильник и
            -- сколько угодно взаимодействий, а имя есть не у каждого. Цена
            -- честная: вставил новую привязку в СЕРЕДИНУ списка -- сохранённые
            -- клавиши сместятся на соседей. Дописывать в конец безопасно.
            --
            -- Собственное состояние взаимодействия сюда НЕ идёт: «летим прямо
            -- сейчас» -- это про сеанс, а не настройка. Поднимать его из профиля
            -- значило бы взлетать при запуске скрипта.
            --
            -- Подпись пишется только СВОЯ, данная человеком: скриптерская
            -- приедет из кода, и притом свежая. Сохрани мы её, переименование в
            -- коде не доходило бы до тех, кто уже сохранил профиль.
            if handle.binds and #handle.binds > 0 then
                local list = {}
                for index, bind in ipairs(handle.binds) do
                    list[index] = {
                        key = bind:Key(),
                        kind = bind:Kind(),
                        title = bind.titled or nil,
                        -- false пишем явно: nil означал бы «не сохраняли», а
                        -- скрытая привязка обязана вернуться скрытой.
                        shown = bind:Shown(),
                        -- Создал её человек в менеджере -- она его, и переживать
                        -- перезапуск обязана даже без клавиши.
                        made = bind:Made(),
                    }
                end
                entry.binds = encode(list)
            end

            data[flag] = entry
        end
    end
    return data
end

local function apply(window, data)
    local applied, missing = 0, {}

    for flag, entry in pairs(data) do
        local handle = window.flags[flag]
        if not handle then
            -- Профиль от другой сборки меню: элемент исчез или переименован.
            missing[#missing + 1] = flag
        else
            if entry.settings and handle.SetSetting then
                local map = decode(entry.settings)
                if entry.flat then
                    for field, v in pairs(map) do
                        pcall(handle.SetSetting, handle, field, v)
                    end
                else
                    for key, fields in pairs(map) do
                        for name, v in pairs(fields) do
                            pcall(handle.SetSetting, handle, key, name, v)
                        end
                    end
                end
            end

            -- Привязки восстанавливаются ДО значения: сперва клавиши и режимы,
            -- потом уже «включено или нет». Обратный порядок закрыл бы ворота
            -- по ещё не восстановленным привязкам.
            if entry.binds and handle.binds then
                local saved = decode(entry.binds)
                if type(saved) == "table" then
                    for index, bind in ipairs(handle.binds) do
                        local one = saved[index]
                        if type(one) == "table" then
                            pcall(bind.SetKey, bind, one.key)
                            if one.kind and one.kind ~= "action" then
                                pcall(bind.SetKind, bind, one.kind)
                            end
                            pcall(bind.SetTitle, bind, one.title)
                            if one.shown ~= nil then
                                pcall(bind.SetShown, bind, one.shown)
                            end
                            -- ПОСЛЕ клавиши: SetKey сам помечает привязку
                            -- созданной, и порядок наоборот терял бы снятие.
                            if one.made ~= nil then
                                pcall(bind.SetMade, bind, one.made)
                            end
                        end
                    end
                end
            end

            local value = decode(entry.value)
            if value ~= nil then
                -- ПОМЕЧЕННОЕ Apply = false СТАВИТСЯ МОЛЧА.
                --
                -- Значение поднимается в строку, обратный вызов не зовётся: за
                -- ней стоит команда, а не настройка, и её значение -- «что
                -- сделать, когда попросят». Выбор маски профиль обязан помнить,
                -- надевать её при каждом запуске -- нет.
                --
                -- Тишина -- вторым аргументом Set: он есть у всех виджетов
                -- ровно для этого случая, и заводить ради него второй путь
                -- применения незачем.
                local ok = pcall(handle.Set, handle, value, window.noApply[flag])
                if ok then applied = applied + 1 end
            end
        end
    end

    return applied, missing
end

--=============================================================================
-- Наружу
--=============================================================================

function Window:Save(profile)
    if not canWrite() then
        return false, "исполнитель не умеет писать файлы"
    end

    ensureFolder(ROOT)
    ensureFolder(folderOf(self))

    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, collect(self))
    if not ok then return false, "не закодировалось: " .. tostring(encoded) end

    local okWrite, err = pcall(writefile, pathOf(self, profile or "default"), encoded)
    if not okWrite then return false, tostring(err) end
    return true
end

function Window:Load(profile)
    if not canWrite() then
        return false, "исполнитель не умеет читать файлы"
    end

    local path = pathOf(self, profile or "default")
    if type(isfile) == "function" and not isfile(path) then
        return false, "профиля нет"
    end

    local okRead, raw = pcall(readfile, path)
    if not okRead then return false, tostring(raw) end

    local okDecode, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not okDecode or type(data) ~= "table" then
        return false, "файл повреждён"
    end

    local applied, missing = apply(self, data)
    return true, applied, missing
end

--=============================================================================
-- МАСТЕР-ПРОФИЛЬ
--=============================================================================
--
--     win:SetMaster("pvp")     назначить: грузится сам при каждом запуске
--     win:GetMaster()          какой назначен
--     win:SetMaster(false)     снять назначение
--
-- Имя лежит в отдельном файле рядом с профилями, а не внутри одного из них:
-- профиль -- это набор значений, и «какой из них главный» ему не принадлежит.
-- Положи мы указатель внутрь, он копировался бы вместе с профилем и назначал
-- сам себя при каждом копировании.
--
-- ЗАГРУЗКА ОТЛОЖЕНА НА КАДР, И ЭТО ВЫНУЖДЕННО. Окно возвращается пустым --
-- вкладки и виджеты вызывающий добавляет ПОСЛЕ. Загрузи мы профиль сразу, в
-- реестре не было бы ни одного флага и применять было бы нечего. task.defer
-- ждёт, пока вызывающий закончит постройку, и делает это без опроса и таймера.
--
-- Это не поток: одна отложенная задача, которая один раз отрабатывает и всё.

local MASTER = "master.txt"

local function masterPath(window)
    return folderOf(window) .. "/" .. MASTER
end

function Window:GetMaster()
    if not self.configFolder then return nil end
    if type(readfile) ~= "function" then return nil end

    local path = masterPath(self)
    if type(isfile) == "function" and not isfile(path) then return nil end

    local ok, name = pcall(readfile, path)
    if not ok then return nil end
    name = tostring(name):gsub("%s+$", "")
    return name ~= "" and name or nil
end

function Window:SetMaster(profile)
    if not canWrite() then return false, "исполнитель не умеет писать файлы" end

    ensureFolder(ROOT)
    ensureFolder(folderOf(self))

    if not profile then
        if type(delfile) == "function" then pcall(delfile, masterPath(self)) end
        return true
    end

    local ok, err = pcall(writefile, masterPath(self), tostring(profile))
    if not ok then return false, tostring(err) end
    return true
end

-- Зовётся окном при создании. Молчит, если папка не задана или мастера нет:
-- отсутствие мастер-профиля -- обычное дело, а не ошибка.
function Window:LoadMaster()
    if not self.configFolder then return false end

    if not self.autoMaster then return false end

    -- ПРОВЕРКА НА ЛОЖНОСТЬ, А НЕ НА nil.
    --
    -- В состоянии окна «не задан» хранится как false -- там все отсутствующие
    -- поля false, чтобы диспетчер контейнера отличал их от опечаток. Сравнение
    -- с nil здесь не срабатывало никогда, и имя из файла не читалось вовсе:
    -- мастер молча не поднимался, а выглядело это как «профиль пустой».
    local name = self.master
    if not name then
        local ok, found = pcall(self.GetMaster, self)
        name = ok and found or nil
    end
    if not name then return false end

    local ok, applied, missing = pcall(self.Load, self, name)
    if not ok then return false end
    return applied, missing
end

function Window:Profiles()
    if type(listfiles) ~= "function" then return {} end

    local ok, files = pcall(listfiles, folderOf(self))
    if not ok then return {} end

    local out = {}
    for _, path in ipairs(files) do
        local name = tostring(path):match("([^/\\]+)%.json$")
        if name then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

function Window:DeleteProfile(profile)
    if type(delfile) ~= "function" then return false end
    local ok = pcall(delfile, pathOf(self, profile or "default"))
    return ok
end

end)(NierUI)

--============================ NierUI/Notify.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Notify -- всплывающие сообщения
--=============================================================================
--
--     win:Notify({ Text = "...", Title = "...", Duration = 6 })
--
-- Выезжают из-за правого края экрана, стопкой сверху вниз, снизу убывающая
-- полоска остатка времени. Duration задаёт срок жизни, по умолчанию берётся
-- Theme.NotifyDuration.
--
--
-- ЖИВУТ ОТДЕЛЬНО ОТ ОКНА
--
-- Сообщение о том, что кто-то зашёл на сервер, обязано показаться при ЗАКРЫТОМ
-- меню. Поэтому слой висит на ScreenGui рядом с окном, а Toggle прячет корень
-- окна, а не весь ScreenGui.
--
--
-- СТОПКА ВЕДЁТСЯ ВРУЧНУЮ, БЕЗ UIListLayout
--
-- Сначала карточки лежали в UIListLayout. Он САМ управляет позицией детей и
-- молча перезаписывал твин выезда -- анимации не было вовсе, карточка просто
-- возникала на месте. Разложить это на «слот от раскладки плюс карточка
-- внутри» тоже нельзя без второго слоя вложенности: по X двигается карточка,
-- по Y -- вся стопка, и обе координаты живут в одном свойстве Position.
--
-- Поэтому позиции считаются здесь: X отвечает за выезд и уход, Y -- за место в
-- стопке, пересчёт идёт при появлении, уходе и изменении высоты карточки.
--
--
-- ВЫСОТА ЗАДАЁТСЯ ЯВНО, А НЕ AutomaticSize
--
-- Полоска остатка прижата к низу карточки. С AutomaticSize по высоте это
-- замкнутая зависимость: высота считается по детям, а ребёнок стоит по высоте.
-- Поэтому высоту карточки выставляем сами по фактической высоте текста.
--
--
-- УНИЧТОЖЕНИЕ ГАРАНТИРОВАНО
--
-- Снос привязан к Completed твина ухода, а не к отдельной задержке: задержка
-- могла разъехаться с анимацией и оставить карточку висеть. Плюс защита от
-- повторного ухода и от сноса окна раньше срока -- в обоих случаях выходим
-- молча, ничего не оставляя.

local TweenService = game:GetService("TweenService")

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

local PAD = 10
local GAP = 6
local BAR = 2
local EDGE = 16          -- отступ стопки от края экрана

local MOVE = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EXIT = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

--=============================================================================

-- Слой уведомлений выше любого всплывающего окна: сообщение обязано быть видно.
-- Число берём у общей таблицы порядка слоёв (см. NierUI.layers в Util) -- здесь
-- оно стояло голой двухсоткой, а знали о ней ещё два файла комментариями.
local function ensureLayer(window)
    if window.notifyLayer then return window.notifyLayer end

    window.notifyLayer = U.new("Frame", {
        BackgroundTransparency = 1, Active = false,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -EDGE, 0, EDGE),
        Size = UDim2.fromOffset(THEME.NotifyWidth, 0),
        ZIndex = NierUI.layers.notify,
    }, window.gui)

    return window.notifyLayer
end

-- Пересчёт стопки. X берётся у самой записи: за него отвечает выезд и уход, и
-- пересчёт не должен его затирать.
local function reflow(window)
    local y = 0
    for _, entry in ipairs(window.notifications) do
        if entry.card.Parent then
            TweenService:Create(entry.card, MOVE, {
                Position = UDim2.fromOffset(entry.x, y),
            }):Play()
            y = y + entry.card.AbsoluteSize.Y + GAP
        end
    end
end

--=============================================================================

function Window:Notify(opts)
    opts = opts or {}

    local width = THEME.NotifyWidth
    local duration = tonumber(opts.Duration) or THEME.NotifyDuration
    local layer = ensureLayer(self)
    local z = NierUI.layers.notify

    -- Стартовая позиция -- за краем экрана: слой отбит от края на EDGE, значит
    -- сдвиг на ширину плюс этот отступ выводит карточку ровно за экран.
    local offscreen = width + EDGE

    local card = U.new("Frame", {
        BackgroundColor3 = THEME.Bg, BorderSizePixel = 0, Active = false,
        Position = UDim2.fromOffset(offscreen, 0),
        Size = UDim2.fromOffset(width, 0),
        ZIndex = z, ClipsDescendants = true,
    }, layer)
    local line = U.stroke(card, 1)

    local top = PAD
    local titleLabel
    if opts.Title then
        titleLabel = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = tostring(opts.Title), TextColor3 = THEME.InkSoft, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(PAD, top),
            Size = UDim2.new(1, -PAD * 2, 0, 12), ZIndex = z + 1,
        }, card)
        top = top + 15
    end

    local body = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = tostring(opts.Text or ""), TextColor3 = THEME.Ink,
        TextSize = THEME.TextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(PAD, top),
        Size = UDim2.new(1, -PAD * 2, 0, 0), ZIndex = z + 1,
    }, card)

    -- Полоска остатка: живёт ровно duration и убывает линейно, поэтому по ней
    -- видно, сколько сообщение ещё провисит.
    local bar = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        BackgroundTransparency = 0.35,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, BAR), ZIndex = z + 2,
    }, card)

    -- abandon заполняется ниже: это способ для ClearNotifications погасить
    -- карточку изнутри, не разбираясь в её внутренностях.
    local entry = { card = card, x = 0, abandon = false }
    table.insert(self.notifications, entry)

    -- Высота карточки -- по фактической высоте текста. Пересчитывается по
    -- событию, потому что на кадре создания она ещё нулевая.
    local sizeConn
    sizeConn = body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if not card.Parent then return end
        card.Size = UDim2.fromOffset(width, top + body.AbsoluteSize.Y + PAD + BAR)
        reflow(self)
    end)

    card.Size = UDim2.fromOffset(width, top + body.TextBounds.Y + PAD + BAR)
    reflow(self)

    --== уход ================================================================
    --
    -- Гаснет ВСЁ разом и одним TweenInfo: подложка, рамка, обе подписи и
    -- полоска. Раньше гасились только подложка и текст -- рамка с заголовком
    -- оставались висеть в воздухе, пока карточка уезжала.

    local gone = false

    -- Бросить карточку: пометить ушедшей и снять подписку на высоту.
    --
    -- Подписку здесь снимать ОБЯЗАТЕЛЬНО. ClearNotifications уничтожает карточку
    -- сам, мимо destroy, и раньше взводил только пометку -- sizeConn оставался
    -- висеть на теле уничтоженной карточки. Одна забытая подписка на каждое
    -- показанное сообщение, а сообщений за сеанс сотни.
    local function abandon()
        gone = true
        if sizeConn then
            sizeConn:Disconnect()
            sizeConn = nil
        end
    end
    entry.abandon = abandon

    local function destroy()
        abandon()
        for i = #self.notifications, 1, -1 do
            if self.notifications[i] == entry then table.remove(self.notifications, i) end
        end
        if card.Parent then card:Destroy() end
        reflow(self)
    end

    -- Через abandon, а не своим `gone = true`: пометка и снятие подписки на
    -- высоту -- одно действие, и разводить его на два места значит однажды
    -- взвести одно без другого. Ровно этим и болел ClearNotifications.
    local function dismiss()
        if gone then return end
        abandon()
        if not card.Parent then
            destroy()
            return
        end

        entry.x = offscreen
        TweenService:Create(line, EXIT, { Transparency = 1 }):Play()
        TweenService:Create(body, EXIT, { TextTransparency = 1 }):Play()
        TweenService:Create(bar, EXIT, { BackgroundTransparency = 1 }):Play()
        if titleLabel then
            TweenService:Create(titleLabel, EXIT, { TextTransparency = 1 }):Play()
        end

        local slide = TweenService:Create(card, EXIT, {
            Position = UDim2.fromOffset(offscreen, card.Position.Y.Offset),
            BackgroundTransparency = 1,
        })
        -- Снос по завершении анимации, а не по отдельной задержке: та могла
        -- разъехаться с ней и оставить карточку висеть.
        slide.Completed:Connect(destroy)
        slide:Play()
    end

    TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0, 0, 0, BAR) }):Play()

    task.delay(duration, dismiss)

    return { Dismiss = dismiss, instance = card }
end

-- Снять все разом. Нужно выгрузке окна: карточки висят на ScreenGui, и без
-- этого отложенные задержки достались бы уже уничтоженным объектам.
--
-- Бросаем каждую явно, её же собственным механизмом. Карточка уничтожается
-- здесь, а отложенный dismiss на неё всё равно придёт -- и без пометки пошёл бы
-- уводить и хоронить то, чего уже нет. До сих пор его удерживала только
-- проверка card.Parent внутри, то есть случайность, а не намерение.
--
-- Через abandon, а не пометкой руками: вместе с пометкой снимается и подписка на
-- высоту карточки, а её здесь снять больше некому -- destroy отсюда не зовётся.
function Window:ClearNotifications()
    for i = #self.notifications, 1, -1 do
        local entry = self.notifications[i]
        if entry.abandon then entry.abandon() end
        if entry.card.Parent then entry.card:Destroy() end
        table.remove(self.notifications, i)
    end
end

end)(NierUI)

--============================ NierUI/Trigger.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Trigger -- условие снаружи, обработка внутри
--=============================================================================
--
--     win:Trigger({
--         Name = "join",
--         Signal = Players.PlayerAdded,          -- любой RBXScriptSignal
--         Filter = function(p) return p ~= me end,   -- условие пишет юзер
--         Message = function(p) return p.Name .. " зашёл" end,
--         Title = "PLAYER",
--         Action = function(p) list:Refresh(...) end,
--         Enabled = true,
--         Flag = "notifyJoin",
--     })
--
-- Возвращает handle: :Enable(), :Disable(), :IsEnabled(), :Fire(...).
--
--
-- ГДЕ ЗДЕСЬ ГРАНИЦА
--
-- Библиотека НЕ ЗНАЕТ, что такое игрок, вход и выход. Ей передают сигнал и
-- предикат -- она берёт на себя ровно три вещи, которые иначе пришлось бы
-- писать заново на каждый случай:
--
--   ВРЕМЯ ЖИЗНИ. Подписка живёт в окне и гаснет вместе с ним. Собственный
--     коннект пользователя пережил бы Destroy и остался бы висеть -- ровно тот
--     класс утечки, на котором мы горели трижды.
--
--   ВЫКЛЮЧАТЕЛЬ. У триггера есть состояние, которое можно завести на Flag и
--     тем самым сохранить в профиль. Выключенный триггер не отписывается, а
--     перестаёт срабатывать: переподписка на каждый щелчок тумблера -- лишний
--     способ потерять сигнал.
--
--   ПОКАЗ. Есть Message -- будет уведомление. Нет -- не будет. Пользователю не
--     нужно знать, как устроен слой сообщений.
--
-- Всё остальное -- откуда сигнал, что считать событием, что делать сверх
-- уведомления -- пишет тот, кто триггер объявляет.
--
--
-- ПОЧЕМУ ТОЛЬКО СИГНАЛЫ, А НЕ УСЛОВИЯ-ПРОВЕРКИ
--
-- Напрашивается Condition = function() return hp < 20 end с опросом каждый
-- кадр. Этого здесь нет намеренно: опрос -- это цикл, а библиотека держится на
-- том, что в ней нет ни одного постоянного потока. Нужен опрос -- заведите его
-- снаружи и дёргайте handle:Fire(), обработка та же.

local Window = NierUI.WindowClass

function Window:Trigger(opts)
    opts = opts or {}

    -- Имя нужно ровно для одного -- сказать в предупреждении, ЧЕЙ обработчик
    -- упал. Реестра «имя -> триггер» здесь больше нет: он только заполнялся и
    -- не читался никем, а найти триггер по имени было нечем -- метода наружу не
    -- существовало. Ручку и так возвращает сам вызов, держать её вторую копию
    -- незачем.
    --
    -- Счётчик, а не длина реестра: у отображения имя -> обработчик нет числовой
    -- части, и # всегда давал ноль -- все безымянные получали одно «trigger1».
    self.triggerSeq = self.triggerSeq + 1

    local trigger = {
        name = opts.Name or ("trigger" .. self.triggerSeq),
        enabled = opts.Enabled ~= false,
    }

    -- Само срабатывание: сперва выключатель, потом условие, потом показ.
    -- Порядок важен -- выключенный триггер не должен даже вычислять предикат,
    -- он может быть дорогим.
    local function fire(...)
        if not trigger.enabled then return end

        if opts.Filter then
            local ok, pass = pcall(opts.Filter, ...)
            if not ok or not pass then return end
        end

        if opts.Message then
            local ok, text = pcall(opts.Message, ...)
            if ok and text ~= nil and text ~= "" then
                self:Notify({
                    Text = tostring(text),
                    Title = opts.Title,
                    Duration = opts.Duration,
                })
            end
        end

        if opts.Action then
            local ok, err = pcall(opts.Action, ...)
            if not ok then
                warn(("[NierUI] триггер %s: %s"):format(trigger.name, tostring(err)))
            end
        end
    end

    if opts.Signal then
        -- В window.conns, а не в собственный список: триггеры живут столько
        -- же, сколько окно, и гаснут одним махом в Destroy.
        table.insert(self.conns, opts.Signal:Connect(fire))
    end

    local handle = {
        Fire = function(_, ...) fire(...) end,
        Enable = function(_) trigger.enabled = true end,
        Disable = function(_) trigger.enabled = false end,
        IsEnabled = function(_) return trigger.enabled end,
        -- Пара Get/Set -- чтобы триггер сохранялся в профиль как обычный
        -- переключатель, без отдельной ветки в конфиге.
        Get = function(_) return trigger.enabled end,
        Set = function(_, on) trigger.enabled = on and true or false end,
    }

    NierUI.bindFlag(self, opts.Flag, handle, 2, opts.Save)

    return handle
end

end)(NierUI)

--============================ NierUI/Popup.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Popup -- всплывающее окно поверх всего
--=============================================================================
--
-- ЗАЧЕМ ОТДЕЛЬНЫЙ СЛОЙ
--
-- Страница вкладки -- это ScrollingFrame, он обрезает всё, что выходит за его
-- границы. Раскрывающиеся блоки живут внутри строки и обрезаются вместе с ней:
-- правильно для списка, но не годится для окошка, которое должно вылезать за
-- пределы меню. Поэтому окна вешаются на сам ScreenGui и позиционируются в
-- экранных координатах.
--
--
--=============================================================================
-- ПОЧЕМУ ЗАКРЫТИЕ НЕ НА КНОПКЕ-ФОНЕ
--=============================================================================
--
-- Сначала под окном лежала прозрачная кнопка во весь экран с MouseButton1Click
-- на закрытие. Это оказалось неработоспособно, и по двум причинам сразу:
--
--   1. Click срабатывает на ОТПУСКАНИИ. Выбираешь цвет, ведёшь курсор, отпускаешь
--      чуть мимо панели -- окно закрывается прямо в момент выбора. Именно это и
--      ломало палитру: выбрать цвет было невозможно.
--
--   2. Окно создаётся В ОБРАБОТЧИКЕ Click, то есть на отпускании. Свежая кнопка
--      фона успевала получить то же самое отпускание и закрыть окно, едва оно
--      появилось.
--
-- Теперь закрытие -- по НАЖАТИЮ мимо панели, с собственной проверкой попадания,
-- и с явным взведением: пока кнопка мыши, которой окно открыли, ещё не
-- отпущена, окно закрыть нельзя. Проверяем состояние кнопки прямо при создании,
-- а не гадаем по таймеру.
--
-- Кнопка-фон осталась, но теперь у неё одна работа -- ПОГЛОЩАТЬ щелчки, чтобы
-- нажатие мимо окна не проваливалось в меню под ним. Правую кнопку она тоже
-- поглощает, и разделить их у GuiButton нечем -- поэтому правая обрабатывается
-- на уровне окна, минуя дерево (см. Context).
--
--
--=============================================================================
-- ОКОН МОЖЕТ БЫТЬ НЕСКОЛЬКО, И ОНИ БЫВАЮТ ДВУХ РАЗНЫХ РОДОВ
--=============================================================================
--
-- Раньше правило было одно: отзывается только ВЕРХНЕЕ окно. Оно решало ровно
-- один случай -- палитра поверх настроек, -- и решало его ценой того, что
-- независимых окон существовать не могло в принципе.
--
-- Теперь окна связаны родством: Owner говорит, из какого окна открыто это.
-- Палитра -- ребёнок настроек, настройки двух разных пунктов -- ровня друг
-- другу. Отсюда правило:
--
--   щёлкнули ВНУТРИ окна   -- закрываются только те, что открыты ИЗ НЕГО;
--                             само оно и его соседи остаются;
--   щёлкнули В ПУСТОТУ     -- закрывается всё.
--
-- Прежнее поведение получается из этого само: у палитры и настроек родство
-- есть, значит щелчок в палитре настройки не трогает.
--
-- Подписка на закрытие ОДНА НА ОКНО, а не по одной на всплывающее: при пяти
-- открытых окнах пять обработчиков делали бы одну и ту же работу пять раз.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local THEME = NierUI.Theme
local U = NierUI.util
local Window = NierUI.WindowClass

local TITLE_H = THEME.PopupTitleHeight

local GAP = 6

-- Порядок слоёв -- NierUI.layers, объявлен в Util. Размер экрана -- там же,
-- NierUI.viewport(). И то и другое читают полдюжины файлов, часть из которых
-- собирается РАНЬШЕ этого, -- значит место им в общем начале, а не здесь.
local LAYERS = NierUI.layers

--=============================================================================
-- ПЕРЕХВАТЧИК ОДИН НА ВСЮ СТОПКУ, А НЕ ПО ОДНОМУ НА ОКНО
--=============================================================================
--
-- Сперва каждое окно несло собственную прозрачную кнопку во весь экран, на
-- своём слое. Пока окно было одно, разницы не было никакой.
--
-- Со вторым окном это сломалось сразу и наглухо: слои идут по возрастанию
-- (100, 110, ...), и перехватчик ВЕРХНЕГО окна ложится поверх ПАНЕЛИ нижнего.
-- Нижнее окно остаётся видимым, выглядит совершенно рабочим и не отзывается ни
-- на что -- щелчки до него просто не доходят.
--
-- Работа у перехватчика ровно одна: не пускать щелчок в меню под стопкой.
-- Значит и слой ему нужен один, ниже любой панели. Панели начинаются с
-- layers.popup, перехватчик стоит на layers.shade -- каждая из них выше него, и
-- все они нажимаются.

local function ensureShade(window)
    if window.popupShade then return end
    window.popupShade = U.new("TextButton", {
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1), ZIndex = LAYERS.shade, Name = U.randomName(),
    }, window.gui)
end

local function dropShade(window)
    if not window.popupShade then return end
    pcall(function() window.popupShade:Destroy() end)
    window.popupShade = false
end

--=============================================================================
-- ОДНА ПАНЕЛЬ НА ДВА СЛУЧАЯ: ВСПЛЫВАЮЩЕЕ ОКНО И ПОСТОЯННЫЙ СЛОЙ
--=============================================================================
--
-- Постоянный слой (см. Panel.Show) -- это то же самое окно, только его никто не
-- закрывает щелчком мимо. Полоса заголовка, окно просмотра и перетаскивание у
-- них были написаны ДВАЖДЫ, слово в слово, и один раз уже разошлись: слой
-- держал страницу в простом кадре, и список из полутора десятков привязок
-- обрывался на середине и не двигался.
--
-- Поэтому три приёма ниже -- общие. Разница между окном и слоем остаётся ровно
-- там, где она настоящая: кто создал кадр и что его закрывает.

-- Полоса заголовка: подпись и черта под ней.
function NierUI.popupTitle(parent, text, z)
    U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = text, TextColor3 = THEME.InkSoft, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 12),
        ZIndex = z,
    }, parent)
    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        BackgroundTransparency = 0.65,
        Position = UDim2.fromOffset(0, TITLE_H), Size = UDim2.new(1, 0, 0, 1),
        ZIndex = z,
    }, parent)
end

-- ОКНО ПРОСМОТРА ПРОКРУЧИВАЕТСЯ ВСЕГДА.
--
-- Высота панели зажата экраном, значит содержимое выше экрана обязано
-- прокручиваться -- иначе оно просто обрезается по ClipsDescendants, и до нижних
-- строк не добраться ничем.
--
--   Top     сколько отдать полосе заголовка;
--   Active  поглощать ли ввод. Всплывающему это нужно (тянуть содержимое
--             пальцем), постоянному слою -- нельзя: его самого таскают мышью за
--             пустое место, а поглощающий потомок забрал бы у него нажатие
--             целиком. Колесо прокручивает и без этого;
--   Canvas  заданная высота холста; без неё считается по содержимому.
function NierUI.popupScroll(parent, opts)
    return U.new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Active = opts.Active or false,
        Position = UDim2.fromOffset(0, opts.Top),
        Size = UDim2.new(1, 0, 1, -opts.Top),
        CanvasSize = opts.Canvas and UDim2.fromOffset(0, opts.Canvas) or UDim2.new(),
        AutomaticCanvasSize = opts.Canvas and Enum.AutomaticSize.None
            or Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 2, ScrollBarImageColor3 = THEME.Ink,
        ScrollBarImageTransparency = 0.4,
        ZIndex = opts.ZIndex,
    }, parent)
end

-- ПЕРЕТАСКИВАНИЕ.
--
-- Всплывающее окно тянут за полосу заголовка, постоянный слой -- за любое
-- пустое место: полосы у него может и не быть вовсе, а таскать его надо.
-- Виджеты внутри щелчок съедают сами, поэтому по ним слой не поедет.
--
--   conns       куда сложить подписки: у окна свои, у слоя -- сток контейнера;
--   Grip        сколько ВЕРХНИХ пикселей кадра считать ручкой. Без неё ручка --
--                 весь кадр. Ниже полосы заголовка лежат строки настроек, и
--                 таскать за них значило бы мешать нажатиям;
--   OnMove(x,y) если положение надо запомнить.
function NierUI.dragFrame(conns, frame, opts)
    opts = opts or {}
    local grip = opts.Grip or false
    local onMove = opts.OnMove or false

    local dragging, dragStart, startPos = false, nil, nil

    table.insert(conns, frame.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if grip and input.Position.Y > frame.AbsolutePosition.Y + grip then return end
        dragging, dragStart, startPos = true, input.Position, frame.Position
    end))

    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = input.Position - dragStart
        -- Округляем: дробная позиция размазывает однопиксельные линии между
        -- соседними пикселями, и рамка начинает выглядеть неровной.
        local x = math.floor(startPos.X.Offset + delta.X + 0.5)
        local y = math.floor(startPos.Y.Offset + delta.Y + 0.5)
        frame.Position = UDim2.fromOffset(x, y)
        if onMove then onMove(x, y) end
    end))

    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
end

--=============================================================================
-- РАСКЛАДКА: ОКНА НЕ НАЛЕЗАЮТ ДРУГ НА ДРУГА
--=============================================================================
--
-- Каждое окно встаёт рядом со своей строкой, а строки идут через 26 пикселей --
-- то есть настройки двух соседних пунктов открывались почти на одном месте и
-- перекрывали друг друга. Сравнить их было так же нельзя, как и раньше, только
-- теперь по другой причине.
--
-- Поэтому положение от якоря -- это ПОЖЕЛАНИЕ. Если оно занято, окно съезжает
-- под то, с чем столкнулось; кончилось место по высоте -- начинает следующую
-- колонку правее. Считаем в системе Position (смещение от верха экрана), а не в
-- AbsolutePosition: у окна IgnoreGuiInset, и эти две системы разъезжаются на
-- высоту верхней панели.

local function overlaps(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and bx < ax + aw
       and ay < by + bh and by < ay + ah
end

local function freeSpot(window, x, y, width, height, view)
    local minX, maxX = 4, math.max(4, view.X - width - 4)
    local minY, maxY = 4, math.max(4, view.Y - height - 4)

    local baseX = math.clamp(x, minX, maxX)
    local startY = math.clamp(y, minY, maxY)

    x, y = baseX, startY
    local column = 0

    for _ = 1, 60 do
        local moved = false
        for _, other in ipairs(window.popups) do
            local at = other.panel.Position
            local size = other.panel.AbsoluteSize
            if overlaps(x, y, width, height,
                at.X.Offset, at.Y.Offset, size.X, size.Y) then
                y = at.Y.Offset + size.Y + GAP
                moved = true
            end
        end
        if not moved then break end

        if y > maxY then
            column = column + 1
            if column > 6 then break end
            x = baseX + column * (width + GAP)
            y = startY
            -- Правее экрана уже некуда -- кладём как есть, внахлёст. Лучше
            -- окно на чужом месте, чем окно за краем экрана.
            if x > maxX then break end
        end
    end

    return math.clamp(x, minX, maxX), math.clamp(y, minY, maxY)
end

--=============================================================================
-- Закрытие: один разбор на всё окно
--=============================================================================

-- Открыто ли entry из host -- по цепочке родителей.
-- Шаг цепочки владельцев. «Владельца нет» хранится как false, и U.chain
-- обрывается на нём наравне с nil.
local function ownerOf(entry) return entry.owner end

local function descends(entry, host)
    for node in U.chain(entry.owner, ownerOf) do
        if node == host then return true end
    end
    return false
end

-- Окно стопки, накрывающее точку. Последнее накрывающее и есть ВЕРХНЕЕ: окна
-- лежат в порядке создания, позже созданное выше.
--
-- Спрашивают двое -- закрытие щелчком (здесь) и разбор правой кнопки (см.
-- Context), -- и обход у них был дословно один и тот же. Ответ отдаём записью, а
-- не панелью: Context спросит .panel сам, а обратно из панели в запись пути нет.
function NierUI.popupAt(window, point)
    local host = false
    for _, entry in ipairs(window.popups) do
        if U.inside(entry.panel, point) then host = entry end
    end
    return host
end

local function dismiss(window, point)
    local host = NierUI.popupAt(window, point)

    for i = #window.popups, 1, -1 do
        local entry = window.popups[i]
        -- armed: окно не закрывается тем же щелчком, которым его открыли.
        if entry.armed and entry ~= host
            and (not host or descends(entry, host)) then
            pcall(entry.close)
        end
    end
end

local function ensureDismiss(window)
    if window.popupInput then return end
    -- ХОЗЯИН У ПОДПИСКИ ОДИН -- window.conns. Здесь же лежал ВТОРОЙ список с
    -- теми же двумя коннектами, и читали его только затем, чтобы переложить их в
    -- оконный сток; снять их через него не пытался никто. Поле осталось ровно
    -- тем, чем и было по смыслу, -- пометкой «разбор уже стоит».
    window.popupInput = true

    local conns = {
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            for _, entry in ipairs(window.popups) do entry.armed = true end
        end),

        UserInputService.InputBegan:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.Escape then
                local top = window.popups[#window.popups]
                -- holdEscape поднимает тот, кому Escape нужен самому: захват
                -- клавиши отменяется им же, и закрывать заодно окно нельзя.
                --
                -- Пометка на записи работает, только когда ждёт САМО это окно.
                -- Привязка внутри меню правой кнопки (m:Keybind) о записи не
                -- знает вовсе -- она обычная строка обычного контейнера, -- и
                -- Escape закрывал меню вместо того, чтобы отменить захват.
                -- Общий признак закрывает и этот случай.
                if top and not top.holdEscape
                    and not NierUI.keyGrabbed(window) then
                    pcall(top.close)
                end
                return
            end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            dismiss(window, input.Position)
        end),
    }

    -- В window.conns: подписка живёт столько же, сколько окно, и гаснет в
    -- Destroy вместе со всем остальным.
    for _, conn in ipairs(conns) do
        table.insert(window.conns, conn)
    end
end

function Window:Popup(opts)
    opts = opts or {}

    -- Слой каждого следующего окна выше предыдущего, но не бесконечно: выше
    -- живут уведомления (layers.notify), и десяток открытых окон не должен их
    -- накрывать. Упёршись в потолок, окна остаются на равных номерах, а порядок
    -- между ними решает очерёдность создания -- позже созданное и так сверху.
    local depth = math.min(#self.popups, 8)
    local base = LAYERS.popup + depth * 10

    local width = opts.Width or 200
    local height = opts.Height or 120

    -- ДВЕ СИСТЕМЫ ОТСЧЁТА -- ПОПРАВКА ЗДЕСЬ, А НЕ У ВЫЗЫВАЮЩИХ.
    --
    -- X и Y сюда приходят из AbsolutePosition якоря -- иначе и неоткуда, у
    -- строки другого адреса нет. Но у окна IgnoreGuiInset = true, и смещение в
    -- Position считается от НАСТОЯЩЕГО верха экрана, тогда как AbsolutePosition
    -- сообщается от границы под верхней панелью.
    --
    -- Замерено: панель 58 пикселей, и ровно на столько всплывающие окна вставали
    -- выше своей строки. Настройки тумблера ПОЛЁТ открывались над ним, а не
    -- рядом -- достаточно близко, чтобы полгода не вызывать вопросов.
    --
    -- Поправку делаем в одном месте: вызывающих у Popup много, и повторять её в
    -- каждом значит однажды забыть.
    local inset = GuiService:GetGuiInset()

    -- Держим окно в пределах экрана: открытое у нижнего края меню иначе
    -- уезжает за экран целиком.
    local view = NierUI.viewport()

    --== где встать ==========================================================
    --
    -- ЗАПОМНЕННОЕ ПОЛОЖЕНИЕ СИЛЬНЕЕ ЛЮБОЙ РАСКЛАДКИ.
    --
    -- Окно, которое перетащили руками, обязано открываться там, куда его
    -- поставили: человек двигал его не случайно, а чтобы оно не мешало. Место
    -- у якоря и объезд чужих окон -- это то, что делается ЗА него, пока он сам
    -- ничего не сказал.

    local x, y
    local place = opts.Place and self.popupPlaces[opts.Place]
    if place then
        x = math.clamp(place.X, 4, math.max(4, view.X - width - 4))
        y = math.clamp(place.Y, 4, math.max(4, view.Y - height - 4))
    else
        x, y = freeSpot(self,
            (opts.X or 0) + inset.X, (opts.Y or 0) + inset.Y,
            width, height, view)
    end

    local layer = U.new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        ZIndex = base, Name = U.randomName(),
    }, self.gui)

    ensureShade(self)

    -- Active = true: панель обязана поглощать щелчок, иначе нажатие по её
    -- пустому месту проваливается в меню под окном.
    local panel = U.new("Frame", {
        BackgroundColor3 = THEME.Bg, BorderSizePixel = 0, Active = true,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, height),
        ZIndex = base + 1, ClipsDescendants = true,
    }, layer)
    U.stroke(panel, 1)

    if opts.Title then NierUI.popupTitle(panel, opts.Title, base + 2) end

    local conns = {}
    local closed = false

    local entry

    local function close()
        if closed then return end
        closed = true

        -- СООБЩАЕМ ДО ТОГО, КАК ЧТО-ЛИБО УНИЧТОЖЕНО.
        --
        -- Сначала OnClose стоял в самом конце -- логично казалось сообщать о
        -- свершившемся факте. Но содержимое окна не обязано ему принадлежать:
        -- контейнер (см. Panel) кладёт внутрь свою страницу и забирает её
        -- обратно при закрытии, чтобы построенные виджеты пережили окно.
        --
        -- Destroy у слоя рекурсивен и запирает Parent у всех потомков. Успей он
        -- раньше -- страница вместе со всеми виджетами уничтожалась бы вместе с
        -- окном, а забрать её было бы уже нельзя: «The Parent property is
        -- locked, current parent: NULL».
        --
        -- Порядок обратный: сперва отдать чужое, потом убирать своё.
        if opts.OnClose then pcall(opts.OnClose) end

        -- ЗАКРЫЛСЯ РОДИТЕЛЬ -- ЗАКРЫЛИСЬ И ДЕТИ.
        --
        -- Палитра открыта ИЗ окна настроек и без него не значит ничего: под ней
        -- больше нет ни строки, которую она красит, ни места, к которому она
        -- привязана. Оставшись одна, она висит сиротой и продолжает править
        -- настройку окна, которого уже нет.
        -- Через descends, а не своим обходом: цепочка владельцев тут
        -- перебиралась вторым, дословно повторяющим её экземпляром. Две копии
        -- одного правила -- это два разных ответа на вопрос «чьё это окно»
        -- через месяц.
        for i = #self.popups, 1, -1 do
            local other = self.popups[i]
            if descends(other, entry) then pcall(other.close) end
        end

        NierUI.drain(conns)
        pcall(function() layer:Destroy() end)
        for i = #self.popups, 1, -1 do
            if self.popups[i].close == close then table.remove(self.popups, i) end
        end
        -- Ушло последнее -- перехватчику больше нечего стеречь. Оставить его
        -- значило бы накрыть меню невидимой кнопкой навсегда.
        if #self.popups == 0 then dropShade(self) end
    end

    -- Взводим сразу, если кнопка мыши уже отпущена; иначе -- по её отпусканию.
    -- Так окно не закроется тем же самым щелчком, которым его открыли, и при
    -- этом не нужен ни таймер, ни задержка.
    entry = {
        close = close, panel = panel,
        -- Owner приходит панелью, а хранится записью: вызывающему проще отдать
        -- то, что ему вернули из Popup, чем помнить ещё и внутреннюю запись.
        owner = false,
        armed = not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1),
        holdEscape = false,
    }

    if opts.Owner then
        for _, other in ipairs(self.popups) do
            if other.panel == opts.Owner then entry.owner = other end
        end
    end

    table.insert(self.popups, entry)
    ensureDismiss(self)

    --== перетаскивание ======================================================
    --
    -- За полосу заголовка -- отсюда Grip. Сам приём общий с постоянным слоем,
    -- см. NierUI.dragFrame.

    -- Запоминаем сразу, а не по отпусканию: до отпускания дело может и не
    -- дойти -- окно закроют щелчком мимо прямо во время перетаскивания, и
    -- тогда оно вернулось бы на прежнее место, будто его и не двигали.
    local remember = false
    if opts.Place then
        remember = function(nx, ny)
            self.popupPlaces[opts.Place] = Vector2.new(nx, ny)
        end
    end

    NierUI.dragFrame(conns, panel, { Grip = TITLE_H, OnMove = remember })

    return panel, close, conns, base + 2, entry
end

function Window:ClosePopups()
    for i = #self.popups, 1, -1 do
        pcall(self.popups[i].close)
    end
    self.popups = {}
end

end)(NierUI)

--============================ NierUI/Panel.luau ============================
;(function(NierUI)
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

end)(NierUI)

--============================ NierUI/Hud.luau ============================
;(function(NierUI)
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
        -- Сглаженное число кадров -- ЧТЕНИЕ, и пары ему не полагается.
        --
        -- Рядом стояло `Set = function(_, on) return on end` -- заглушка, которая
        -- ничего не делает, но выглядит настоящей парой к Get. Заведи кто-нибудь
        -- этот handle на Flag -- и профиль честно сохранял бы число кадров, а при
        -- загрузке молча его терял. В профиль от худа уходит ПОЛОЖЕНИЕ, и пара
        -- Get/Set для него своя, см. placeHandle.
        Get = function(_) return smooth end,
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
-- вопрос отвечает (см. Binds). Ни поиска владельца по разметке, ни дописанного
-- руками состояния, ни запасных вариантов.
--
-- Кто этот хозяин -- забота объявления, а не списка. Им бывает строка, сама
-- запись или фича снаружи (State у привязки), и здесь эта разница не видна
-- вовсе: вопрос один и тот же, Get.
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

end)(NierUI)

--============================ NierUI/Context.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Context -- диспетчер правой кнопки
--=============================================================================
--
-- ПОЧЕМУ НЕ MouseButton2Click НА САМОМ ЭЛЕМЕНТЕ
--
-- У всплывающего окна есть фон-перехватчик во весь экран (см. Popup): он
-- поглощает щелчки, чтобы нажатие мимо окна не проваливалось в меню под ним.
-- Поглощает он их ВСЕ, включая правую кнопку -- разделить их у GuiButton
-- нечем. Значит пока открыто хоть одно окно настроек, ни один элемент меню
-- правую кнопку больше не получает: MouseButton2Click на строке просто не
-- срабатывает.
--
-- Отсюда следовало неприятное: настройки открывались строго по одному. Чтобы
-- посмотреть второй пункт, надо было закрыть первый, а положить рядом настройки
-- двух пунктов и сравнить их было нельзя вовсе.
--
-- Заодно отсюда следовало, что «повторный ПКМ откроет второе такое же окно» --
-- не баг: второго нажатия по строке просто не бывает. Ограничитель не нужен,
-- его роль уже играет перехватчик.
--
-- Поэтому правая кнопка обрабатывается НЕ элементом, а окном. UserInputService
-- получает нажатие независимо от того, кто его поглотил, а кому оно
-- предназначалось, мы вычисляем сами. Перехватчик остаётся на месте и
-- по-прежнему стережёт левую кнопку -- меняется только адресат правой.
--
--
-- ПОПАДАНИЕ СЧИТАЕТСЯ ЧЕСТНО, А НЕ ПО ПРЯМОУГОЛЬНИКУ
--
-- Один U.inside по самому элементу недостаточен: строка может лежать в
-- свёрнутой секции, на неактивной вкладке или быть отпрокрученной за край
-- блока -- прямоугольник у неё при этом остаётся вполне настоящий. Поэтому
-- проверяется вся цепочка родителей: видимость каждого и попадание в каждого,
-- кто обрезает содержимое.
--
-- ScrollingFrame обрезает ВСЕГДА, независимо от ClipsDescendants, -- иначе
-- пункт списка, уехавший за край, продолжал бы ловить правую кнопку.

local U = NierUI.util

--=============================================================================
-- Реестр
--=============================================================================
--
-- open(onClosed) -> close | nil
--
-- Возврат nil означает «открывать нечего» (у элемента нет настроек, он выключен)
-- -- цель остаётся в реестре и просто молчит.
--
--
-- height -- СКОЛЬКО ВЕРХНИХ ПИКСЕЛЕЙ ЭЛЕМЕНТА СЧИТАТЬ ЦЕЛЬЮ
--
-- Строка не всегда равна себе: у списка и палитры раскрытая панель лежит ВНУТРИ
-- строки и растит её (см. makePanel). Прямоугольник строки при этом накрывает и
-- панель, а значит правая кнопка по раскрытой палитре попала бы в саму строку и
-- открыла её настройки -- при том что метили в палитру.
--
-- Раньше этого не случалось по случайности: панель поглощала щелчок раньше, чем
-- он доходил до строки-кнопки. Теперь адресата считаем мы, и случайность надо
-- заменить намерением. Строка отдаёт высоту своей ПЕРВОЙ строки -- ровно ту, на
-- которой нарисована метка настроек; всё, что ниже, ей уже не принадлежит.
--
-- nil -- цель занимает элемент целиком (пункт списка, кнопка).

function NierUI.contextTarget(window, frame, open, height)
    local target = { frame = frame, open = open, close = false, height = height or false }
    table.insert(window.m2, target)
    return target
end

-- Снять цель. Обязательно для пунктов списка: они пересобираются на каждое
-- изменение источника и на каждую букву в поиске, и без снятия реестр рос бы
-- неограниченно -- ровно тот класс утечки, ради которого у списка заведён
-- собственный itemConns.
function NierUI.contextForget(window, frame)
    for i = #window.m2, 1, -1 do
        local target = window.m2[i]
        if target.frame == frame then
            if target.close then pcall(target.close) end
            table.remove(window.m2, i)
        end
    end
end

--=============================================================================
-- Попадание
--=============================================================================

-- Шаг цепочки. Объявлен один раз на модуль, а не создаётся при каждом подъёме:
-- попадание считается на каждый щелчок правой кнопкой.
local function parentOf(node) return node.Parent end

local function reachable(target, point)
    local frame = target.frame
    if not U.inside(frame, point) then return false end
    -- Раскрытая панель растит строку, но целью не становится: см. height.
    if target.height and point.Y > frame.AbsolutePosition.Y + target.height then
        return false
    end

    for node in U.chain(frame, parentOf) do
        if not node:IsA("GuiObject") then break end
        if not node.Visible then return false end
        -- ScrollingFrame режет содержимое сам по себе, флага у него для этого
        -- нет: отпрокрученный за край пункт обязан считаться непопадаемым.
        if node.ClipsDescendants or node:IsA("ScrollingFrame") then
            if not U.inside(node, point) then return false end
        end
    end
    return true
end

-- Глубина в дереве. Вложенный элемент выигрывает у того, внутри которого он
-- лежит: пункт списка лежит в раскрытой панели, панель -- в строке, и обе
-- накрывают точку. Правая кнопка предназначалась пункту.
--
-- Глубина -- это ЧИСЛО ПРЕДКОВ, поэтому и считается перебором предков, начиная
-- с родителя. Прежний `while node and node.Parent` давал то же число окольным
-- путём: шагал по самому элементу и останавливался, не дойдя до корня.
local function depthOf(frame)
    local depth = 0
    for _ in U.chain(frame.Parent, parentOf) do depth = depth + 1 end
    return depth
end

--=============================================================================
-- Разбор нажатия
--=============================================================================

function NierUI.contextDispatch(window, point)
    -- Точка внутри открытого окна принадлежит ЕМУ, а не тому, что лежит под
    -- ним: окно непрозрачно, и строка под ним не видна. Кто именно накрыл --
    -- считает Popup: у закрытия щелчком мимо вопрос тот же самый, и обход стопки
    -- был написан здесь вторым, дословным экземпляром.
    local top = NierUI.popupAt(window, point)
    local host = top and top.panel or false

    local best, bestDepth = nil, -1
    for i = #window.m2, 1, -1 do
        local target = window.m2[i]
        -- Попутная уборка: элемент могли уничтожить, не сняв цель.
        if not target.frame.Parent then
            table.remove(window.m2, i)
        elseif reachable(target, point)
            and (not host or target.frame:IsDescendantOf(host)) then
            local depth = depthOf(target.frame)
            if depth > bestDepth then best, bestDepth = target, depth end
        end
    end

    if not best then return false end

    -- ПОВТОРНЫЙ ПКМ ПО ТОЙ ЖЕ ЦЕЛИ ЗАКРЫВАЕТ ЕЁ ОКНО.
    --
    -- Иначе теперь, когда перехватчик правую кнопку пропускает, второе нажатие
    -- честно открывало бы второе такое же окно поверх первого -- тот самый
    -- дубль, которого раньше не бывало только потому, что нажатие не доходило.
    if best.close then
        local close = best.close
        best.close = false
        pcall(close)
        return true
    end

    local opened = best.open(function() best.close = false end)
    best.close = opened or false
    return opened and true or false
end

end)(NierUI)

--============================ NierUI/Modal.luau ============================
;(function(NierUI)
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

end)(NierUI)

--============================ NierUI/OptionSettings.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- OptionSettings -- окошко настроек у отдельного пункта
--=============================================================================
--
-- Открывается правой кнопкой по пункту списка. Внутри -- по строке на каждую
-- настройку; цвет открывает палитру ВТОРЫМ окном поверх.
--
--
-- ТИП ВЫВОДИТСЯ ИЗ ЗНАЧЕНИЯ ПО УМОЛЧАНИЮ, А НЕ ЗАДАЁТСЯ ОТДЕЛЬНО
--
--     Settings = { NAMES = { Color = Color3.fromRGB(255,255,255), Outline = true } }
--
-- Color3 -- образец с палитрой, boolean -- переключатель, EnumItem -- захват
-- клавиши. Описывать тип вручную значило бы держать его в двух местах и
-- однажды разойтись.
--
-- Исключение одно -- ползунок. По голому числу диапазон не угадать, поэтому
-- ему нужна форма описания:
--
--     Settings = { ["ЗНАЧЕНИЕ"] = { Type = "Slider", Default = 1000,
--                                   Min = 1, Max = 999999, Step = 1 } }
--
-- Русское имя настройки -- ТОЛЬКО через ["..."]. Ключ без скобок разбирается как
-- идентификатор, а идентификаторы в Luau только из латиницы: { Цвет = ... } не
-- компилируется вовсе. Имя настройки человек видит в окошке, поэтому русские
-- имена тут дело обычное, и форма у них ровно такая.
--
-- В состоянии при этом лежит само число, а не описание: наружу и в профиль
-- уходит значение.
--
-- Порядок строк -- по алфавиту ключей. Порядок обхода хеша в Lua не определён,
-- и без сортировки настройки перемешивались бы при каждом открытии.

local UserInputService = game:GetService("UserInputService")

local THEME = NierUI.Theme
local U = NierUI.util

local ROW = THEME.RowHeight
local WIDTH = 220
-- Первая строка идёт под полосой заголовка всплывающего окна. Высоту полосы
-- берём у темы, а не повторяем числом: раньше здесь стояло 26 при полосе в 22,
-- и четыре пикселя расхождения существовали просто потому, что их никто не
-- сверял.
local TOP = THEME.PopupTitleHeight + 4

-- Начальное значение настройки. Для описания ползунка это его Default, для
-- всего остального -- само значение.
function NierUI.settingDefault(value)
    if type(value) == "table" and value.Type then return value.Default end
    return value
end

-- ПАРАМЕТРЫ ТАБЛИЦЕЙ, А НЕ ПОЗИЦИЯМИ
--
-- Их стало восемь, и позиционный список из восьми штук читается только со
-- счётом на пальцах -- а впереди ещё расширение меню правой кнопки, где их
-- станет больше. Вызывающих всего двое, переучивать некого.
--
--   Anchor   -- от какого элемента отсчитывать положение
--   Title    -- заголовок окошка
--   Spec     -- ключ -> значение по умолчанию
--   State    -- ключ -> текущее значение (меняется на месте)
--   OnChange -- function(key, value)
--   OnClose  -- зовётся, когда окно закрылось ЛЮБЫМ путём: щелчком мимо,
--               Escape, повторной правой кнопкой или ClosePopups. Без него тот,
--               кто держит ссылку на окно, считал бы его открытым вечно.
--   Place    -- ключ памяти положения. ДОЛЖЕН ПЕРЕЖИВАТЬ САМ ЭЛЕМЕНТ: пункты
--               списка пересобираются на каждую букву в поиске, и ключом по
--               кнопке память терялась бы ровно тогда, когда она нужна.
function NierUI.optionSettings(window, opts)
    local spec, state = opts.Spec, opts.State
    local anchor = opts.Anchor
    local onChange = opts.OnChange

    local keys = {}
    for key in pairs(spec) do keys[#keys + 1] = key end
    table.sort(keys)
    if #keys == 0 then return end

    -- ВЫСОТА ЗАЖИМАЕТСЯ ПО ЭКРАНУ, ОСТАЛЬНОЕ УХОДИТ В ПРОКРУТКУ.
    --
    -- Раньше она считалась как TOP + числом настроек, и только. Popup держит в
    -- пределах экрана ПОЛОЖЕНИЕ, но не размер, поэтому два десятка настроек
    -- давали окно выше экрана: нижние строки просто негде было показать, и
    -- добраться до них было нечем.
    local view = NierUI.viewport()

    local content = #keys * ROW + 8
    local room = math.max(ROW * 3, view.Y - 40 - TOP)
    local height = TOP + math.min(content, room)

    -- Взведённые захваты клавиши этого окна: строка -> чем отпустить. Он же и
    -- ответ на вопрос «ждёт ли эта строка клавишу»: второго признака у неё нет.
    --
    -- Нужны здесь, а не в самой строке, потому что окно могут закрыть ПРЯМО ВО
    -- ВРЕМЯ ожидания -- щелчком мимо, Escape, закрытием родителя. Подписки
    -- строки уходят вместе с окном, и отпустить захват стало бы некому: core.grab
    -- остался бы единицей навсегда, а с ним молчат ВСЕ привязки разом и клавиша
    -- открытия меню -- она проверяет keyGrabbed первым делом. Ни ошибки, ни
    -- следа в консоли.
    local grabs = {}

    local panel, close, conns, z, entry = window:Popup({
        Title = opts.Title,
        Width = WIDTH,
        Height = height,
        X = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + 6,
        Y = anchor.AbsolutePosition.Y,
        OnClose = function()
            for _, release in pairs(grabs) do release() end
            table.clear(grabs)
            if opts.OnClose then opts.OnClose() end
        end,
        Place = opts.Place,
    })

    -- Строки лежат в прокрутке, а не в самой панели: полоса заголовка обязана
    -- остаться на месте, за неё окно таскают.
    --
    -- Холст задаём числом, а не считаем по содержимому: строки здесь стоят
    -- смещением, а не раскладкой, и высота их известна заранее -- с запасом в
    -- восемь пикселей, чтобы последняя не упиралась в край.
    local body = NierUI.popupScroll(panel,
        { Top = TOP, ZIndex = z, Active = true, Canvas = content })

    for index, key in ipairs(keys) do
        local y = (index - 1) * ROW

        local rowBtn = U.new("TextButton", {
            BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false, Text = "",
            Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, ROW),
            ZIndex = z,
        }, body)

        local label = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = tostring(key), TextColor3 = THEME.Ink,
            TextSize = THEME.TextSize, TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -110, 1, 0),
            ZIndex = z + 1,
        }, rowBtn)

        local descriptor = spec[key]
        local isSlider = type(descriptor) == "table" and descriptor.Type == "Slider"

        -- ВИД СТРОКИ РЕШАЕТ ОБЪЯВЛЕНИЕ, А НЕ ТЕКУЩЕЕ ЗНАЧЕНИЕ.
        --
        -- Раньше ветка выбиралась по тому, что лежит в состоянии, -- и стоило
        -- клавише оттуда пропасть, как настройка меняла тип на глазах: снятая
        -- клавиша (false) превращала строку в переключатель. Тип объявлен один
        -- раз и не меняется, значит и спрашивать надо объявление.
        local declared = NierUI.settingDefault(descriptor)

        local current = state[key]
        if current == nil then current = declared end

        if isSlider then
            local min = descriptor.Min or 0
            local max = descriptor.Max or 100
            local stepSize = descriptor.Step or 1

            local span = (max > min) and (max - min) or 1

            local decimals = 0
            if stepSize < 1 then
                decimals = math.max(0, math.ceil(-math.log(stepSize, 10)))
            end
            local format = "%." .. decimals .. "f"
            local roundTo = 10 ^ decimals

            -- Строка тесная: название, дорожка и поле числа делят 220 пикселей.
            -- Название поэтому обрезается, а не растягивается под остальными.
            label.Size = UDim2.fromOffset(96, ROW)
            label.TextTruncate = Enum.TextTruncate.AtEnd

            local track = U.new("Frame", {
                BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
                BackgroundTransparency = 0.75, AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 112, 0, math.floor(ROW / 2)),
                Size = UDim2.fromOffset(50, 2), ZIndex = z + 1,
            }, rowBtn)
            local fill = U.new("Frame", {
                BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
                Size = UDim2.fromScale(0, 1),
            }, track)

            local box = U.new("TextBox", {
                BackgroundTransparency = 1, Font = THEME.Font,
                Text = "", TextColor3 = THEME.InkSoft, TextSize = THEME.TextSize,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextEditable = true, ClearTextOnFocus = false,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -10, 0, 0),
                Size = UDim2.fromOffset(0, ROW),
                AutomaticSize = Enum.AutomaticSize.X, ZIndex = z + 1,
            }, rowBtn)
            U.new("UISizeConstraint", { MinSize = Vector2.new(22, ROW) }, box)

            local editing = false

            local function render()
                local v = state[key] or min
                if not editing then box.Text = format:format(v) end
                fill.Size = UDim2.fromScale((v - min) / span, 1)
            end

            local function commit(v)
                state[key] = math.clamp(
                    math.floor(v * roundTo + 0.5) / roundTo, min, max)
                render()
                if onChange then pcall(onChange, key, state[key]) end
            end

            if state[key] == nil then state[key] = current or min end
            render()

            -- Тянуть можно только за дорожку. Строка занимает всю ширину окошка,
            -- и нажатие по названию швырнуло бы значение в минимум.
            local sliding = false
            table.insert(conns, rowBtn.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                local x = input.Position.X
                if x < track.AbsolutePosition.X - 6
                    or x > track.AbsolutePosition.X + track.AbsoluteSize.X + 6 then return end
                sliding = true
                commit(min + span * U.alongX(track, x))
            end))
            table.insert(conns, UserInputService.InputChanged:Connect(function(input)
                if not sliding then return end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                commit(min + span * U.alongX(track, input.Position.X))
            end))
            table.insert(conns, UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    sliding = false
                end
            end))

            -- Точное значение набирается руками: по дорожке в 56 пикселей в
            -- диапазон до миллиона не попасть.
            table.insert(conns, box.Focused:Connect(function() editing = true end))
            table.insert(conns, box.FocusLost:Connect(function()
                editing = false
                local typed = tonumber(box.Text)
                if typed then commit(typed) else render() end
            end))

            table.insert(conns, rowBtn.MouseEnter:Connect(function()
                rowBtn.BackgroundTransparency = 0
                label.TextColor3, box.TextColor3 = THEME.Bg, THEME.Bg
                track.BackgroundColor3, fill.BackgroundColor3 = THEME.Bg, THEME.Bg
            end))
            table.insert(conns, rowBtn.MouseLeave:Connect(function()
                rowBtn.BackgroundTransparency = 1
                label.TextColor3, box.TextColor3 = THEME.Ink, THEME.InkSoft
                track.BackgroundColor3, fill.BackgroundColor3 = THEME.Ink, THEME.Ink
            end))

        elseif typeof(declared) == "Color3" then
            local swatch = U.new("Frame", {
                BackgroundColor3 = current, BorderSizePixel = 0,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(34, 12),
                ZIndex = z + 1,
            }, rowBtn)
            local line = U.stroke(swatch, 1)

            table.insert(conns, rowBtn.MouseEnter:Connect(function()
                rowBtn.BackgroundTransparency = 0
                label.TextColor3 = THEME.Bg
                line.Color = THEME.Bg
            end))
            table.insert(conns, rowBtn.MouseLeave:Connect(function()
                rowBtn.BackgroundTransparency = 1
                label.TextColor3 = THEME.Ink
                line.Color = THEME.Ink
            end))

            -- ЛКМ по цвету -- палитра ВТОРЫМ окном. Её фон перехватывает
            -- щелчок мимо первым, поэтому закрывается только она, а настройки
            -- остаются открытыми.
            table.insert(conns, rowBtn.MouseButton1Click:Connect(function()
                -- Открываем СПРАВА от окна настроек, а не под курсором: так
                -- палитра гарантированно не ложится поверх той строки, из
                -- которой её вызвали, и её видно целиком.
                local field = 100
                local pad = 12
                local pickPanel, _, pickConns, pickZ = window:Popup({
                    Title = tostring(key),
                    Width = WIDTH,
                    Height = TOP + pad + field + NierUI.colorControlExtra + pad,
                    X = panel.AbsolutePosition.X + panel.AbsoluteSize.X + 6,
                    Y = rowBtn.AbsolutePosition.Y - 24,
                    -- Палитра -- РЕБЁНОК этих настроек, и это не украшение:
                    -- по родству решается, что закрывать щелчком. Щелчок в
                    -- настройках убирает палитру, но не их самих; щелчок в
                    -- палитре не трогает ничего; настройки соседнего пункта не
                    -- задеваются ни тем ни другим.
                    Owner = panel,
                    -- Палитре память положения нужна ровно как и самим
                    -- настройкам: её тоже отодвигают, чтобы видеть строку,
                    -- которую красят. Ключ -- от родителя плюс имя поля, чтобы
                    -- две палитры одного окна не делили одно место на двоих.
                    Place = opts.Place and (opts.Place .. "\0c\0" .. tostring(key)) or nil,
                })

                NierUI.colorControl(pickPanel, {
                    Position = UDim2.fromOffset(pad, TOP + pad),
                    Width = WIDTH - pad * 2, Height = field,
                    Color = state[key] or spec[key],
                    sink = pickConns,
                    ZIndex = pickZ,
                    Callback = function(c)
                        state[key] = c
                        swatch.BackgroundColor3 = c
                        if onChange then pcall(onChange, key, c) end
                    end,
                })
            end))

        elseif typeof(declared) == "EnumItem" then
            -- СНЯТАЯ КЛАВИША ХРАНИТСЯ КАК false, А НЕ КАК nil.
            --
            -- nil означает «не задано», и такую настройку в профиле нечем
            -- отличить от несохранённой: кодек её просто не увидит, а при
            -- загрузке вернётся объявленное умолчание -- то есть снятая клавиша
            -- воскресала бы на каждом запуске. false -- обычное значение, оно
            -- переживает и JSON, и загрузку. Тот же приём, что и во всём
            -- остальном состоянии библиотеки.
            local function keyName()
                local v = state[key]
                return typeof(v) == "EnumItem" and v.Name or "NONE"
            end

            -- Захват клавиши. Пока ждём нажатие, строка помечена и подсвечена:
            -- иначе непонятно, что окно чего-то ждёт.
            local value = U.new("TextLabel", {
                BackgroundTransparency = 1, Font = THEME.Font,
                Text = keyName(), TextColor3 = THEME.InkSoft,
                TextSize = THEME.TextSize,
                TextXAlignment = Enum.TextXAlignment.Right,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -10, 0, 0),
                Size = UDim2.fromOffset(110, ROW), ZIndex = z + 1,
            }, rowBtn)

            -- ЖДЁТ ЛИ ЭТА СТРОКА КЛАВИШУ -- ЗАПИСАНО В ОДНОМ МЕСТЕ, В grabs.
            --
            -- Здесь стояла вторая копия того же самого: локальная `listening` с
            -- тем же значением, что и grabs[rowBtn], плюс поддельная подписка
            -- `{ Disconnect = ... }` в conns окна, отпускавшая захват ещё раз.
            -- Работало это лишь потому, что отмена ожидания идемпотентна: close
            -- зовёт OnClose ПЕРЕД тем, как гасить conns, то есть grabs успевал
            -- отпустить всё раньше, и поддельной подписке не доставалось ничего.
            -- Два счетовода при одной записи -- это расхождение, ждущее случая.
            local function waiting()
                return grabs[rowBtn] ~= nil
            end

            local function paint()
                local on = waiting()
                rowBtn.BackgroundTransparency = on and 0 or 1
                label.TextColor3 = on and THEME.Bg or THEME.Ink
                value.TextColor3 = on and THEME.Bg or THEME.InkSoft
            end

            table.insert(conns, rowBtn.MouseEnter:Connect(function()
                if waiting() then return end
                rowBtn.BackgroundTransparency = 0
                label.TextColor3 = THEME.Bg
                value.TextColor3 = THEME.Bg
            end))
            table.insert(conns, rowBtn.MouseLeave:Connect(function()
                if waiting() then return end
                paint()
            end))

            -- ЖДЁМ НАЖАТИЕ ЧУЖИМИ РУКАМИ.
            --
            -- Здесь стояла вторая копия этого танца -- взвести захват,
            -- дождаться клавиши, отменить по Escape, применить со следующего
            -- кадра, -- и она успела разойтись с первой: принимала только
            -- Enum.KeyCode (то есть мышиную настройку молча превращала в
            -- клавиатурную) и снимать привязку не умела вовсе.
            --
            -- Теперь ожидание одно на всю библиотеку и живёт в ядре (см. Binds).
            -- Оттуда же пришло то, чего не было ни в одной копии: ждущий ВСЕГДА
            -- ОДИН. Открыл настройки двух пунктов, щёлкнул клавишу в обоих --
            -- прежнее ожидание отменяется, а не назначается вместе с новым.
            table.insert(conns, rowBtn.MouseButton1Click:Connect(function()
                if waiting() then return end
                -- Пока ждём клавишу, Escape принадлежит НАМ: им отменяют
                -- назначение. Без этой пометки одно нажатие делало две работы
                -- разом -- отменяло захват и закрывало окно, -- и увидеть, что
                -- отмена сработала, было уже негде.
                entry.holdEscape = true

                grabs[rowBtn] = window.binds:Capture(function(captured)
                    grabs[rowBtn] = nil
                    -- Отпускаем Escape СО СЛЕДУЮЩЕГО КАДРА: порядок обработчиков
                    -- одного события в Roblox не определён, и сними мы пометку
                    -- здесь, сторож окна прочитал бы её уже снятой и закрылся
                    -- от того же самого нажатия.
                    task.defer(function() entry.holdEscape = false end)

                    -- Backspace приходит сюда как nil -- клавиши нет. Отмена по
                    -- Escape сюда не доходит вовсе (см. Core.Capture), поэтому
                    -- nil означает ровно снятие и ничего больше.
                    --
                    -- Раньше здесь стояло «применяем, только если не nil»: снять
                    -- настройку было нельзя ничем, кроме правки кода, при том что
                    -- Backspace честно обещал обратное.
                    state[key] = captured or false

                    value.Text = keyName()
                    paint()

                    if onChange then pcall(onChange, key, state[key]) end
                end)

                value.Text = "[ ... ]"
                paint()
            end))

        elseif type(declared) == "boolean" then
            local value = U.new("TextLabel", {
                BackgroundTransparency = 1, Font = THEME.Font,
                Text = current and "[ ON ]" or "[ OFF ]",
                TextColor3 = THEME.InkSoft, TextSize = THEME.TextSize,
                TextXAlignment = Enum.TextXAlignment.Right,
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -10, 0, 0),
                Size = UDim2.fromOffset(80, ROW), ZIndex = z + 1,
            }, rowBtn)

            table.insert(conns, rowBtn.MouseEnter:Connect(function()
                rowBtn.BackgroundTransparency = 0
                label.TextColor3 = THEME.Bg
                value.TextColor3 = THEME.Bg
            end))
            table.insert(conns, rowBtn.MouseLeave:Connect(function()
                rowBtn.BackgroundTransparency = 1
                label.TextColor3 = THEME.Ink
                value.TextColor3 = THEME.InkSoft
            end))

            table.insert(conns, rowBtn.MouseButton1Click:Connect(function()
                local next_ = not state[key]
                state[key] = next_
                value.Text = next_ and "[ ON ]" or "[ OFF ]"
                if onChange then pcall(onChange, key, next_) end
            end))
        end
    end

    return close
end

end)(NierUI)

--============================ NierUI/widgets/Basic.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Toggle, Button, Label, Divider
--=============================================================================

local THEME = NierUI.Theme
local U = NierUI.util

--== переключатель ===========================================================

NierUI.widget("Toggle", function(tab, opts)
    local row, _, value, _, _, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)
    local state = opts.Default and true or false

    -- Привязки-взаимодействия. Заводятся ниже, но гасить их надо отсюда, а
    -- объявление в Lua наверх не смотрит.
    local gated = {}

    local function render()
        value.Text = state and "[ ON ]" or "[ OFF ]"
    end
    render()

    local function set(on, silent)
        state = on and true or false
        render()

        -- ВОРОТА ЗАКРЫЛИСЬ -- ВСЁ, ЧТО ЗА НИМИ, ГАСНЕТ БЕЗУСЛОВНО.
        --
        -- Строка -- мастер-свитч: выключили функцию, значит взаимодействия с
        -- ней не просто перестают слушать клавишу, а уходят в OFF. Оставить их
        -- включёнными значило бы оставить включённым то, до чего больше не
        -- дотянуться ничем.
        --
        -- ДО обратного вызова: вызывающий в нём сворачивает саму функцию, и
        -- узнать о том, что взаимодействия погасли, он должен раньше, а не
        -- после того, как сворачивать уже нечего.
        if not state then
            for _, bind in ipairs(gated) do bind:Shut() end
        end

        NierUI.fire(opts, silent, state)

        -- СООБЩАЕМ ПОСЛЕ ОБРАТНОГО ВЫЗОВА, А НЕ ДО.
        --
        -- Обратный вызов -- часть применения смены: именно в нём вызывающий
        -- дописывает то, что от неё зависит. Сообщи мы раньше -- подписчик
        -- увидел бы промежуточное состояние и отстал ровно на одно действие.
        --
        -- Поймано на менеджере привязок: тумблер «показывать» ставит свой
        -- признак в Callback, а список перерисовывался до этого -- и прятал
        -- строку только со второго щелчка.
        --
        -- Сообщаем и при silent: он гасит обратный вызов ВЫЗЫВАЮЩЕГО, а не
        -- осведомлённость самого меню. Иначе загрузка профиля меняла бы всё
        -- молча, и список привязок врал бы до первого щелчка руками.
        NierUI.stateChanged(tab.window)
    end

    NierUI.connect(tab, row.MouseButton1Click, rowApi.gate(function()
        set(not state)
    end))

    --== ПРИВЯЗКИ ============================================================
    --
    --     Bind  = true | Enum.KeyCode.F      РУБИЛЬНИК: переключает эту строку
    --     Binds = { {...}, {...} }           ВЗАИМОДЕЙСТВИЯ: работают с функцией
    --
    -- Разные поля, потому что разные цели, а не потому что разное количество.
    -- Рубильник один и целится в строку; взаимодействий сколько угодно, и строка
    -- для них -- ворота. См. шапку Binds.
    local all = {}

    if opts.Bind ~= nil or opts.Binds then
        if opts.Settings then
            error(("[NierUI] у строки «%s» и привязка, и Settings: правая "
                .. "кнопка одна, а открывать пришлось бы двоих. Переложите "
                .. "настройки в Menu -- там доступны все виджеты.")
                :format(tostring(opts.Text or "?")), 0)
        end
    end

    if opts.Bind ~= nil then
        -- Состояния ядру НЕ ОТДАЁМ -- отдаём пару функций до него. set здесь тот
        -- же самый, что зовёт щелчок мышью, поэтому нажатие клавиши и щелчок по
        -- строке буквально неразличимы: один код, одно уведомление, одна правда.
        all[#all + 1] = tab.window.binds:Add({
            Flag = opts.Flag, Kind = opts.Kind, Enabled = opts.Enabled,
            ChangeModeInGame = opts.ChangeModeInGame,
            Key = typeof(opts.Bind) == "EnumItem" and opts.Bind or nil,
            row = row, rowTitle = opts.Text,
            get = function() return state end,
            set = function(on) set(on) end,
        })
    end

    --== СПИСКА ПОЛЕЙ ЗДЕСЬ БОЛЬШЕ НЕТ =======================================
    --
    -- Стояло переписывание по именам: Text, Flag, Key, Kind, Enabled, Toggle,
    -- Action, ChangeModeInGame. То есть ровно тот слой перевода, которого, как
    -- сказано в шапке Binds, «нет нигде», -- и вёл он себя как положено слою
    -- перевода: новое поле ядра надо было не забыть дописать сюда.
    --
    -- Забыли на первом же. State доезжал через win:Bind и терялся МОЛЧА у
    -- привязки, объявленной на строке: ядро не видело его вовсе и заводило
    -- привязке своё состояние. Внешне -- та самая ложь, ради которой State и
    -- заводился: [ON] при пустом захвате.
    --
    -- Копия, а не сама spec: таблицу дал вызывающий, и дописывать в неё своё
    -- значит однажды вернуть ему её изменённой.
    for _, spec in ipairs(opts.Binds or {}) do
        local decl = table.clone(spec)
        -- Подпись собирается из двух: строчной и своей. Своей нет -- останется
        -- строчная, и это верно: одна привязка на строке и есть эта строка.
        decl.row, decl.rowTitle = row, opts.Text
        -- ВОРОТА -- состояние строки, читается КАЖДЫЙ раз. Копией здесь была бы
        -- вторая правда о том же факте.
        decl.gate = function() return state end

        local extra = tab.window.binds:Add(decl)
        all[#all + 1] = extra
        gated[#gated + 1] = extra
    end

    -- Своё меню строим САМИ и одним построителем: редакторы ядра сверху, то,
    -- что дописал вызывающий, -- под ними. См. makeRow.
    if #all > 0 then
        rowApi.menu(tab, opts.MenuTitle or opts.Text, function(menu)
            NierUI.bindRows(menu, all)
            if opts.Menu then
                menu:Divider()
                opts.Menu(menu)
            end
        end, opts.MenuWidth)
    end

    -- Настройки по правой кнопке подключает КАРКАС, а пару Get/SetSetting
    -- дописывает воронка в containerIndex. Переключателю для этого не надо
    -- делать ничего -- как и любой другой строке, чего от него и добивались.
    return NierUI.bind(tab, opts, {
        -- Клавиши, режимы и подписи уезжают в профиль вместе со значением
        -- строки, а не отдельными флагами: это настройки ОДНОГО пункта меню.
        binds = all,

        Set = function(_, on, silent) set(on, silent) end,
        Get = function(_) return state end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Недоступная строка не должна отзываться и на клавишу: иначе она
            -- выглядит выключенной, а работает. Касается ВСЕХ её привязок --
            -- и рубильника, и взаимодействий.
            for _, b in ipairs(all) do b:SetEnabled(on) end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)

--== кнопка ==================================================================

-- У кнопки НЕТ СОБСТВЕННОГО СОСТОЯНИЯ, и это намеренно.
--
-- Была версия со встроенным счётчиком нажатий: Counter = true, кнопка считала
-- сама и показывала число. Убрано -- счёт это прикладная логика, а не работа
-- элемента интерфейса. Сегодня счётчик нажатий, завтра таймер отката,
-- послезавтра «показывать только по чётным» -- и библиотека обрастает чужими
-- правилами, которых никто у неё не просил.
--
-- Кнопка умеет ровно две вещи: сообщить о нажатии и ПОКАЗАТЬ то, что ей дали.
-- Счётчик поверх этого пишется в три строки и остаётся там, где ему место:
--
--     local count = 0
--     local btn
--     btn = tab:Button({ Text = "CLICK", Callback = function()
--         count = count + 1
--         btn:SetValue(tostring(count))
--     end })
--
-- Сохранять такой счётчик или нет -- тоже решает вызывающий, своим Flag на том,
-- что действительно хранит значение.
NierUI.widget("Button", function(tab, opts)
    local row, label, value, _, _, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)
    value.Text = opts.Value or ">"

    NierUI.connect(tab, row.MouseButton1Click, rowApi.gate(function()
        NierUI.fire(opts, false)
    end))

    -- ПРИВЯЗКА У КНОПКИ -- ДЕЙСТВИЕ. Состояния у неё нет и быть не может:
    -- нажали -- сработало, удерживать и переключать нечего. В списке привязок
    -- у такой написано [BUTTON], а не [OFF] -- отключённой она не бывает.
    local bind
    if opts.Bind ~= nil then
        bind = tab.window.binds:Add({
            Flag = opts.Flag, Enabled = opts.Enabled, row = row,
            rowTitle = opts.Text,
            Key = typeof(opts.Bind) == "EnumItem" and opts.Bind or nil,
            Action = opts.Callback,
        })
        rowApi.menu(tab, opts.MenuTitle or opts.Text, function(menu)
            NierUI.bindRows(menu, { bind })
            if opts.Menu then
                menu:Divider()
                opts.Menu(menu)
            end
        end, opts.MenuWidth)
    end

    return NierUI.bind(tab, opts, {
        binds = bind and { bind } or nil,

        -- Единственный примитив показа: что писать в поле -- дело вызывающего.
        SetValue = function(_, text) value.Text = tostring(text) end,
        -- Подпись меняется наравне со значением: полезно там, где строка
        -- показывает что-то, что может смениться на ходу.
        SetText = function(_, text) label.Text = tostring(text) end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Недоступная строка не должна отзываться и на клавишу: иначе она
            -- выглядит выключенной, а работает.
            if bind then bind:SetEnabled(on) end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)

--== текст ===================================================================
--
-- Не строка в общем смысле: у него нет ни подсветки, ни значения, ни описания.
-- Поэтому makeRow тут не при чём, это просто подпись в потоке.

NierUI.widget("Label", function(tab, opts)
    tab.rows = tab.rows + 1
    local text = type(opts) == "table" and (opts.Text or "") or tostring(opts)

    local label = U.new("TextLabel", {
        BackgroundTransparency = 1, Font = THEME.Font,
        Text = text, TextColor3 = THEME.InkSoft, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 18), LayoutOrder = tab.rows,
    }, tab.page)

    return {
        Set = function(_, v) label.Text = tostring(v) end,
        Get = function(_) return label.Text end,
        -- Подписи каркас строки не касается вовсе, поэтому доступность у неё
        -- своя и делает единственное, что для подписи осмысленно, -- бледнеет.
        -- Пара всё равно нужна: она обещана всем обработчикам, и тот, кто гасит
        -- группу строк разом, не должен разбирать, что среди них подпись.
        SetEnabled = function(_, on)
            label.TextColor3 = on ~= false and THEME.InkSoft or THEME.Disabled
        end,
        IsEnabled = function(_) return label.TextColor3 ~= THEME.Disabled end,
    }
end)

NierUI.widget("Divider", function(tab)
    tab.rows = tab.rows + 1
    local holder = U.new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10),
        LayoutOrder = tab.rows,
    }, tab.page)
    U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0,
        BackgroundTransparency = 0.65, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1),
    }, holder)
    return holder
end)

end)(NierUI)

--============================ NierUI/widgets/Slider.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Slider -- число с дорожкой
--=============================================================================
--
-- Тянется мышью через события: нажали -- ведём, отпустили -- всё. Никакого
-- покадрового опроса, InputChanged приходит сам.
--
-- Дробные значения задаются через Step: Step = 0.05 даст два знака.

local UserInputService = game:GetService("UserInputService")

-- THEME здесь больше не нужен: вся геометрия дорожки -- в каркасе строки.
local U = NierUI.util

NierUI.widget("Slider", function(tab, opts)
    -- Значение сразу редактируемое: ползунком в 0.53 из 0.65 не попасть, при
    -- ста пикселях дорожки и диапазоне 0..1 один пиксель стоит целый сотый.
    local row, _, box, invert, _, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, "TextBox", opts)

    local min = opts.Min or 0
    local max = opts.Max or 100
    local step = opts.Step or 1
    local suffix = opts.Suffix or ""
    local current = math.clamp(opts.Default or min, min, max)

    -- Вырожденный диапазон -- не ошибка вызывающего, а обычное следствие
    -- данных: Min и Max нередко считаются из чего-то, что в этот момент пусто.
    -- Делить на него нельзя: (current-min)/(max-min) даёт nan, а nan в
    -- UDim2.fromScale роняет отрисовку. Полоса при этом честно стоит пустой.
    local span = (max > min) and (max - min) or 1

    -- Сколько знаков показывать -- выводим из шага, а не из значения: иначе
    -- 0.30000000000000004 попадало бы в подпись как есть.
    local decimals = 0
    if step < 1 then
        decimals = math.max(0, math.ceil(-math.log(step, 10)))
    end
    local format = "%." .. decimals .. "f"

    -- Дорожка слева от числа. Геометрия, ограничитель и инверсия -- в каркасе
    -- (см. NierUI.makeTrack): полоса выполнения строит ровно то же самое, и две
    -- копии этих долей однажды разъехались бы. Своего здесь только толщина и то,
    -- что под курсором дорожка светлеет: её, в отличие от полосы, тянут.
    local track, fill = NierUI.makeTrack(row, invert, 2, 0.75, 0.55)

    local editing = false

    local function render()
        if not editing then
            box.Text = format:format(current) .. suffix
        end
        fill.Size = UDim2.fromScale((current - min) / span, 1)
    end

    local function commit(v, silent)
        current = v
        render()
        NierUI.fire(opts, silent, current)
    end

    -- Перетаскивание: притягиваем к шагу. Дорожка -- это сто пикселей, точнее
    -- шага по ней всё равно не попасть.
    --
    -- СЕТКА ОТСЧИТЫВАЕТСЯ ОТ MIN, А НЕ ОТ НУЛЯ.
    --
    -- Раньше было floor(v/step + 0.5)*step -- сетка от нуля, независимо от
    -- диапазона. При Min = 5, Step = 10 она давала 0, 10, 20: само значение 5,
    -- с которого ползунок начинается, перетаскиванием было недостижимо, а левый
    -- край дорожки после зажима прилипал к 5 и не двигался до середины. Любой
    -- диапазон, чей Min не кратен шагу, вёл себя так же.
    local function set(v, silent)
        commit(math.clamp(
            min + math.floor((v - min) / step + 0.5) * step, min, max), silent)
    end

    -- НАБОР РУКАМИ: зажим ТОЛЬКО по диапазону, к шагу НЕ притягиваем.
    --
    -- Иначе весь смысл теряется: при Step = 0.05 набранное 0.53 превращалось
    -- бы в 0.55 -- ровно то, ради чего поле и понадобилось, потому что
    -- ползунком в 0.53 не попасть.
    --
    -- Округляем до отображаемой точности, а не как попало: у целочисленного
    -- ползунка (Step = 1, знаков ноль) набранное 24.7 станет 25, а не осядет
    -- дробью там, где дробей быть не должно.
    local roundTo = 10 ^ decimals
    local function setTyped(v, silent)
        local clamped = math.clamp(v, min, max)
        commit(math.floor(clamped * roundTo + 0.5) / roundTo, silent)
    end

    --== приём только чисел ==================================================
    --
    -- Фильтруем ПО ХОДУ ввода, а не только при подтверждении: иначе человек
    -- набирает буквы, они видны, а на выходе молча превращаются в старое
    -- значение -- выглядит как проглоченный ввод.
    --
    -- Минус разрешаем только первым символом и только если диапазон вообще
    -- уходит в отрицательные; точку -- ровно одну.
    local allowNegative = min < 0

    local function sanitize(text)
        local out, dotSeen = {}, false
        for i = 1, #text do
            local ch = text:sub(i, i)
            if ch:match("%d") then
                out[#out + 1] = ch
            elseif ch == "." and not dotSeen then
                dotSeen = true
                out[#out + 1] = ch
            elseif ch == "-" and allowNegative and #out == 0 then
                out[#out + 1] = ch
            end
        end
        return table.concat(out)
    end

    NierUI.connect(tab, box:GetPropertyChangedSignal("Text"), function()
        if not editing then return end
        local clean = sanitize(box.Text)
        if clean ~= box.Text then box.Text = clean end
    end)

    NierUI.connect(tab, box.Focused, function()
        editing = true
        -- на время правки суффикс убираем: "0.65x" числом не разбирается
        box.Text = format:format(current)
    end)

    NierUI.connect(tab, box.FocusLost, function()
        editing = false
        local typed = tonumber(box.Text)
        if typed then
            setTyped(typed)
        else
            render()   -- пусто или мусор -- возвращаем прежнее
        end
    end)

    render()

    local sliding = false

    NierUI.connect(tab, row.InputBegan, rowApi.gate(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        -- Тянем, только если попали по дорожке. Иначе клик по названию строки
        -- швырял значение в минимум -- строка-то во всю ширину.
        local x = input.Position.X
        local left = track.AbsolutePosition.X - 8
        local right = left + track.AbsoluteSize.X + 16
        if x < left or x > right then return end

        sliding = true
        set(min + span * U.alongX(track, x))
    end))

    NierUI.connect(tab, UserInputService.InputChanged, function(input)
        if not sliding then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        set(min + span * U.alongX(track, input.Position.X))
    end)

    NierUI.connect(tab, UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)

    return NierUI.bind(tab, opts, {
        -- Set НЕ ПРИТЯГИВАЕТ К ШАГУ, как и набор руками.
        --
        -- Шаг существует ради перетаскивания: по стопиксельной дорожке точнее
        -- всё равно не попасть. Но программная установка и загрузка профиля --
        -- не перетаскивание, и притягивание там теряет данные: при шаге 1000
        -- сохранённые 65 возвращались как 0, а 500 -- как 1000. Значение,
        -- которое положили в профиль, обязано вернуться тем же.
        --
        -- Тишина уходит вторым аргументом в тот же setTyped. Здесь стояла её
        -- отдельная ветка -- зажать, округлить, перерисовать, -- то есть второй
        -- путь к тому же самому: разойтись двум округлениям достаточно одной
        -- правки в одном из них.
        Set = function(_, v, silent) setTyped(tonumber(v) or min, silent) end,
        Get = function(_) return current end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Перетаскивание могло идти в момент выключения: без сброса
            -- ползунок продолжил бы ехать за мышью на недоступной строке.
            if not on then sliding = false end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)

end)(NierUI)

--============================ NierUI/widgets/Dropdown.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Dropdown и MultiDropdown
--=============================================================================
--
-- Одиночный и множественный отличаются ровно тремя вещами: что делает щелчок
-- по пункту, что написано в значении строки и закрывается ли список после
-- выбора. Всё остальное общее, поэтому конструктор ОДИН: две копии
-- разъехались бы на первой же правке.
--
--
-- ФОРМА ПУНКТА
--
--     "NAMES"                                     строка -- она же ключ и подпись
--     { Text = "Игрок", Key = 12345 }             подпись и ключ раздельно
--     { Text = ..., Key = ..., Settings = {...} } плюс свои настройки
--
-- Раздельные ключ и подпись нужны там, где подписи могут совпадать: два разных
-- объекта с одинаковым именем на строковом ключе склеились бы в один пункт.
--
--
-- ДИНАМИКА
--
--     dd:Refresh({ ... })   заменить набор пунктов целиком
--
-- Библиотека НЕ ЗНАЕТ, откуда берутся пункты и по какому поводу меняются. Кто
-- их поставляет, тот и решает, когда звать Refresh.
--
-- Выбор и настройки хранятся ПО КЛЮЧУ и переживают пересборку. Исчезнувший из
-- набора ключ не стирается: его просто некому показать, и в Get он не попадёт,
-- потому что Get идёт по текущим пунктам. Вернётся ключ -- вернётся и отметка.
-- Это осознанный выбор: стирать сразу значило бы терять настройку от любого
-- мигания источника. Кому нужна честная зачистка -- dd:Prune().
--
--
-- ЧЕКБОКСЫ -- ПРИЗНАК ТОЛЬКО МНОЖЕСТВЕННОГО. В одиночном выбран ровно один
-- пункт, и он написан в самой строке; ряд квадратиков там лишь притворялся бы,
-- что можно отметить несколько.

local THEME = NierUI.Theme
local U = NierUI.util

-- Насколько далеко пускать поиск (см. U.matchScore). Таблица объявлена ОДИН раз
-- на модуль, а не собирается при каждой постройке списка: она константа, а
-- списков в меню бывает много.
local SEARCH_LIMIT = { prefix = 0, word = 1, substring = 2, fuzzy = 3 }

local function normalize(list)
    local entries = {}
    for _, item in ipairs(list or {}) do
        if type(item) == "table" then
            local key = item.Key
            if key == nil then key = item.Text end
            entries[#entries + 1] = {
                key = key,
                text = tostring(item.Text ~= nil and item.Text or key),
                settings = item.Settings,
            }
        else
            entries[#entries + 1] = { key = item, text = tostring(item) }
        end
    end
    return entries
end

local function build(tab, opts, multi)
    -- SETTINGS У СПИСКА ОЗНАЧАЕТ НЕ ТО ЖЕ, ЧТО У СТРОКИ.
    --
    -- У строки это набор «поле -> значение», один уровень. Здесь -- настройки
    -- ПУНКТОВ, по набору на каждый ключ, то есть два уровня. Каркас, который
    -- теперь подключает настройки любой строке сам, развернул бы их как свои и
    -- упёрся в таблицу там, где ждал значение.
    --
    -- Прячем поле от него подстановкой, а не копией всей таблицы: остальные
    -- поля читаются через __index и остаются теми же самыми.
    local rowOpts = setmetatable({ Settings = false }, { __index = opts })

    local row, _, value, _, setHeld, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, nil, rowOpts)
    local window = tab.window

    -- Своё имя списка: ключи пунктов у двух разных списков совпадают запросто
    -- («NAMES» есть и там и там), а память положения окна настроек ведётся по
    -- ключу пункта -- без имени списка два списка делили бы её на двоих.
    local listId = U.randomName()

    -- ДВА НАБОРА, И ЭТО ПРИНЦИПИАЛЬНО.
    --
    -- source -- всё, что есть; entries -- то, что сейчас видно после фильтра.
    -- Ответы Get и Prune идут ПО ПОЛНОМУ набору: иначе отфильтрованный список
    -- сообщал бы, что выбрано только видимое, а стоило стереть строку поиска --
    -- выбор «возвращался» бы. Выбор к фильтру отношения не имеет.
    local source = normalize(opts.Options)
    local entries = source
    local query = ""

    local chosen = {}
    local settings = {}

    local searchHeight = opts.Search and THEME.RowHeight or 0
    local panel, setPanel, setPanelHeight = NierUI.makePanel(row, 0)

    -- ШТАТНАЯ ПОЛОСА ПРОКРУТКИ ВЫКЛЮЧЕНА: она рисуется вплотную к правому краю
    -- и читалась заодно с границей блока. Нулевая толщина -- это нулевая ширина
    -- отрисовки, прокрутка при этом жива (ScrollingEnabled остаётся true, а
    -- VerticalScrollBarInset у нас None, колонка не резервируется).
    local list = U.new("ScrollingFrame", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, searchHeight),
        Size = UDim2.new(1, 0, 1, -1 - searchHeight),
        ZIndex = 30,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 0,
    }, panel)
    U.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)

    -- Указатель лежит в ПАНЕЛИ, а не в списке: дети списка едут вместе с
    -- содержимым, и он уезжал бы вместе с ними.
    local bar = U.new("Frame", {
        BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
        BackgroundTransparency = 0.45, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(2, 0),
        ZIndex = 33, Visible = false,
    }, panel)

    --=========================================================================
    -- Состояние
    --=========================================================================

    -- Ответ всегда в порядке пунктов, а не в порядке щелчков: иначе один и тот
    -- же набор выглядел бы по-разному в зависимости от того, как его натыкали.
    --
    -- ВТОРЫМ ЗНАЧЕНИЕМ -- ПОДПИСИ, И ЭТО НЕ УДОБСТВО.
    --
    -- Наружу и в профиль уходит КЛЮЧ, а человеку показывается ПОДПИСЬ, и это
    -- разные вещи ровно там, где их и развели: { Text = "Игрок", Key = 12345 }.
    -- В строке при этом писался ключ -- то есть «12345» вместо имени, -- и
    -- раздельная форма, которую README рекомендует как основную при совпадающих
    -- подписях, делала строку нечитаемой. Собираем оба за один обход: второй
    -- ради подписи -- это второй ответ на тот же вопрос.
    local function picked()
        local keys, labels = {}, {}
        for _, entry in ipairs(source) do
            if chosen[entry.key] then
                keys[#keys + 1] = entry.key
                labels[#labels + 1] = entry.text
            end
        end
        return keys, labels
    end

    local function specFor(entry)
        if entry.settings then return entry.settings end
        return opts.Settings and opts.Settings[entry.key] or nil
    end

    -- Значения по умолчанию копируются в собственное хранилище: править сам
    -- spec нельзя, его может передать общая на несколько списков таблица.
    local function ensureSettings(entry)
        local spec = specFor(entry)
        if not spec then return nil end
        local store = settings[entry.key]
        if not store then
            store = {}
            settings[entry.key] = store
        end
        -- В состоянии лежит ЗНАЧЕНИЕ, а не описание: у ползунка описание
        -- содержит диапазон, а наружу и в профиль должно уходить число.
        for key, default in pairs(spec) do
            if store[key] == nil then store[key] = NierUI.settingDefault(default) end
        end
        return spec, store
    end

    local repaint = {}

    local function render()
        local sel, labels = picked()
        if not multi then
            value.Text = sel[1] ~= nil and labels[1] or "NONE"
        elseif #sel == 0 then
            value.Text = "NONE"
        elseif #sel == 1 then
            value.Text = labels[1]
        else
            -- Перечислять всё в стопиксельном поле бессмысленно, а рисовать
            -- обрезок с многоточием -- врать о содержимом. Число честнее.
            value.Text = ("%d SELECTED"):format(#sel)
        end
        for _, fn in ipairs(repaint) do fn() end
    end

    local function updateBar()
        local total = #entries * THEME.RowHeight
        if total == 0 then bar.Visible = false return end
        local view = list.AbsoluteSize.Y
        if view <= 0 or total <= view then
            bar.Visible = false
            return
        end
        bar.Visible = true

        local travel = view - 4
        local height = math.max(14, math.floor(travel * view / total))
        local maxScroll = total - view
        local progress = maxScroll > 0 and (list.CanvasPosition.Y / maxScroll) or 0
        bar.Size = UDim2.fromOffset(2, height)
        bar.Position = UDim2.new(1, -4, 0, 2 + math.floor((travel - height) * progress))
    end

    NierUI.connect(tab, list:GetPropertyChangedSignal("CanvasPosition"), updateBar)

    -- Флаг «раскрыт» и щелчок по строке держит каркас (см. NierUI.rowExpand):
    -- та же связка у палитры, вместе со сторожем «щелчок пришёлся ВНУТРЬ
    -- раскрытого блока -- строку не трогаем».
    local setOpen = NierUI.rowExpand(tab, row, rowApi, panel, function(state)
        setPanel(state)
        if not state then list.CanvasPosition = Vector2.zero end
        setHeld(state)          -- шапка подсвечена, пока блок раскрыт
        updateBar()
    end)

    --=========================================================================
    -- Пункты
    --=========================================================================
    --
    -- КОННЕКТЫ ПУНКТОВ ЖИВУТ ОТДЕЛЬНО ОТ ОКОННЫХ, И ЭТО ГЛАВНОЕ ЗДЕСЬ.
    --
    -- Раньше каждый пункт складывал свои подписки в window.conns -- список на
    -- всё время жизни окна, который никогда не укорачивается. Для статичных
    -- двадцати пяти масок это незаметно. Для списка, который пересобирается на
    -- каждое изменение источника, это неограниченная утечка: за сессию набегут
    -- сотни коннектов, и каждый будет держать уничтоженную кнопку.
    --
    -- Ровно тот класс, на котором мы уже горели дважды. Поэтому свой список,
    -- и он гасится при каждой пересборке.

    local itemConns = {}

    local function clearItems()
        -- Общим drain, а не своим циклом: приём «погасить сток и опустошить его»
        -- один на всю библиотеку. Замыкания на каждую подписку он не заводит --
        -- а здесь это важнее всего, список пересобирается на каждую букву в
        -- строке поиска.
        NierUI.drain(itemConns)
        table.clear(repaint)
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then
                -- Цель правой кнопки снимается ВМЕСТЕ с пунктом. Список
                -- пересобирается на каждое изменение источника и на каждую
                -- букву в поиске -- без снятия реестр рос бы неограниченно,
                -- ровно как когда-то рос window.conns.
                NierUI.contextForget(window, child)
                child:Destroy()
            end
        end
    end

    local function makeItem(entry, index)
        local key = entry.key

        local item = U.new("TextButton", {
            BackgroundTransparency = 1, BorderSizePixel = 0,
            AutoButtonColor = false, Text = "",
            Size = UDim2.new(1, 0, 0, THEME.RowHeight),
            LayoutOrder = index, ZIndex = 31,
        }, list)

        local itemBg = U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
            BorderSizePixel = 0, Active = false,
            Size = UDim2.fromScale(1, 1), ZIndex = 31,
        }, item)

        local box, dot
        if multi then
            box = U.new("Frame", {
                BackgroundColor3 = THEME.Ink, BackgroundTransparency = 0.7,
                BorderSizePixel = 0, Active = false,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(9, 9),
                ZIndex = 33,
            }, item)
            dot = U.new("Frame", {
                BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
                BorderSizePixel = 0, Active = false,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(1, -4, 1, -4), ZIndex = 34,
            }, box)
        end

        local spec, store = ensureSettings(entry)

        -- Без квадратика текст начинается там же, где подписи строк, иначе
        -- одиночный список выглядел бы сдвинутым непонятно почему.
        local textX = multi and 24 or 10

        local text = U.new("TextLabel", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = entry.text, TextColor3 = THEME.Ink,
            TextSize = THEME.TextSize, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(textX, 0),
            Size = UDim2.new(1, -textX - (spec and 22 or 8), 1, 0), ZIndex = 33,
        }, item)

        -- Метка «у пункта есть настройки». Без неё правая кнопка -- знание,
        -- которое неоткуда взять: пункты выглядят одинаково.
        local gear
        if spec then
            gear = U.new("Frame", {
                BackgroundColor3 = THEME.Ink, BackgroundTransparency = 0.4,
                BorderSizePixel = 0, Active = false,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(5, 5),
                ZIndex = 33,
            }, item)
        end

        local hovered = false
        local function paint()
            local ink = hovered and THEME.Bg or THEME.Ink
            itemBg.BackgroundTransparency = hovered and 0 or 1
            text.TextColor3 = ink
            if gear then gear.BackgroundColor3 = ink end
            if box then
                box.BackgroundColor3 = ink
                dot.BackgroundColor3 = ink
                dot.BackgroundTransparency = chosen[key] and 0 or 1
            end
        end
        repaint[#repaint + 1] = paint

        table.insert(itemConns, item.MouseEnter:Connect(function()
            hovered = true
            paint()
        end))
        table.insert(itemConns, item.MouseLeave:Connect(function()
            hovered = false
            paint()
        end))

        table.insert(itemConns, item.MouseButton1Click:Connect(function()
            if multi then
                -- Список НЕ закрывается -- в этом весь смысл множественного:
                -- отметить пять штук, не открывая его пять раз.
                chosen[key] = (not chosen[key]) or nil
                render()
                NierUI.fire(opts, false, picked())
            else
                table.clear(chosen)
                chosen[key] = true
                render()
                setOpen(false)
                NierUI.fire(opts, false, key)
            end
        end))

        -- Правая кнопка -- через реестр окна: при открытом окне настроек до
        -- пункта она не доходит, его перехватывает фон всплывающего. Ровно
        -- из-за этого нельзя было открыть настройки двух масок рядом и
        -- сравнить их. См. Context.
        if spec then
            NierUI.contextTarget(window, item, function(onClosed)
                return NierUI.optionSettings(window, {
                    Anchor = item, Title = entry.text,
                    Spec = spec, State = store,
                    OnChange = function(field, v)
                        if opts.OnSetting then pcall(opts.OnSetting, key, field, v) end
                    end,
                    OnClose = onClosed,
                    -- Ключ памяти -- ПО КЛЮЧУ ПУНКТА, а не по кнопке: кнопки
                    -- пересобираются на каждое изменение источника и на каждую
                    -- букву в поиске, и память положения умирала бы вместе с
                    -- ними. У ключа пункта та же роль, что у выбора и настроек:
                    -- он переживает пересборку.
                    Place = listId .. "\0" .. tostring(key),
                })
            end)
        end
    end

    --=========================================================================
    -- Пересборка
    --=========================================================================

    local function layout()
        local visibleRows = math.min(#entries, opts.MaxVisible or THEME.DropdownMax)
        local total = #entries * THEME.RowHeight
        list.CanvasSize = UDim2.fromOffset(0, total)
        -- Строка поиска входит в высоту блока всегда, даже когда фильтр не
        -- нашёл ничего: иначе стереть запрос было бы негде.
        local body = visibleRows > 0 and (visibleRows * THEME.RowHeight + 1) or 0
        setPanelHeight(searchHeight + math.max(body, searchHeight > 0 and 1 or 0))
    end

    local function rebuild()
        local keepScroll = list.CanvasPosition
        clearItems()
        for index, entry in ipairs(entries) do makeItem(entry, index) end
        layout()
        render()
        -- Прокрутку возвращаем, но движок сам зажмёт её по новому полотну,
        -- если список стал короче.
        list.CanvasPosition = keepScroll
        updateBar()
    end

    --== поиск ===============================================================
    --
    -- Фильтр -- это пересборка подмножества, то есть тот же rebuild, что и у
    -- динамического списка. Отдельного механизма не понадобилось.

    -- Подпоследовательность («fuzzy») находит слишком многое, поэтому по
    -- умолчанию отрезаем на подстроке.
    local searchLimit = SEARCH_LIMIT[opts.Search] or 2

    local function refilter()
        if query == "" then
            entries = source
            rebuild()
            return
        end

        -- Сортируем находки, а не просто отбираем: совпадение в начале строки
        -- обязано стоять выше совпадения в середине слова, иначе список
        -- выглядит случайным. Порядок в source -- последний разделитель, чтобы
        -- одинаково хорошие находки не прыгали между наборами букв.
        local ranked = {}
        for index, entry in ipairs(source) do
            local score, at = U.matchScore(entry.text, query)
            if score and score <= searchLimit then
                ranked[#ranked + 1] = { entry = entry, score = score, at = at, order = index }
            end
        end

        table.sort(ranked, function(a, b)
            if a.score ~= b.score then return a.score < b.score end
            if a.at ~= b.at then return a.at < b.at end
            return a.order < b.order
        end)

        local found = {}
        for _, item in ipairs(ranked) do found[#found + 1] = item.entry end
        entries = found
        rebuild()
    end

    if opts.Search then
        local search = U.new("TextBox", {
            BackgroundTransparency = 1, Font = THEME.Font,
            Text = "", PlaceholderText = "поиск",
            PlaceholderColor3 = THEME.Disabled,
            TextColor3 = THEME.Ink, TextSize = THEME.TextSize,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -20, 0, THEME.RowHeight), ZIndex = 31,
        }, panel)

        U.new("Frame", {
            BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Active = false,
            BackgroundTransparency = 0.75,
            Position = UDim2.fromOffset(0, THEME.RowHeight - 1),
            Size = UDim2.new(1, 0, 0, 1), ZIndex = 31,
        }, panel)

        NierUI.connect(tab, search:GetPropertyChangedSignal("Text"), function()
            query = search.Text
            refilter()
        end)

        -- Закрыли список -- сбрасываем запрос: иначе он откроется отфильтрованным
        -- и будет выглядеть наполовину пустым без видимой причины.
        NierUI.connect(tab, panel:GetPropertyChangedSignal("Visible"), function()
            if panel.Visible or search.Text == "" then return end
            search.Text = ""
        end)
    end

    --== начальный выбор =====================================================

    -- DEFAULT = FALSE ОЗНАЧАЕТ «НИЧЕГО НЕ ВЫБРАНО».
    --
    -- Отличать это от «не сказано» надо: не сказано -- список сам отмечает первый
    -- пункт, и строка выглядит так, будто выбор уже сделан. Там, где список
    -- предлагает ДЕЙСТВИЕ («что добавить»), это прямая ложь.
    --
    -- nil на эту роль не годится -- он и есть «не сказано», -- поэтому false. В
    -- ключи он при этом не попадает: отмеченный `false` был бы пунктом, которого
    -- нет ни в одном наборе, и жил бы в выборе вечно.
    local function choose(key)
        if key == nil or key == false then return end
        chosen[key] = true
    end

    if multi then
        for _, v in ipairs(opts.Default or {}) do choose(v) end
    else
        local single = opts.Default
        if single == nil and entries[1] then single = entries[1].key end
        choose(single)
    end

    rebuild()

    --=========================================================================
    -- Наружу
    --=========================================================================

    local api = {
        Refresh = function(_, options)
            if options ~= nil then source = normalize(options) end
            refilter()
        end,

        Options = function(_)
            local out = {}
            for _, entry in ipairs(source) do out[#out + 1] = entry.key end
            return out
        end,

        -- Забыть выбор и настройки по ключам, которых больше нет в наборе.
        -- Отдельной командой, а не само: мигание источника не должно стирать
        -- то, что человек накрутил.
        Prune = function(_)
            local alive = {}
            for _, entry in ipairs(source) do alive[entry.key] = true end
            for key in pairs(chosen) do
                if not alive[key] then chosen[key] = nil end
            end
            for key in pairs(settings) do
                if not alive[key] then settings[key] = nil end
            end
            render()
        end,

        -- Через промежуточную переменную, а не `store and store[field] or nil`:
        -- у настроек бывают булевы значения, и false в такой записи молча
        -- превращается в nil. Выключенный флаг пункта читался как «нет такой
        -- настройки» -- и именно так он терялся после загрузки профиля.
        GetSetting = function(_, key, field)
            local store = settings[key]
            if not store then return nil end
            return store[field]
        end,
        SetSetting = function(_, key, field, v)
            -- ЗАВОДИМ ХРАНИЛИЩЕ, ЕСЛИ ЕГО ЕЩЁ НЕТ.
            --
            -- Раньше здесь стоял молчаливый выход. Хранилище появляется, когда
            -- пункт ПОСТРОЕН, а профиль применяется к списку, который мог ещё
            -- не получить свой набор через Refresh, -- и все настройки пунктов
            -- пропадали без следа. Ровно тот же класс тихой потери, что уже
            -- чинили выше в GetSetting.
            --
            -- Настройка ключа, которого в наборе нет, при этом не мусор: выбор и
            -- настройки хранятся ПО КЛЮЧУ и переживают пересборку намеренно --
            -- вернётся ключ, вернётся и накрученное. Кому нужна зачистка, у того
            -- есть Prune.
            local store = settings[key]
            if not store then
                store = {}
                settings[key] = store
            end
            store[field] = v
            -- Как и у строки: загрузка профиля применяет настройку, а не
            -- только запоминает.
            if opts.OnSetting then pcall(opts.OnSetting, key, field, v) end
        end,
        Settings = function(_, key)
            return settings[key]
        end,

        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Раскрытый список надо схлопнуть: иначе он останется висеть
            -- поверх соседних строк, а закрыть его будет уже нечем.
            if not on then setOpen(false) end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    }

    -- SET ОБЯЗАН СООБЩИТЬ О СМЕНЕ, как это делают все остальные элементы.
    --
    -- Список был единственным, кто молчал, и стоило это вот чего: загрузка
    -- профиля расставляла галочки, а тот, кто на них подписан, о смене не
    -- узнавал. В меню отмечено, на деле выключено -- расхождение, которое
    -- глазами не поймать, потому что интерфейс показывает правду о себе и
    -- неправду о происходящем.
    --
    -- Тишина по-прежнему доступна вторым аргументом -- ею пользуются, когда
    -- значение ставят изнутри и обработчик уже отработал. Сам вызов -- общий
    -- NierUI.fire: своя копия здесь была двенадцатой в библиотеке.
    if multi then
        -- Через переменную: picked отдаёт ДВА значения, и `return picked()`
        -- вернул бы вызывающему заодно и подписи -- второй ответ на вопрос,
        -- которого он не задавал.
        api.Get = function(_)
            local keys = picked()
            return keys
        end
        api.Set = function(_, values, silent)
            table.clear(chosen)
            for _, v in ipairs(values or {}) do choose(v) end
            render()
            -- Наружу отдаём picked(), а не values: он идёт в порядке пунктов и
            -- не содержит ключей, которых в наборе нет.
            --
            -- Через переменную -- по той же причине, что и в Get: picked отдаёт
            -- ДВА значения, и подставленный прямо в вызов он донёс бы до
            -- обработчика заодно и подписи.
            local keys = picked()
            NierUI.fire(opts, silent, keys)
        end
        api.Has = function(_, key) return chosen[key] == true end
    else
        api.Get = function(_)
            local keys = picked()
            return keys[1]
        end
        api.Set = function(_, v, silent)
            table.clear(chosen)
            choose(v)
            render()
            NierUI.fire(opts, silent, v)
        end
    end

    -- Настройки пунктов уезжают в конфиг вместе со значением: без них
    -- сохранённый белый список вернулся бы без цветов.
    api.SettingsMap = function(_) return settings end

    return NierUI.bind(tab, opts, api)
end

NierUI.widget("Dropdown", function(tab, opts) return build(tab, opts, false) end)
NierUI.widget("MultiDropdown", function(tab, opts) return build(tab, opts, true) end)

end)(NierUI)

--============================ NierUI/widgets/InputText.luau ============================
;(function(NierUI)
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

end)(NierUI)

--============================ NierUI/widgets/Keybind.luau ============================
;(function(NierUI)
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
    -- МЕНЮ СТРОИМ САМИ, И КАРКАСУ ОБ ЭТОМ НАДО СКАЗАТЬ.
    --
    -- Он подключает Menu любой строке сам и отступает только там, где видит
    -- признак привязки -- Bind, Binds или готовую bind (см. makeRow). У строки
    -- клавиши, объявленной руками, нет ни одного из трёх: она САМА и есть
    -- привязка. Каркас строил её Menu, следом свой построитель ставил виджет --
    -- и заявка на правую кнопку оказывалась второй: `tab:Keybind{ Menu = ... }`
    -- падал с «правая кнопка уже занята» прямо на загрузке.
    --
    -- Прячем поле подстановкой, как список прячет свой Settings: остальное
    -- читается через __index и остаётся тем же самым.
    local rowOpts = setmetatable({ Menu = false }, { __index = opts })

    local row, label, value, _, setHeld, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, nil, rowOpts)

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
    -- Через bindWatch, а не своей подпиской: разбор повода («не моё событие
    -- мимо, не моя привязка мимо, nil значит всех») был выписан тут третьей
    -- копией. Средняя проверка самая ломкая -- забыть `changed ~= nil`, и вид
    -- перестаёт обновляться на общих пересборках; забыть `changed ~= bind`, и
    -- строка перерисовывается от чужих правок. Снятие подписки bindWatch
    -- укладывает в сток контейнера сам.
    NierUI.bindWatch(tab, bind, "key", function()
        render()
        if opts.Changed then pcall(opts.Changed, bind:Key()) end
    end)

    -- СНЕСЛИ СТРОКУ, ПОКА ОНА ЖДАЛА КЛАВИШУ -- ОЖИДАНИЕ НАДО СНЯТЬ.
    --
    -- Четвёртый повод к stopWaiting, и он не про эту строку, а про её
    -- контейнер. Менеджер привязок пересобирает своё содержимое на каждое
    -- добавление и снятие, то есть сносит строки пачками; всплывающее окно
    -- закрывается щелчком мимо. Взведённое ожидание переживало и то, и другое:
    -- отменить его было уже некому -- ни клавиши, ни Escape до снесённой строки
    -- не дойдут, -- и core.grab оставался единицей НАВСЕГДА.
    --
    -- А с ненулевым grab молчат и все привязки, и клавиша открытия меню: она
    -- проверяет keyGrabbed первым делом. Снаружи это выглядит как намертво
    -- залипшее меню, причём без единой ошибки в консоли.
    table.insert(NierUI.sink(tab), { Disconnect = stopWaiting })

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

end)(NierUI)

--============================ NierUI/widgets/Choice.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Radio и Segmented -- выбор без сворачивания в строку
--=============================================================================
--
--     tab:Radio({ Text = "MODE", Options = { "A", "B", "C" }, Default = "A" })
--     tab:Segmented({ Text = "SPEED", Options = { "LOW", "MID", "HIGH" } })
--
-- Оба про одно и то же -- выбрать один вариант из немногих, -- и различаются
-- только формой. Radio занимает строку на вариант и читается с одного взгляда;
-- Segmented умещается в одну строку и годится там, где места мало: в колонке
-- или в половинной ячейке блока.
--
-- Когда вариантов больше пяти-шести, оба проигрывают Dropdown: он сворачивается
-- и умеет прокрутку.

local THEME = NierUI.Theme
local U = NierUI.util

--=============================================================================
-- Radio
--=============================================================================

NierUI.widget("Radio", function(tab, opts)
    local options = opts.Options or {}
    local current = opts.Default
    if current == nil then current = options[1] end

    -- ПРАВОЙ КНОПКИ У НЕГО НЕТ, И ЭТО НЕ УПУЩЕНИЕ.
    --
    -- Radio -- не строка, а НЕСКОЛЬКО строк плюс подпись над ними, и вешать
    -- меню не на что: на подпись -- она не строка вовсе, на каждый вариант --
    -- получится по меню на вариант, чего никто не просил. Сказать об этом
    -- вслух надо потому, что молча поля Menu и Settings просто не делали
    -- ничего, а понять это можно было только по тому, что ничего не
    -- происходит. Нужны настройки при выборе из немногих -- Segmented: он
    -- занимает ровно одну строку, и правая кнопка у него своя.
    if opts.Menu or opts.Settings then
        error(("[NierUI] «%s»: у Radio нет правой кнопки -- он занимает "
            .. "несколько строк, и вешать меню не на что. Возьмите Segmented "
            .. "или Dropdown."):format(tostring(opts.Text or "?")), 0)
    end

    if opts.Text then tab:Label({ Text = opts.Text }) end

    local rows, painters = {}, {}

    local function render(silent)
        for _, paint in ipairs(painters) do paint() end
        NierUI.fire(opts, silent, current)
    end

    for _, option in ipairs(options) do
        local row, _, value, _, _, rowApi =
            NierUI.makeRow(tab, tostring(option), opts.Desc)

        painters[#painters + 1] = function()
            value.Text = current == option and "[ o ]" or "[   ]"
        end

        NierUI.connect(tab, row.MouseButton1Click, rowApi.gate(function()
            if current == option then return end
            current = option
            render()
        end))

        rows[#rows + 1] = rowApi
    end

    render(true)

    if opts.Enabled == false then
        for _, rowApi in ipairs(rows) do rowApi.setEnabled(false) end
    end

    return NierUI.bind(tab, opts, {
        Get = function(_) return current end,
        Set = function(_, v, silent) current = v render(silent) end,
        SetEnabled = function(_, on)
            for _, rowApi in ipairs(rows) do rowApi.setEnabled(on) end
        end,
        IsEnabled = function(_) return rows[1] and rows[1].isEnabled() or false end,
    })
end)

--=============================================================================
-- Segmented
--=============================================================================
--
-- Кнопки занимают правую часть строки -- от той же доли, где у ползунка
-- начинается дорожка, до правого края. Ширина делится поровну, поэтому
-- сегменты остаются одинаковыми и в узкой колонке.

NierUI.widget("Segmented", function(tab, opts)
    local row, _, value, _, _, rowApi = NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)
    value.Text = ""

    local options = opts.Options or {}
    local current = opts.Default
    if current == nil then current = options[1] end

    local left = THEME.TrackRight - THEME.TrackFrac
    local span = 1 - left
    local count = math.max(#options, 1)
    local share = span / count

    -- ЧЕТЫРЕ СОЧЕТАНИЯ, А НЕ ДВА.
    --
    -- Вид сегмента зависит и от выбора, и от подсветки строки. Простой инверсии
    -- тут мало: она подставляет пару значений, а нам нужно решать. Без этого
    -- сегменты оставались чернильными на чернильном фоне подсвеченной строки и
    -- попросту сливались с ней.
    --
    --     не выбран, строка обычная   -- чернильный контур на песке
    --     не выбран, строка подсвечена-- песочный контур на чернилах
    --     выбран,   строка обычная    -- залит чернилами, текст песочный
    --     выбран,   строка подсвечена -- залит песком, текст чернильный
    local painters = {}
    local rowHot = false

    local function render(silent)
        for _, paint in ipairs(painters) do paint() end
        NierUI.fire(opts, silent, current)
    end

    -- Строка перерисовалась -- перерисовываем сегменты, и ничего больше:
    -- render(true) -- это ровно «пройтись по художникам молча». Свой цикл здесь
    -- был вторым путём к тому же самому.
    rowApi.onPaint(function(hot)
        rowHot = hot
        render(true)
    end)

    for index, option in ipairs(options) do
        local segment = U.new("TextButton", {
            BackgroundColor3 = THEME.Ink, BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false,
            Font = THEME.Font, Text = tostring(option),
            TextColor3 = THEME.Ink, TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(left + share * (index - 1), 1,
                0, math.floor(THEME.RowHeight / 2)),
            Size = UDim2.new(share, -12, 0, THEME.RowHeight - 8),
            ZIndex = 3,
        }, row)
        local line = U.stroke(segment, 1)

        painters[#painters + 1] = function()
            local on = current == option
            -- Цвет «чернил» и «песка» меняются местами, когда строка подсвечена.
            local ink = rowHot and THEME.Bg or THEME.Ink
            local paper = rowHot and THEME.Ink or THEME.Bg

            segment.BackgroundColor3 = ink
            segment.BackgroundTransparency = on and 0 or 1
            segment.TextColor3 = on and paper or ink
            line.Color = ink
            line.Transparency = on and 1 or 0.5
        end

        NierUI.connect(tab, segment.MouseButton1Click, rowApi.gate(function()
            if current == option then return end
            current = option
            render()
        end))
    end

    render(true)

    return NierUI.bind(tab, opts, {
        Get = function(_) return current end,
        Set = function(_, v, silent) current = v render(silent) end,
        SetEnabled = function(_, on) rowApi.setEnabled(on) end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)

end)(NierUI)

--============================ NierUI/widgets/Progress.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- Progress -- полоса выполнения
--=============================================================================
--
--     local bar = tab:Progress({ Text = "LOADING", Default = 0 })
--     bar:Set(0.42)                 доля от нуля до единицы
--     bar:SetValue("42 / 100")      своя подпись вместо процентов
--     bar:SetValue(nil)             вернуть проценты
--
-- Только показывает. Ничего не считает и ни на что не подписывается: чем
-- заполнять -- дело вызывающего. Это осознанно, иначе полосе пришлось бы знать
-- про источник данных, а библиотека такого не знает нигде.

-- Ни THEME, ни util здесь больше не нужны: вся геометрия полосы -- в каркасе.

NierUI.widget("Progress", function(tab, opts)
    local row, _, value, invert, _, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)

    -- Геометрия -- та же дорожка, что у ползунка (см. NierUI.makeTrack): те же
    -- доли, поэтому полоса и ползунок в соседних строках стоят вровень. Своего
    -- здесь только толщина: полосу не тянут, и под курсором она не светлеет.
    local _, fill = NierUI.makeTrack(row, invert, 4, 0.8)

    local current = math.clamp(tonumber(opts.Default) or 0, 0, 1)
    local caption = nil

    local function render()
        fill.Size = UDim2.fromScale(current, 1)
        value.Text = caption or ("%d%%"):format(math.floor(current * 100 + 0.5))
    end
    render()

    return NierUI.bind(tab, opts, {
        Get = function(_) return current end,

        -- ВТОРОЙ ПАРАМЕТР Set ВЕЗДЕ ОЗНАЧАЕТ ОДНО И ТО ЖЕ -- «без обратного
        -- вызова». Полоса была единственной строкой, где он значил другое:
        -- подпись. Стоило чему-нибудь позвать общий Set(значение, true) --
        -- конфигу, менеджеру, чужому коду, гасящему группу строк, -- и в поле
        -- уезжало булево значение, а отрисовка падала на присваивании.
        --
        -- Подпись теперь ставится SetValue -- тем же примитивом, каким её
        -- ставит кнопка. Одно имя на одно действие во всей библиотеке.
        Set = function(_, fraction, silent)
            if type(silent) == "string" then
                error(("[NierUI] строка «%s»: Set(доля, подпись) больше нет -- "
                    .. "подпись ставится :SetValue(текст)")
                    :format(tostring(opts.Text or "?")), 2)
            end
            current = math.clamp(tonumber(fraction) or 0, 0, 1)
            render()
        end,

        -- Своя подпись вместо процентов; nil возвращает проценты.
        SetValue = function(_, text)
            caption = text ~= nil and tostring(text) or nil
            render()
        end,
        -- Пара доступности есть у ВСЕХ обработчиков, и полоса не исключение:
        -- README обещает её всем, а тот, кто гасит группу строк разом, не
        -- обязан помнить, какая из них показывает, а какая принимает ввод.
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Заливка -- не текст, общее приглушение подписей до неё не
            -- достаёт; гасим отдельно, как образец у палитры.
            --
            -- Сравнение с false, а не просто `on and ...`: доступность во всей
            -- библиотеке -- это `state ~= false`, то есть SetEnabled() без
            -- аргумента ВКЛЮЧАЕТ строку. Здесь же nil гасил заливку -- строка
            -- отзывалась, а выглядела выключенной.
            fill.BackgroundTransparency = on ~= false and 0 or 0.6
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)

end)(NierUI)

--============================ NierUI/widgets/ColorPicker.luau ============================
;(function(NierUI)
--!nocheck
--=============================================================================
-- ColorPicker -- строка с палитрой
--=============================================================================
--
-- Сама палитра живёт в NierUI.colorControl и здесь только встраивается: тот же
-- контрол используется во всплывающем окне настроек пункта списка. Держать две
-- копии этой геометрии значило бы получить через месяц две разные палитры.

local THEME = NierUI.Theme
local U = NierUI.util

local FIELD_HEIGHT = 100
-- место под HEX-строку берём у самого контрола, а не подгоняем числом
local PANEL_HEIGHT = FIELD_HEIGHT + NierUI.colorControlExtra + 20

NierUI.widget("ColorPicker", function(tab, opts)
    local row, _, value, invert, setHeld, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)

    -- Образец встаёт по той же доле, что и дорожка ползунка (см. Theme):
    -- жёсткий отступ от правого края не пережил бы половинной ширины ячейки.
    local swatch = U.new("Frame", {
        BackgroundColor3 = opts.Default or Color3.fromRGB(255, 40, 40),
        BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(THEME.TrackRight, 0, 0, math.floor(THEME.RowHeight / 2)),
        Size = UDim2.fromOffset(28, 12), ZIndex = 3,
    }, row)
    local swatchLine = U.stroke(swatch, 1)
    -- Обводка образца обязана инвертироваться: чернильная рамка на чернильном
    -- фоне под курсором исчезла бы, и образец повис бы в воздухе.
    invert(swatchLine, "Color", THEME.Bg, THEME.Ink)

    local panel, setPanel = NierUI.makePanel(row, PANEL_HEIGHT)

    -- ВИД СТРОКИ -- ОТДЕЛЬНО ОТ ОБРАТНОГО ВЫЗОВА.
    --
    -- Образец и код цвета рисовались прямо в обработчике, который уходит
    -- наружу, а он гасится тишиной. Значит Set(цвет, true) -- загрузка профиля
    -- у строки с Apply = false -- менял палитру внутри и НЕ менял ни квадрат, ни
    -- подпись: строка показывала прежний цвет, а хранила новый. Тишина гасит
    -- обратный вызов вызывающего, а не осведомлённость самого меню.
    local function show(c)
        swatch.BackgroundColor3 = c
        value.Text = U.hex(c)
    end

    local control = NierUI.colorControl(panel, {
        Position = UDim2.fromOffset(12, 10),
        Height = FIELD_HEIGHT,
        Color = opts.Default,
        -- Палитра слушает мышь глобально и обязана уметь отключаться: сток
        -- берём у контейнера, а не у окна. Во временном контейнере эти две
        -- подписки иначе переживали бы его.
        sink = NierUI.sink(tab),
        ZIndex = 30,
        Callback = function(c)
            show(c)
            NierUI.fire(opts, false, c)
        end,
    })
    -- Ширину контрол берёт от родителя (Width ему не задан), оставляем поля по
    -- краям; высоту не трогаем -- он сам знает про свою HEX-строку.
    control.instance.Size = UDim2.new(1, -24, 0, FIELD_HEIGHT + NierUI.colorControlExtra)

    show(control.Get())

    -- Раскрытие щелчком по строке -- в каркасе (см. NierUI.rowExpand), вместе
    -- со сторожем «щелчок пришёлся ВНУТРЬ раскрытой палитры -- строку не
    -- трогаем». Тот же самый, что у списка: держать его в двух местах значило
    -- бы однажды починить одно и оставить второе.
    local setOpen = NierUI.rowExpand(tab, row, rowApi, panel, function(state)
        setPanel(state)
        setHeld(state)
    end)

    return NierUI.bind(tab, opts, {
        Get = function(_) return control.Get() end,
        -- Вид строки обновляем ВСЕГДА, даже когда просили молчать: см. show.
        Set = function(_, c, silent)
            control.Set(c, silent)
            show(control.Get())
        end,
        SetEnabled = function(_, on)
            rowApi.setEnabled(on)
            -- Образец цвета гасим вручную: он не текст, и общее приглушение
            -- подписей до него не достаёт. Сравнение с false, а не просто
            -- `on and ...`: доступность везде -- это `state ~= false`, и
            -- SetEnabled() без аргумента строку ВКЛЮЧАЕТ.
            swatch.BackgroundTransparency = on ~= false and 0 or 0.6
            -- Раскрытую палитру схлопываем: иначе она останется висеть поверх
            -- соседних строк, а закрыть её будет уже нечем.
            if not on then setOpen(false) end
        end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)

end)(NierUI)

return NierUI
