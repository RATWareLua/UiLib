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
function U.guiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local ok = pcall(function() return CoreGui.Name end)
    if ok then return CoreGui end
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

-- Доля вдоль объекта по координате мыши: пригодится и ползунку, и палитре.
function U.alongX(inst, x)
    return math.clamp((x - inst.AbsolutePosition.X) / math.max(inst.AbsoluteSize.X, 1), 0, 1)
end

function U.alongY(inst, y)
    return math.clamp((y - inst.AbsolutePosition.Y) / math.max(inst.AbsoluteSize.Y, 1), 0, 1)
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
    local pos = 1
    while true do
        local from, to = haystack:find("[%w\128-\255]+", pos)
        if not from then break end
        if haystack:sub(from, from + length - 1) == needle then return 1, from end
        pos = to + 1
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
