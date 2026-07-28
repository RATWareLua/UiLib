# NierUI

Библиотека меню в стиле NieR:Automata для Roblox-скриптов.

Без внешних зависимостей и без единого ассета: шрифт берётся встроенный,
палитра собрана из градиентов, фактура фона рисуется процедурно в рантайме.
Грузить нечего, модерировать нечего, перестать открываться нечему.

---

## Подключение

Публиковать нужно `dist/NierUI.luau` — это вся библиотека одним файлом.

```lua
local NierUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ПОЛЬЗОВАТЕЛЬ/РЕПОЗИТОРИЙ/main/dist/NierUI.luau"
))()
```

Файлы в `NierUI/` — исходники. Сборка одним файлом делается `build.ps1`,
`dist/NierUIDemo.luau` — витрина со всеми элементами, её можно запустить и
посмотреть.

---

## Минимальный пример

```lua
local win = NierUI:Window({
    Title = "MY SCRIPT",
    Subtitle = "v1.0",
    ToggleKey = Enum.KeyCode.Delete,
})

local tab = win:Tab("MAIN")

tab:Toggle({
    Text = "ESP",
    Desc = "Подсветка игроков.",
    Default = false,
    Flag = "esp",
    Callback = function(on) print("esp:", on) end,
})

tab:Slider({
    Text = "SPEED",
    Min = 16, Max = 100, Default = 16,
    Flag = "speed",
    Callback = function(v) print("speed:", v) end,
})
```

---

## Окно

```lua
local win = NierUI:Window({
    Title     = "MY SCRIPT",        -- заголовок
    Subtitle  = "v1.0",             -- подпись под ним
    Hint      = "подсказка снизу",  -- начальный текст нижней панели
    Name      = "myscript",         -- имя папки профилей; иначе берётся Title
    Width     = 644, Height = 483,
    Position  = UDim2.fromScale(0.5, 0.5),
    ToggleKey = Enum.KeyCode.Delete,
})

win:Toggle()        -- показать/спрятать
win:Toggle(false)   -- явно
win:Hint("текст")   -- нижняя панель
win:Destroy()       -- снять полностью
```

`Destroy` гасит все подписки, всплывающие окна и уведомления и уничтожает
`ScreenGui`. После него не остаётся ничего.

**Важно при разработке.** Скрипт, который перезапускают, обязан снимать
прошлое окно сам, иначе они накопятся:

```lua
if getgenv().__myWindow then getgenv().__myWindow:Destroy() end
getgenv().__myWindow = win
```

---

## Контейнеры

Виджеты не знают, куда их кладут. Вкладка, блок, секция и колонка — всё это
контейнеры с одинаковым набором методов, и любой виджет работает в любом из них.

### Вкладки

```lua
local tab = win:Tab("COMBAT")
```

### Блоки — сетка до 2×2 внутри вкладки

```lua
local lt = tab:Block("Left", "Up", "ЛЕВЫЙ ВЕРХ")   -- своя клетка
local rb = tab:Block("Right", "Down")
local band = tab:Block("Right")                    -- вся правая полоса
local single = tab:Block()                         -- на всю страницу
```

Порядок аргументов свободный, ось узнаётся по слову: `Block("Up")` работает
так же, как `Block(nil, "Up")`. Третья строка — заголовок блока.

Правила размещения, по конкретности и **независимо от порядка объявления**:

- обе оси — блок получает ровно свою клетку;
- одна ось — занимает всю полосу, но только из того, что осталось свободным;
- без осей — всю страницу, и только если он один.

Спорные случаи дают явную ошибку, а не размещение наугад: две клетки с
одинаковыми координатами, две одинаковые полосы, `Left` и `Up` в споре за один
угол, полоса без свободных клеток, безпараметрный блок рядом с другими.

Строки и блоки в одной вкладке несовместимы — либо то, либо другое.

### Секции — складные группы

```lua
local group = tab:Section("PASSIVE")
group:Toggle({ Text = "ONE" })

local folded = tab:Section("EXTRA", { Open = false })
```

### Колонки

```lua
local left, right = tab:Split(2)
left:Toggle({ Text = "A" })
right:Toggle({ Text = "B" })
```

`Split` делит место, а не строку: виджеты внутри считают, что занимают всю
ширину, потому что для них это правда.

---

## Виджеты

Общие поля у всех: `Text`, `Desc` (текст нижней панели при наведении),
`Flag`, `Save`, `Enabled`, `Callback`.

Общее у всех обработчиков: `:Get()`, `:Set(v)`, `:SetEnabled(on)`, `:IsEnabled()`.

```lua
tab:Toggle({ Text = "ESP", Default = false, Callback = function(on) end })

tab:Button({ Text = "REJOIN", Value = ">", Callback = function() end })
-- :SetValue(text) -- поставить свою подпись справа

tab:Label({ Text = "ЗАГОЛОВОК" })      -- или tab:Label("ЗАГОЛОВОК")
tab:Divider()

tab:Slider({ Text = "SPEED", Min = 16, Max = 100, Step = 1,
             Default = 16, Suffix = " ст/с", Callback = function(v) end })
-- по числу можно щёлкнуть и ввести руками

tab:InputText({ Text = "WEBHOOK", Placeholder = "https://...",
                MaxLength = 200, Width = 0.42,
                Callback = function(text) end,   -- по завершении ввода
                Changed  = function(text) end })

tab:Dropdown({ Text = "MASK", Options = { "A", "B" }, Default = "A",
               MaxVisible = 6, Search = true, Callback = function(v) end })

tab:MultiDropdown({ Text = "ESP", Options = { "A", "B" }, Default = { "A" },
                    Callback = function(list) end })

tab:Keybind({ Text = "PANIC", Default = Enum.KeyCode.G,
              Callback = function(key) end,     -- нажали привязанную клавишу
              Changed  = function(key) end })   -- переназначили

tab:ColorPicker({ Text = "ENEMY", Default = Color3.fromRGB(255, 40, 40),
                  Callback = function(c) end })

tab:Radio({ Text = "MODE", Options = { "A", "B" }, Default = "A" })
tab:Segmented({ Text = "SPEED", Options = { "LOW", "MID", "HIGH" } })

local bar = tab:Progress({ Text = "LOADING", Default = 0 })
bar:Set(0.42)               -- доля 0..1
bar:Set(0.42, "42 / 100")   -- своя подпись вместо процентов
```

### Списки: форма пункта

```lua
"NAMES"                                       строка = и ключ, и подпись
{ Text = "Игрок", Key = 12345 }               ключ отдельно от подписи
{ Text = ..., Key = ..., Settings = {...} }   плюс свои настройки пункта
```

Раздельные ключ и подпись нужны там, где подписи могут совпадать: на строковом
ключе два разных объекта склеятся в один пункт.

### Списки: динамика

```lua
dd:Refresh(newOptions)   -- заменить набор целиком
dd:Options()             -- текущие ключи
dd:Prune()               -- забыть выбор и настройки исчезнувших ключей
```

Выбор и настройки хранятся **по ключу** и переживают пересборку. Исчезнувший
ключ не стирается: его некому показать, и в `Get` он не попадёт. Вернулся ключ —
вернулась отметка. Явная зачистка — `Prune`.

### Списки: настройки отдельных пунктов

Правая кнопка по пункту открывает его настройки. Пункт «с настройками» — это
просто пункт, у которого есть запись в `Settings`; остальные на правую кнопку
не отзываются и помечаются точкой справа.

```lua
tab:MultiDropdown({
    Options = { "NAMES", "BOX", "DISTANCE" },
    Settings = {
        NAMES = { Color = Color3.new(1, 1, 1) },
        BOX   = { Color = Color3.new(1, 0, 0), Outline = true },
    },
    OnSetting = function(key, field, value) end,
})

dd:GetSetting("BOX", "Color")
dd:SetSetting("BOX", "Outline", false)
```

Тип контрола выводится из значения по умолчанию: `Color3` — образец с палитрой,
`boolean` — переключатель, `EnumItem` — захват клавиши (`Escape` отменяет).

### Настройки у обычной строки

Тот же механизм доступен любому `Toggle`, а не только пунктам списка. Строка с
настройками помечается точкой справа.

```lua
tab:Toggle({
    Text = "ПОЛЁТ",
    Settings = { Клавиша = Enum.KeyCode.F, Цвет = Color3.new(1, 0, 0) },
    OnSetting = function(field, value) ... end,
})
```

Настройки строки **идут в профиль** наравне со значением: клавиша, цвет и режим —
такие же настройки, как сам тумблер. При загрузке профиля вызывается
`OnSetting`, поэтому значение не просто запоминается, а применяется.

### Поиск в списках

`Search = true` добавляет строку фильтра. Находки **ранжируются**, а не просто
отбираются:

| разряд | что значит | пример |
|---|---|---|
| 0 | строка начинается с запроса | `NI` → `NIGEL` |
| 1 | с запроса начинается слово | `WO` → `DENNIS / WOLF` |
| 2 | подстрока где угодно | `NI` → `DENNIS` |
| 3 | буквы по порядку, но не подряд | `dnw` → `DENNIS / WOLF` |

Разряд 3 по умолчанию выключен. Режимы: `"prefix"`, `"word"`, `"substring"`
(он же `true`), `"fuzzy"`.

---

## Уведомления

```lua
win:Notify({ Title = "PLAYER", Text = "Кто-то зашёл", Duration = 6 })
```

Выезжают из-за правого края, стопкой, снизу убывающая полоска остатка. Живут на
`ScreenGui` рядом с окном, поэтому **показываются и при закрытом меню**.

---

## Триггеры

Условие пишет пользователь, меню его обрабатывает.

```lua
local Players = game:GetService("Players")

local join = win:Trigger({
    Name    = "playerJoin",
    Signal  = Players.PlayerAdded,                        -- любой RBXScriptSignal
    Filter  = function(p) return p ~= Players.LocalPlayer end,
    Title   = "PLAYER",
    Message = function(p) return p.DisplayName .. " зашёл" end,
    Action  = function(p) list:Refresh(roster()) end,
    Flag    = "notifyJoin",
})

join:Enable()  join:Disable()  join:IsEnabled()  join:Fire(...)
```

Библиотека берёт на себя три вещи: **время жизни** подписки (гаснет вместе с
окном), **выключатель** с парой `Get`/`Set`, из-за которой триггер сохраняется в
профиль как обычный переключатель, и **показ** уведомления. Откуда сигнал и что
считать событием — дело вызывающего.

Опроса по условию каждый кадр здесь нет намеренно: это цикл. Нужен опрос —
заводите снаружи и дёргайте `Fire()`.

---

## Модальное подтверждение

```lua
win:Confirm({
    Title = "UNLOAD", Text = "Снять меню целиком?",
    Confirm = "YES", Cancel = "NO",
    OnConfirm = function() win:Destroy() end,
})
```

---

## Профили

```lua
win:Save("default")     -- записать
win:Load("default")     -- применить
win:Profiles()          -- список имён
win:DeleteProfile("x")
```

Сохраняются только элементы с `Flag`. **`Flag` — это имя, а не команда
сохранять**; чтобы именовать, но не сохранять, добавьте `Save = false`:

```lua
Flag = "walkSpeed"                    именуется и сохраняется
Flag = "clickCount", Save = false     именуется, в профиль не идёт
без Flag                              ни того, ни другого
```

Граница проходит по смыслу: **настройка** — то, что человек выбрал и хочет
получить обратно; **состояние** — то, что накопилось само (счётчики, служебные
поля, временные значения).

Повторный `Flag` — ошибка сразу, а не тихая замена.

Загрузка **зовёт обратные вызовы**: профиль должен применяться, а не только
отображаться.

Файлы лежат в `NierUI/<ConfigFolder>/<профиль>.json`.

**Папку задаёте вы, и это обязательно** — без неё `Save` и `Load` бросают явную
ошибку:

```lua
local win = NierUI:Window({ Title = "MY SCRIPT", ConfigFolder = "myscript" })
```

Библиотека намеренно не выводит имя папки из заголовка окна: заголовок меняется
по вкусу, и каждая его правка оставляла бы на диске новую папку с осиротевшими
профилями. Окно без профилей заводить можно — ошибка возникнет только при
попытке сохранить или загрузить.

Нет `writefile` у исполнителя — сохранение просто не работает, меню при этом не
ломается.

---

## Тема

Меняется **до** создания окна: значения читаются в момент постройки.

```lua
NierUI.Theme.Font = Enum.Font.RobotoMono   -- нужна кириллица
NierUI.Theme.Bg   = Color3.fromRGB(207, 201, 176)
NierUI.Theme.Ink  = Color3.fromRGB(69, 65, 56)

NierUI.Theme.WindowWidth = 644
NierUI.Theme.RowHeight   = 26
NierUI.Theme.DropdownMax = 6       -- сколько пунктов видно до прокрутки

NierUI.Theme.Scanlines = true      -- фактура подложки
NierUI.Theme.GridStep  = 8
NierUI.Theme.Grain     = 7
NierUI.Theme.Band      = true      -- полосы-перфорации сверху и снизу

NierUI.Theme.BlockSeparators = false
NierUI.Theme.NotifyDuration  = 4
```

Шрифт по умолчанию — `Merriweather`, ближайшая к оригиналу антиква из
встроенных. Кириллицу держит.

---

## Что важно знать

**В библиотеке нет ни одного цикла и ни одного `task.spawn`.** Всё на событиях,
анимация на `TweenService`. Это не украшательство: готовые меню часто оставляют
после себя вечные `while true do task.wait() end`, которые переживают снос
интерфейса и держат живым мёртвый экземпляр. Здесь каждая подписка записана и
гаснет в `Destroy`.

**Слабые ключи по `Instance` не работают** так, как ожидаешь: ключ — это
Lua-обёртка над объектом, дерево её не держит, и сборщик забирает её вместе с
записью. Внутри везде сильные ключи и ручная чистка.

**Всплывающие окна и уведомления живут на `ScreenGui`, а не внутри окна** —
страница вкладки обрезает всё за своими границами.

**Недоступная строка не прячется, а бледнеет** и продолжает показывать значение:
исчезнувший пункт непонятно, исчез или не существует.
