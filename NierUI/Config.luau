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
