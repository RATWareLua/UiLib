# Сборка NierUI из частей.
#
# Файлы не связаны require, поэтому каждый оборачивается в функцию, которой
# передаётся общая таблица NierUI. Так области видимости изолированы (никаких
# коллизий локальных имён и никакого упора в лимит локалей на функцию), а
# добавление виджета -- это ровно один новый файл в списке ниже.
#
# Собирается три файла:
#   dist\NierUI.luau      только библиотека, возвращает таблицу
#   dist\NierUIDemo.luau  библиотека + общая витрина
#   dist\BindDemo.luau    библиотека + витрина привязок, только ядро биндов
#
# Пишем ЧЕРЕЗ .NET без BOM: Luau падает на BOM ещё до первой строки.

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $root 'dist'

# Порядок обязателен:
#   Theme  -- его читают все остальные при загрузке;
#   Util   -- им пользуются Row, Window и виджеты;
#   Row    -- общий каркас строки и раскрывающейся панели;
#   Binds  -- ядро привязок; окно заводит его в конструкторе, значит до Window;
#   Window -- заводит реестр виджетов, без него им негде регистрироваться;
#   widgets-- только регистрируются, ничего не строят до вызова.
$parts = @(
    'NierUI\Theme.luau'
    'NierUI\Util.luau'
    'NierUI\Texture.luau'
    'NierUI\ColorControl.luau'
    'NierUI\Row.luau'
    'NierUI\Binds.luau'
    'NierUI\Window.luau'
    'NierUI\Block.luau'
    'NierUI\Section.luau'
    'NierUI\Cursor.luau'
    'NierUI\Capture.luau'
    'NierUI\Config.luau'
    'NierUI\Notify.luau'
    'NierUI\Trigger.luau'
    'NierUI\Popup.luau'
    'NierUI\Panel.luau'
    'NierUI\Hud.luau'
    'NierUI\Context.luau'
    'NierUI\Modal.luau'
    'NierUI\OptionSettings.luau'
    'NierUI\widgets\Basic.luau'
    'NierUI\widgets\Slider.luau'
    'NierUI\widgets\Dropdown.luau'
    'NierUI\widgets\InputText.luau'
    'NierUI\widgets\Keybind.luau'
    'NierUI\widgets\Choice.luau'
    'NierUI\widgets\Progress.luau'
    'NierUI\widgets\ColorPicker.luau'
)

function Read-Part([string]$rel) {
    $path = Join-Path $root $rel
    if (-not (Test-Path $path)) { throw "нет файла: $rel" }
    return [System.IO.File]::ReadAllText($path).TrimStart([char]0xFEFF)
}

$lib = New-Object System.Text.StringBuilder
[void]$lib.AppendLine('local NierUI = {}')
[void]$lib.AppendLine('')

foreach ($rel in $parts) {
    $name = $rel.Replace('\', '/')
    [void]$lib.AppendLine("--============================ $name ============================")
    [void]$lib.AppendLine(';(function(NierUI)')
    [void]$lib.AppendLine((Read-Part $rel))
    [void]$lib.AppendLine('end)(NierUI)')
    [void]$lib.AppendLine('')
}

[void]$lib.AppendLine('return NierUI')

if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist | Out-Null }

$libText = "--!nocheck`r`n-- NierUI. Собрано lib\build.ps1, правки вносить в lib\NierUI\.`r`n`r`n" + $lib.ToString()
$noBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $dist 'NierUI.luau'), $libText, $noBom)

# Витрина: библиотека сворачивается в вызов функции, её результат ложится в
# локальную NierUI, демо идёт следом и её видит.
#
# Витрин две и будет больше, поэтому сборка одна на все: копия этих восьми строк
# на каждую означала бы, что однажды они разойдутся.
function Write-Demo([string]$source, [string]$target, [string]$title) {
    $demo = New-Object System.Text.StringBuilder
    [void]$demo.AppendLine('--!nocheck')
    [void]$demo.AppendLine("-- NierUI + $title. Собрано lib\build.ps1.")
    [void]$demo.AppendLine('')
    [void]$demo.AppendLine('local NierUI = (function()')
    [void]$demo.AppendLine($lib.ToString())
    [void]$demo.AppendLine('end)()')
    [void]$demo.AppendLine('')
    [void]$demo.AppendLine((Read-Part $source))

    [System.IO.File]::WriteAllText((Join-Path $dist $target), $demo.ToString(), $noBom)
    return [math]::Round((Get-Item (Join-Path $dist $target)).Length / 1024, 1)
}

$b = Write-Demo 'demo.luau' 'NierUIDemo.luau' 'витрина'
$c = Write-Demo 'binds-demo.luau' 'BindDemo.luau' 'витрина привязок'

$a = [math]::Round((Get-Item (Join-Path $dist 'NierUI.luau')).Length / 1024, 1)
Write-Output "собрано: NierUI.luau ($a КБ), NierUIDemo.luau ($b КБ), BindDemo.luau ($c КБ), частей: $($parts.Count)"
