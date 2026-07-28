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
--     EnumItem      -> { __t = "k", v = "LeftShift" }
-- Разворачивается обратно по той же пометке. Обычные таблицы (набор
-- множественного выбора, настройки пунктов) проходят рекурсией как есть.
--
--
-- ЗАГРУЗКА ЗОВЁТ ОБРАТНЫЕ ВЫЗОВЫ, И ЭТО НАМЕРЕННО
--
-- Молча выставить значения означало бы, что меню показывает включённое, а
-- фичи выключены. Профиль должен ПРИМЕНЯТЬСЯ, а не только отображаться.

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

local function encode(value)
    local kind = typeof(value)

    if kind == "Color3" then
        return { __t = "c", v = U.hex(value) }
    elseif kind == "EnumItem" then
        return { __t = "k", v = value.Name }
    elseif kind == "table" then
        local out = {}
        for k, v in pairs(value) do out[k] = encode(v) end
        return out
    end

    return value
end

local function decode(value)
    if type(value) ~= "table" then return value end

    if value.__t == "c" then
        return U.fromHex(value.v)
    end

    if value.__t == "k" then
        -- Клавиша могла исчезнуть между версиями движка -- pcall, а не вера.
        local ok, key = pcall(function() return Enum.KeyCode[value.v] end)
        return ok and key or nil
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

            local value = decode(entry.value)
            if value ~= nil then
                local ok = pcall(handle.Set, handle, value)
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
