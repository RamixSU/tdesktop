# Phantom Launcher for the Telegram Phantom Economy build.
# A small WinForms window that lets a friend pick the mode and values,
# remembers them in phantom.ini and starts Telegram with the right env vars.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$iniPath = Join-Path $scriptDir 'phantom.ini'

$config = @{
    Mode          = 'infinite'
    Stars         = '999999'
    Ton           = '13370'
    TransferStars = '25'
    TelegramPath  = ''
}

function Read-Config {
    if (-not (Test-Path $iniPath)) { return }
    foreach ($line in Get-Content -LiteralPath $iniPath -Encoding UTF8) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0) { continue }
        if ($trimmed.StartsWith('#') -or $trimmed.StartsWith(';')) { continue }
        $idx = $trimmed.IndexOf('=')
        if ($idx -lt 1) { continue }
        $key = $trimmed.Substring(0, $idx).Trim()
        $val = $trimmed.Substring($idx + 1).Trim()
        if ($config.ContainsKey($key)) { $config[$key] = $val }
    }
}

function Save-Config {
    $lines = @(
        '# Phantom Launcher settings',
        "Mode=$($config.Mode)",
        "Stars=$($config.Stars)",
        "Ton=$($config.Ton)",
        "TransferStars=$($config.TransferStars)",
        "TelegramPath=$($config.TelegramPath)"
    )
    Set-Content -LiteralPath $iniPath -Value $lines -Encoding UTF8
}

function Find-Telegram {
    $candidates = @(
        (Join-Path $scriptDir 'Telegram.exe'),
        (Join-Path $scriptDir 'bin\Telegram.exe'),
        (Join-Path (Split-Path -Parent $scriptDir) 'Telegram.exe'),
        (Join-Path (Split-Path -Parent $scriptDir) 'bin\Telegram.exe'),
        (Join-Path (Split-Path -Parent (Split-Path -Parent $scriptDir)) 'Telegram.exe')
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return (Resolve-Path -LiteralPath $path).Path
        }
    }
    return ''
}

Read-Config

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Phantom Launcher'
$form.ClientSize = New-Object System.Drawing.Size(470, 430)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Telegram Phantom Economy'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$title.SetBounds(18, 14, 434, 30)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Фантомные подарки и баланс. Сервер ничего не получает.'
$subtitle.ForeColor = [System.Drawing.Color]::DimGray
$subtitle.SetBounds(20, 46, 434, 20)
$form.Controls.Add($subtitle)

$modeBox = New-Object System.Windows.Forms.GroupBox
$modeBox.Text = 'Режим валюты'
$modeBox.SetBounds(18, 74, 434, 76)
$form.Controls.Add($modeBox)

$radioInfinite = New-Object System.Windows.Forms.RadioButton
$radioInfinite.Text = 'Бесконечная — баланс не уменьшается'
$radioInfinite.SetBounds(14, 20, 400, 22)
$modeBox.Controls.Add($radioInfinite)

$radioSpend = New-Object System.Windows.Forms.RadioButton
$radioSpend.Text = 'Траты — баланс уменьшается с каждым подарком'
$radioSpend.SetBounds(14, 44, 400, 22)
$modeBox.Controls.Add($radioSpend)

$valuesBox = New-Object System.Windows.Forms.GroupBox
$valuesBox.Text = 'Значения'
$valuesBox.SetBounds(18, 160, 434, 140)
$form.Controls.Add($valuesBox)

function New-Label($text, $x, $y, $w) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $text
    $lbl.SetBounds($x, $y, $w, 20)
    return $lbl
}

$starsBox = New-Object System.Windows.Forms.NumericUpDown
$starsBox.SetBounds(230, 22, 180, 24)
$starsBox.Minimum = 0
$starsBox.Maximum = 2000000000
$starsBox.ThousandsSeparator = $true
$starsValue = 0
[void][long]::TryParse($config.Stars, [ref]$starsValue)
$starsBox.Value = [Math]::Min([decimal]$starsValue, $starsBox.Maximum)

$tonBox = New-Object System.Windows.Forms.NumericUpDown
$tonBox.SetBounds(230, 56, 180, 24)
$tonBox.Minimum = 0
$tonBox.Maximum = 100000000
$tonBox.ThousandsSeparator = $true
$tonValue = 0
[void][long]::TryParse($config.Ton, [ref]$tonValue)
$tonBox.Value = [Math]::Min([decimal]$tonValue, $tonBox.Maximum)

$transferBox = New-Object System.Windows.Forms.NumericUpDown
$transferBox.SetBounds(230, 90, 180, 24)
$transferBox.Minimum = 0
$transferBox.Maximum = 1000000
$transferBox.ThousandsSeparator = $true
$transferValue = 25
[void][long]::TryParse($config.TransferStars, [ref]$transferValue)
$transferBox.Value = [Math]::Min([decimal]$transferValue, $transferBox.Maximum)

$valuesBox.Controls.Add((New-Label 'Звёзды на балансе' 18 24 200))
$valuesBox.Controls.Add($starsBox)
$valuesBox.Controls.Add((New-Label 'Грамы (TON) на балансе' 18 58 200))
$valuesBox.Controls.Add($tonBox)
$valuesBox.Controls.Add((New-Label 'Цена передачи NFT, звёзд' 18 92 200))
$valuesBox.Controls.Add($transferBox)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.SetBounds(18, 314, 344, 24)
$form.Controls.Add($pathBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = 'Обзор...'
$browseButton.SetBounds(368, 312, 84, 27)
$form.Controls.Add($browseButton)

$status = New-Object System.Windows.Forms.Label
$status.SetBounds(20, 344, 432, 20)
$status.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($status)

$launchButton = New-Object System.Windows.Forms.Button
$launchButton.Text = 'Запустить'
$launchButton.SetBounds(18, 374, 200, 40)
$launchButton.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($launchButton)

$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = 'Сохранить'
$saveButton.SetBounds(226, 374, 110, 40)
$form.Controls.Add($saveButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = 'Выход'
$closeButton.SetBounds(344, 374, 108, 40)
$form.Controls.Add($closeButton)

if ($config.Mode -eq 'spend') {
    $radioSpend.Checked = $true
} else {
    $radioInfinite.Checked = $true
}

$initialPath = $config.TelegramPath
if (-not $initialPath) { $initialPath = Find-Telegram }
$pathBox.Text = $initialPath
$form.AcceptButton = $launchButton
$form.CancelButton = $closeButton

function Update-ModeHint {
    if ($radioInfinite.Checked) {
        $starsBox.Enabled = $true
        $status.Text = 'Баланс всегда равен указанному числу.'
    } else {
        $starsBox.Enabled = $true
        $status.Text = 'Баланс стартует с указанного числа и уменьшается.'
    }
}

$radioInfinite.Add_CheckedChanged({ Update-ModeHint })
$radioSpend.Add_CheckedChanged({ Update-ModeHint })
Update-ModeHint

$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = 'Telegram.exe|Telegram.exe|Все файлы|*.*'
    if ($pathBox.Text) {
        $dialog.InitialDirectory = Split-Path -Parent $pathBox.Text
    }
    if ($dialog.ShowDialog() -eq 'OK') {
        $pathBox.Text = $dialog.FileName
        $status.Text = ''
    }
})

function Apply-Config {
    $config.Mode = if ($radioSpend.Checked) { 'spend' } else { 'infinite' }
    $config.Stars = [string]$starsBox.Value
    $config.Ton = [string]$tonBox.Value
    $config.TransferStars = [string]$transferBox.Value
    $config.TelegramPath = $pathBox.Text.Trim()
}

$saveButton.Add_Click({
    Apply-Config
    Save-Config
    $status.Text = 'Сохранено в phantom.ini'
})

$launchButton.Add_Click({
    Apply-Config
    $exe = $config.TelegramPath
    if (-not $exe -or -not (Test-Path -LiteralPath $exe)) {
        $found = Find-Telegram
        if ($found) {
            $exe = $found
            $pathBox.Text = $found
            $config.TelegramPath = $found
        }
    }
    if (-not $exe -or -not (Test-Path -LiteralPath $exe)) {
        [System.Windows.Forms.MessageBox]::Show(
            'Не найден Telegram.exe. Укажи путь к нему через «Обзор...».',
            'Phantom Launcher',
            'OK',
            'Warning') | Out-Null
        return
    }

    Save-Config

    $running = Get-Process -Name 'Telegram' -ErrorAction SilentlyContinue
    if ($running) {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            'Telegram уже запущен. Закрыть его и запустить заново с новыми настройками?',
            'Phantom Launcher',
            'YesNo',
            'Question')
        if ($answer -ne 'Yes') { return }
        $running | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.WorkingDirectory = Split-Path -Parent $exe
    $psi.UseShellExecute = $false
    $psi.EnvironmentVariables['TD_FAKE_ECONOMY'] = '1'
    $psi.EnvironmentVariables['TD_FAKE_STARS'] = $config.Stars
    $psi.EnvironmentVariables['TD_FAKE_TON'] = $config.Ton
    $psi.EnvironmentVariables['TD_FAKE_TRANSFER_STARS'] = $config.TransferStars
    if ($config.Mode -eq 'infinite') {
        $psi.EnvironmentVariables['TD_FAKE_INFINITE'] = '1'
    } else {
        $psi.EnvironmentVariables.Remove('TD_FAKE_INFINITE')
    }

    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        $status.Text = 'Telegram запущен.'
        $form.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Не удалось запустить:`n$($_.Exception.Message)",
            'Phantom Launcher',
            'OK',
            'Error') | Out-Null
    }
})

[void]$form.ShowDialog()
