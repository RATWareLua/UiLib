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
        if opts.Callback then pcall(opts.Callback, current) end
    end))

    return NierUI.bind(tab, opts, {
        Get = function(_) return current end,
        Set = function(_, v, silent)
            current = tonumber(v) or 0
            render()
            if not silent and opts.Callback then pcall(opts.Callback, current) end
        end,
        SetEnabled = function(_, on) rowApi.setEnabled(on) end,
        IsEnabled = function(_) return rowApi.isEnabled() end,
    })
end)
```

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

**Виджет не знает, куда его кладут.** Ему нужны только `.page`, `.rows`,
`.window` и `.conns` — а это есть у вкладки, блока, секции, колонки, меню правой
кнопки и худа. Ровно поэтому блоки в своё время не потребовали править ни один
виджет.

---

[← к оглавлению](../README.md)
