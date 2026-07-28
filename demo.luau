--!nocheck
--=============================================================================
-- demo -- витрина NierUI
--=============================================================================
--
-- Собирается вместе с библиотекой в dist\NierUIDemo.luau.
--
--   Delete                     открыть / закрыть
--   getgenv().__nierDemo:Destroy()   снять начисто

local ENV = getgenv and getgenv() or _G
if ENV.__nierDemo then pcall(function() ENV.__nierDemo:Destroy() end) end

local win = NierUI:Window({
    Title = "VIOLENCE DISTRICT",
    Subtitle = "SYSTEM MENU / v1.0",
    Hint = "hover a row to read what it does",
})
ENV.__nierDemo = win

--== вкладка с переключателями ===============================================

local combat = win:Tab("COMBAT")

combat:Label("PASSIVE")
combat:Toggle({
    Text = "LUNGE",
    Desc = "Extends the lunge window. Held per frame, nothing is written to the tree.",
    Default = true, Flag = "lunge",
    Callback = function(on) print("[demo] lunge:", on) end,
})
combat:Toggle({
    Text = "NO COOLDOWN",
    Desc = "Removes the attack cooldown. Server never sees the value.",
    Callback = function(on) print("[demo] cooldown:", on) end,
})
combat:Toggle({
    Text = "NO SLOWDOWN",
    Desc = "Keeps walk speed after a swing.",
    Callback = function(on) print("[demo] slowdown:", on) end,
})

combat:Divider()
combat:Label("DEPENDENCY")

-- Недоступное состояние: строки ниже живут, только пока включена эта.
local dependent = {}

combat:Toggle({
    Text = "MASTER",
    Desc = "Turns the two rows below on and off.",
    Default = true, Flag = "master",
    Callback = function(on)
        for _, handle in ipairs(dependent) do handle:SetEnabled(on) end
    end,
})

dependent[#dependent + 1] = combat:Slider({
    Text = "DEPENDS SLIDER",
    Desc = "Greyed out and unresponsive while MASTER is off.",
    Min = 0, Max = 10, Default = 5, Flag = "depSlider",
})
dependent[#dependent + 1] = combat:ColorPicker({
    Text = "DEPENDS COLOUR",
    Desc = "Its swatch dims too, and the palette cannot be opened.",
    Default = Color3.fromRGB(120, 180, 255), Flag = "depColour",
})

combat:Divider()
combat:Label("TUNING")

combat:Slider({
    Text = "WALK SPEED",
    Desc = "Base walk speed. Composed on top of the game value, not overwritten.",
    Min = 16, Max = 60, Default = 24, Flag = "walkSpeed",
    Callback = function(v) print("[demo] speed:", v) end,
})
combat:Slider({
    Text = "REACH",
    Desc = "Interaction distance in studs.",
    Min = 5, Max = 40, Default = 12, Step = 1,
    Callback = function(v) print("[demo] reach:", v) end,
})

--== вкладка с прочими элементами ============================================

local visuals = win:Tab("VISUALS")

visuals:Toggle({
    Text = "ESP",
    Desc = "Highlights players. Lives in CoreGui, the server cannot see it.",
    Default = true,
    Callback = function(on) print("[demo] esp:", on) end,
})
-- Двадцать пять пунктов -- это и есть проверка: без ограничения высоты список
-- вытянулся бы на 650 пикселей при панели в 420.
local MASKS = {
    "RICHARD / ROOSTER", "RASMUS / OWL", "TONY / TIGER",
    "AUBREY / PIG", "DON JUAN / HORSE", "DENNIS / WOLF",
    "GEORGE / GIRAFFE", "BRANDON / RABBIT", "TED / DOG",
    "RAMI / CAMEL", "JAKE / COBRA", "GRAHAM / PANTHER",
    "OSCAR / BEAR", "ZACK / CHAMELEON", "PETER / UNICORN",
    "NIGEL / FROG", "EARL / BAT", "CHARLIE / OCTOPUS",
    "WILLEM / BULL", "PHIL / FISH", "LOUIE / ELK",
    "RUFUS / ELEPHANT", "CARL / GRASSHOPPER", "RICK / SQUIRREL",
    "STANLEY / CLOWN",
}

visuals:Dropdown({
    Text = "MASK",
    Desc = "Single choice. Closes on pick, square marks the active one.",
    Options = MASKS,
    Default = "RICHARD / ROOSTER",
    Callback = function(v) print("[demo] mask:", v) end,
})

-- Тот же длинный список, но множественный: закрываться на каждом щелчке он не
-- должен, а в значении строки должно стоять число.
local unlocked = visuals:MultiDropdown({
    Text = "UNLOCKED",
    Desc = "Multiple choice. Stays open, counts what is picked.",
    Options = MASKS,
    Default = { "RICHARD / ROOSTER", "DENNIS / WOLF", "TONY / TIGER" },
    Callback = function(list) print("[demo] unlocked:", #list, table.concat(list, ", ")) end,
})
ENV.__nierMulti = unlocked

-- Настройки отдельных пунктов: ПКМ по пункту с меткой справа. У NAMES и BOX
-- свой цвет, у BOX ещё и выключатель. DISTANCE и WEAPON настроек не имеют и на
-- правую кнопку не отзываются.
visuals:MultiDropdown({
    Text = "SHOW",
    Desc = "Right-click a marked item for its own settings.",
    Options = { "NAMES", "HEALTH", "DISTANCE", "BOX", "WEAPON" },
    Default = { "NAMES", "DISTANCE" }, Flag = "espShow",
    Settings = {
        NAMES  = { Color = Color3.fromRGB(255, 255, 255) },
        HEALTH = { Color = Color3.fromRGB(80, 220, 100) },
        BOX    = { Color = Color3.fromRGB(255, 60, 60), Outline = true },
    },
    Callback = function(list) print("[demo] show:", table.concat(list, ", ")) end,
    OnSetting = function(option, key, value)
        print("[demo] setting:", option, key, value)
    end,
})

-- Короткий список рядом -- чтобы видеть, что ограничение включается только
-- когда нужно, и три пункта не превращаются в окно с прокруткой.
-- Настройки пунктов работают и в одиночном списке -- механизм общий.
visuals:Dropdown({
    Text = "OUTLINE",
    Desc = "Single list, and its items can carry settings too.",
    Options = { "THIN", "THICK", "OFF" },
    Default = "THIN",
    Settings = {
        THIN  = { Color = Color3.fromRGB(30, 30, 30) },
        THICK = { Color = Color3.fromRGB(0, 0, 0), Glow = false },
    },
    Callback = function(v) print("[demo] outline:", v) end,
    OnSetting = function(option, key, value)
        print("[demo] outline setting:", option, key, value)
    end,
})
visuals:Keybind({
    Text = "PANIC",
    Desc = "Press to unload everything at once.",
    Default = Enum.KeyCode.G,
    Callback = function() print("[demo] panic!") end,
    Changed = function(key) print("[demo] rebound to", key.Name) end,
})

visuals:Divider()

visuals:ColorPicker({
    Text = "ENEMY",
    Desc = "Colour picker: hue bar on the right, saturation field on the left.",
    Default = Color3.fromRGB(255, 40, 40), Flag = "enemyColour",
    Callback = function(c) print("[demo] enemy colour:", c) end,
})
visuals:ColorPicker({
    Text = "ALLY",
    Desc = "Second picker -- both keep their own state.",
    Default = Color3.fromRGB(60, 200, 90),
    Callback = function(c) print("[demo] ally colour:", c) end,
})
visuals:Slider({
    Text = "FILL",
    Desc = "Fractional slider: Step = 0.05 gives two decimals.",
    Min = 0, Max = 1, Step = 0.05, Default = 0.6,
    Callback = function(v) print("[demo] fill:", v) end,
})

--== вкладка с кнопками ======================================================

local system = win:Tab("SYSTEM")

--== ввод и конфиг ===========================================================

system:Label("CONFIG")

system:InputText({
    Text = "NAME",
    Desc = "Free text input: the name SAVE will write to.",
    Default = "default",
    Placeholder = "name",
    MaxLength = 24,
    -- Имя есть, сохранения нет: профиль, хранящий собственное имя, бессмыслен.
    Flag = "profileName", Save = false,
    Callback = function(text) print("[demo] profile name:", text) end,
})

local function profileName()
    local handle = win.flags.profileName
    local name = handle and handle:Get() or ""
    return name ~= "" and name or "default"
end

-- Список профилей -- обычный динамический список: тот же Refresh, что и у
-- всего остального. Отдельного механизма под это не понадобилось.
local profileList = system:Dropdown({
    Text = "PROFILE",
    Desc = "Pick a saved profile, then LOAD or DELETE it.",
    Options = win:Profiles(),
})

local function refreshProfiles()
    profileList:Refresh(win:Profiles())
end

system:Button({
    Text = "SAVE",
    Desc = "Write every flagged widget into a profile named above.",
    Callback = function()
        local name = profileName()
        local ok, err = win:Save(name)
        refreshProfiles()
        win:Notify({
            Title = "CONFIG",
            Text = ok and ("Saved: " .. name) or ("Save failed: " .. tostring(err)),
        })
    end,
})
system:Button({
    Text = "LOAD",
    Desc = "Apply the profile selected above.",
    Callback = function()
        local chosen = profileList:Get()
        if not chosen then
            win:Notify({ Title = "CONFIG", Text = "No profile selected." })
            return
        end
        local ok, applied = win:Load(chosen)
        win:Notify({
            Title = "CONFIG",
            Text = ok and ("Loaded " .. tostring(applied) .. " values from " .. chosen)
                or "Profile not found.",
        })
    end,
})
system:Button({
    Text = "DELETE",
    Desc = "Remove the selected profile.",
    Callback = function()
        local chosen = profileList:Get()
        if not chosen then return end
        win:DeleteProfile(chosen)
        refreshProfiles()
        win:Notify({ Title = "CONFIG", Text = "Deleted: " .. chosen })
    end,
})

system:Divider()
system:Label("ACTIONS")
system:Button({
    Text = "REJOIN",
    Desc = "Rejoin the same server.",
    Callback = function() print("[demo] rejoin") end,
})
system:Button({
    Text = "UNLOAD",
    Desc = "Remove the menu and every hook.",
    Callback = function() win:Destroy() end,
})

system:Divider()

--== динамический список =====================================================
--
-- Библиотека не знает и не должна знать, откуда берутся пункты. Здесь их
-- поставляет сама витрина кнопками; снаружи точно так же подставляется что
-- угодно -- игроки, предметы, камни в игре про Гималаи.

local pool, counter = {}, 0
local dynamic

local function push()
    counter = counter + 1
    pool[#pool + 1] = {
        Text = ("ENTRY %02d"):format(counter),
        Key = counter,                                  -- ключ отдельно от подписи
        Settings = { Color = Color3.fromRGB(200, 200, 200) },
    }
end

dynamic = system:MultiDropdown({
    Text = "DYNAMIC",
    Desc = "Rebuilt from outside. Add entries and watch it scroll.",
    Options = pool,
    Callback = function(list) print("[demo] dynamic:", #list) end,
    OnSetting = function(key, field, v) print("[demo] dynamic setting:", key, field, v) end,
})

system:Button({
    Text = "ADD ENTRY",
    Desc = "Append one and rebuild.",
    Callback = function() push() dynamic:Refresh(pool) end,
})
system:Button({
    Text = "ADD TEN",
    Desc = "Enough to make the list scroll.",
    Callback = function()
        for _ = 1, 10 do push() end
        dynamic:Refresh(pool)
    end,
})
system:Button({
    Text = "REMOVE LAST",
    Desc = "Selection of a vanished key survives until PRUNE.",
    Callback = function()
        if #pool > 0 then
            pool[#pool] = nil
            dynamic:Refresh(pool)
        end
    end,
})
system:Button({
    Text = "PRUNE",
    Desc = "Forget selections and settings of keys no longer present.",
    Callback = function() dynamic:Prune() end,
})

--== триггеры ================================================================
--
-- Условие пишет пользователь, меню его обрабатывает. Библиотека не знает, что
-- такое игрок: ей передали сигнал и предикат, она взяла на себя время жизни
-- подписки, выключатель и показ уведомления.

local Players = game:GetService("Players")

local function roster()
    local out = {}
    for _, player in ipairs(Players:GetPlayers()) do
        out[#out + 1] = { Text = player.DisplayName, Key = player.UserId }
    end
    return out
end

local players = system:MultiDropdown({
    Text = "PLAYERS",
    Desc = "Rebuilt by triggers on join and leave.",
    Options = roster(),
    Flag = "playerPicks",
})

local joinTrigger = win:Trigger({
    Name = "playerJoin",
    Signal = Players.PlayerAdded,
    Title = "PLAYER",
    Message = function(player) return player.DisplayName .. " joined" end,
    Action = function() players:Refresh(roster()) end,
})

local leaveTrigger = win:Trigger({
    Name = "playerLeave",
    Signal = Players.PlayerRemoving,
    Title = "PLAYER",
    Message = function(player) return player.DisplayName .. " left" end,
    -- Список перестраиваем ПОСЛЕ ухода: в момент сигнала игрок ещё в списке.
    Action = function() task.defer(function() players:Refresh(roster()) end) end,
})

system:Toggle({
    Text = "NOTIFY JOINS",
    Desc = "Turns both triggers on and off. Saved with the profile.",
    Default = true, Flag = "notifyPlayers",
    Callback = function(on)
        joinTrigger:Set(on)
        leaveTrigger:Set(on)
    end,
})

system:Slider({
    Text = "NOTIFY TIME",
    Desc = "Lifetime of the notifications below, in seconds.",
    Min = 1, Max = 15, Step = 0.5, Default = 4, Suffix = "s",
    Flag = "notifyTime",
})

system:Button({
    Text = "NOTIFY x3",
    Desc = "Three at once -- watch them stack, then leave.",
    Callback = function()
        local seconds = win.flags.notifyTime:Get()
        for i = 1, 3 do
            win:Notify({
                Title = "TEST " .. i,
                Text = ("Notification %d, living for %s seconds."):format(i, seconds),
                Duration = seconds,
            })
        end
    end,
})

system:Button({
    Text = "TEST TRIGGER",
    Desc = "Fire the join trigger by hand, without waiting for anyone.",
    Callback = function() joinTrigger:Fire(Players.LocalPlayer) end,
})

system:Divider()
system:Label("Delete toggles this window. Drag it by the header.")

--== секции, колонки и остальные элементы ====================================

local more = win:Tab("MORE")

local group = more:Section("COLLAPSIBLE GROUP")
group:Toggle({ Text = "INSIDE ONE", Default = true })
group:Toggle({ Text = "INSIDE TWO" })
group:Slider({ Text = "INSIDE LEVEL", Min = 0, Max = 100, Default = 30 })

local folded = more:Section("FOLDED BY DEFAULT", { Open = false })
folded:Label({ Text = "Скрыто, пока не раскроешь заголовок." })
folded:Button({ Text = "HIDDEN ACTION" })

more:Divider()

-- Колонки: делят место, а не строку. Виджеты внутри ничего не знают о них.
local left, right = more:Split(2)
left:Label({ Text = "LEFT" })
left:Toggle({ Text = "ONE", Default = true })
left:Slider({ Text = "LEVEL", Min = 0, Max = 10, Default = 4 })
right:Label({ Text = "RIGHT" })
right:Toggle({ Text = "TWO" })
right:ColorPicker({ Text = "TINT", Default = Color3.fromRGB(200, 120, 60) })

more:Divider()

more:Segmented({
    Text = "SPEED",
    Desc = "Segmented choice: fits one row, good in narrow columns.",
    Options = { "LOW", "MID", "HIGH" },
    Default = "MID", Flag = "speedMode",
    Callback = function(v) print("[demo] speed mode:", v) end,
})

more:Radio({
    Text = "TARGET MODE",
    Desc = "Radio: one row per option, readable at a glance.",
    Options = { "NEAREST", "LOWEST HP", "CROSSHAIR" },
    Default = "NEAREST", Flag = "targetMode",
    Callback = function(v) print("[demo] target mode:", v) end,
})

more:Divider()

local progress = more:Progress({ Text = "PROGRESS", Desc = "Display only.", Default = 0 })

-- Метка запуска. Каждое нажатие заводит новый номер, и отложенные шаги старого
-- запуска, увидев чужой номер, молча выходят.
--
-- Без этого повторные нажатия перемешивались: шаги двух заходов приходили
-- вперемешку, и полоса дёргалась туда-сюда. Отменить уже назначенный task.delay
-- нечем, поэтому шаг должен уметь сам понять, что он лишний.
local progressRun = 0

more:Button({
    Text = "RUN PROGRESS",
    Desc = "Fills the bar over two seconds. Only the last press counts.",
    Callback = function()
        progressRun = progressRun + 1
        local run = progressRun
        progress:Set(0, "0 / 10")
        for i = 1, 10 do
            task.delay(i * 0.2, function()
                if run ~= progressRun then return end
                progress:Set(i / 10, ("%d / 10"):format(i))
            end)
        end
    end,
})

more:Button({
    Text = "CONFIRM DIALOG",
    Desc = "Modal in the middle of the screen.",
    Callback = function()
        win:Confirm({
            Title = "CONFIRM",
            Text = "Это модальное окно. Оно встаёт по центру и закрывается щелчком мимо.",
            Confirm = "YES", Cancel = "NO",
            OnConfirm = function() win:Notify({ Title = "MODAL", Text = "Confirmed." }) end,
            OnCancel = function() win:Notify({ Title = "MODAL", Text = "Cancelled." }) end,
        })
    end,
})

more:Divider()

-- Счётчик нажатий -- прикладная логика, поэтому он ЗДЕСЬ, а не в библиотеке.
-- Кнопка умеет только показать то, что ей дали; считает вызывающий.
local clicks = 0
local clickButton

clickButton = more:Button({
    Text = "CLICK ME",
    Desc = "The count lives in the demo, not in the library.",
    Value = "0",
    Callback = function()
        clicks = clicks + 1
        clickButton:SetValue(clicks)
        if clicks % 10 == 0 then
            win:Notify({ Title = "CLICKS", Text = ("Round number: %d"):format(clicks) })
        end
    end,
})

more:Button({
    Text = "RESET COUNTER",
    Callback = function()
        clicks = 0
        clickButton:SetValue(0)
    end,
})

more:Dropdown({
    Text = "SEARCHABLE",
    Desc = "Twenty five options with a filter line on top.",
    Options = MASKS,
    Search = true,
    Default = "RICHARD / ROOSTER",
})

--== блоки ===================================================================
--
-- Четыре ячейки: две с полными координатами и одна полоса, которая ужимается
-- под них. Порядок объявления намеренно «неудобный» -- полоса объявлена ПЕРВОЙ,
-- а ужаться обязана под блоки, объявленные после неё.

NierUI.Theme.BlockSeparators = true

local grid = win:Tab("BLOCKS")

local rightBand = grid:Block("Right", "RIGHT BAND")
rightBand:Label("Одна ось: занял бы обе правые клетки,")
rightBand:Label("но ниже объявлен Right+Down, поэтому")
rightBand:Label("остался только правый верхний угол.")

local leftTop = grid:Block("Left", "Up", "LEFT TOP")
leftTop:Toggle({ Text = "ONE", Desc = "Строка в половинной ячейке.", Default = true })
leftTop:Slider({ Text = "AMOUNT", Min = 0, Max = 100, Default = 40,
    Desc = "Дорожка и поле держатся долями ширины." })

local leftBottom = grid:Block("Left", "Down", "LEFT BOTTOM")
leftBottom:Dropdown({
    Text = "PICK",
    Desc = "Раскрытый список уезжает в прокрутку блока.",
    Options = { "ALPHA", "BETA", "GAMMA", "DELTA", "EPSILON", "ZETA", "ETA" },
})
leftBottom:ColorPicker({ Text = "TINT", Default = Color3.fromRGB(120, 180, 255) })

local rightBottom = grid:Block("Right", "Down", "RIGHT BOTTOM")
for i = 1, 8 do
    rightBottom:Toggle({ Text = ("ROW %d"):format(i),
        Desc = "Содержимое длиннее ячейки -- блок листается." })
end

print("[NierUI] демо готово. Delete -- открыть/закрыть")
print("[NierUI] снять: getgenv().__nierDemo:Destroy()")
