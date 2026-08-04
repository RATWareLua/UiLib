# Свой виджет

Как добавить свой элемент. Один файл, никаких правок в остальном.

Добавление элемента — **ровно один новый файл** и строка в списке `build.ps1`.
Редактировать не нужно ничего: метод `tab:МойВиджет()` появляется сам.

```lua
NierUI.widget("Stepper", function(tab, opts)
    local row, label, value, invert, setHeld, rowApi =
        NierUI.makeRow(tab, opts.Text, opts.Desc, nil, opts)

    local current = opts.Default or 0
    local function render() value.Text = tostring(current) end
    render()

    NierUI.connect(tab, row.MouseButton1Click, rowApi.gate(function()
        current = current + 1
        render()
        NierUI.fire(opts, false, current)
    end))

    return NierUI.bind(tab, opts, {
        Get = function(_) return current end,
        Set = function(_, v, silent)
            current = tonumber(v) or 0
            render()
            NierUI.fire(opts, silent, current)
        end,
        SetEnabled = function(_, on) rowApi.setEnabled(on) end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)
```

`NierUI.fire(opts, silent, ...)` — «позвать `Callback`, если не просили молчать».
Писать это руками не нужно и вредно: копий приёма набралось двенадцать в семи
файлах, и девять из них глотали ошибку чужого обработчика молча — он мог падать
на каждый щелчок, а снаружи это выглядело как «строка не работает».

**Второй аргумент `Set` везде значит `не звать Callback`** — и у вашего виджета
обязан значить то же. Им пользуется загрузка профиля со строками `Apply = false`
и всякий, кто ставит значение изнутри меню.

Всё остальное он получает **даром, потому что он строка**: подсветку, метку,
разделитель, недоступное состояние, меню правой кнопки, настройки, попадание в
профиль. `makeRow` строит каркас, `NierUI.bind` вносит в реестр флагов, воронка
в `containerIndex` дописывает `Get/SetSetting` и владельца меню.

**Привязка — исключение, и единственное.** Даром она не достаётся: ядру нужна
пара `get`/`set` до состояния виджета, а что считать состоянием, знает только он
сам. `Bind` и `Binds` разбирают `Toggle`, `Button` и `Keybind`; своему виджету
запись заводят руками и возвращают её в поле `binds` — по нему кодек кладёт
клавишу, режим и подпись в профиль вместе со строкой.

```lua
local bind = tab.window.binds:Add({
    Flag = opts.Flag, row = row, rowTitle = opts.Text,
    Key = typeof(opts.Bind) == "EnumItem" and opts.Bind or nil,
    get = function() return current > 0 end,
    set = function(on) ... end,
})
rowApi.menu(tab, opts.Text, function(menu) NierUI.bindRows(menu, { bind }) end)
-- ... и в handle: binds = { bind }
```

Передать `Bind` виджету, который его не разбирает, — **ошибка при постройке, а
не молчание**: иначе привязки нет, в списке пусто, клавиша ничего не делает, да
вдобавок пропало собственное меню строки — каркас решил, что виджет построит его
сам.

| что вернул `makeRow` | зачем |
|---|---|
| `row` | сама строка-кнопка, в неё кладут своё |
| `label`, `value` | подпись слева и значение справа |
| `invert(inst, prop, hovered, normal)` | под курсором строка заливается чернилами — всё, нарисованное чернилами, обязано стать песочным, иначе исчезнет |
| `setHeld(on)` | держать подсветку, пока раскрыт свой блок |
| `rowApi` | `.gate(fn)`, `.setEnabled`, `.isEnabled`, `.onPaint(fn)`, `.menu(...)`, `.settings(...)` |

`rowApi.gate` оборачивает обработчик, и недоступность работает сама — иначе
`if not enabled then return end` пришлось бы дописывать в каждый обработчик
каждого виджета, а забыть один ничего не стоит.

`NierUI.makePanel(row, height)` даёт раскрывающийся блок под строкой — тот же,
на котором стоят списки и палитра.

## Общее уже написано — берите, а не повторяйте

Каждая строка этой таблицы когда-то была копией в двух-двенадцати файлах, и
копии успевали разойтись раньше, чем их замечали.

| приём | вместо чего |
|---|---|
| `NierUI.fire(opts, silent, ...)` | своего `if not silent and opts.Callback` |
| `NierUI.sink(container)` + `NierUI.connect` | записи подписок прямо в `window.conns` |
| `NierUI.drain(list)` | цикла `Disconnect` + `table.clear` |
| `NierUI.makeTrack(row, invert, толщина, тускло, тускло_под_курсором)` | своей дорожки с заливкой; на ней стоят ползунок и полоса выполнения |
| `NierUI.rowExpand(container, row, rowApi, panel, apply)` | своей связки «раскрыть блок по щелчку»; сторож `lastPress` там же |
| `NierUI.bindWatch(container, bind, что, fn)` | своей подписки на ядро привязок с разбором повода |
| `NierUI.layers` | голых чисел `ZIndex`: очередь слоёв глобальна, и знать её надо целиком |
| `NierUI.viewport()` | `workspace.CurrentCamera` с запасным `1920×1080` |

Заводить своё имеет смысл ровно тогда, когда общее не подходит **по существу**,
а не по мелочи: подходящее по мелочи чинится в одном месте и достаётся всем.

**Виджет не знает, куда его кладут.** Ему нужны только `.page`, `.rows`,
`.window` и `.conns` — а это есть у вкладки, блока, секции, колонки, меню правой
кнопки и худа. Ровно поэтому блоки в своё время не потребовали править ни один
виджет.

---

[← к оглавлению](../README.md)
