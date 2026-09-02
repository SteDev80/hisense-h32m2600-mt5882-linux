$ErrorActionPreference = 'Stop'

$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 1000
$logPath = 'C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\outputs\buildroot-h32m2600\uart-preflight.txt'
$all = ''

function Invoke-UbootReadOnly([string]$command, [int]$timeoutSeconds = 30) {
    [Console]::WriteLine("`r`n[HOST] -> $command")
    $script:serial.Write($command + "`r")
    $buffer = ''
    $deadline = [DateTime]::UtcNow.AddSeconds($timeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $script:serial.ReadExisting()
        if ($text.Length -gt 0) {
            [Console]::Write($text)
            $script:all += $text
            $buffer += $text
        }
        if ($buffer -match 'mt5882\s*#\s*$') { return $buffer }
        Start-Sleep -Milliseconds 20
    }
    throw "Timeout dopo: $command"
}

try {
    $serial.Open()
    [Console]::WriteLine('[HOST] LISTENER_READY: togli e rimetti ora alimentazione alla TV.')
    $deadline = [DateTime]::UtcNow.AddMinutes(10)
    $lastBreak = [DateTime]::MinValue
    $prompt = $false
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text.Length -gt 0) {
            [Console]::Write($text)
            $all += $text
        }
        if ($all -match 'U-Boot 2011\.12\.12|Hit any key to stop autoboot') {
            if (([DateTime]::UtcNow - $lastBreak).TotalMilliseconds -gt 100) {
                $serial.Write(' ')
                $lastBreak = [DateTime]::UtcNow
            }
        }
        if ($all -match 'mt5882\s*#\s*$') { $prompt = $true; break }
        Start-Sleep -Milliseconds 10
    }
    if (-not $prompt) { throw 'Nessun prompt U-Boot ricevuto entro 10 minuti.' }

    [void](Invoke-UbootReadOnly 'printenv bootcmd' 10)
    [void](Invoke-UbootReadOnly 'printenv bootargs' 10)
    [void](Invoke-UbootReadOnly 'help eboot.lzo' 10)
    [void](Invoke-UbootReadOnly 'usb start' 40)
    [void](Invoke-UbootReadOnly 'usb start' 40)
    [void](Invoke-UbootReadOnly 'fatls usb 0:1 /' 20)
    [void](Invoke-UbootReadOnly 'ext4ls usb 0:2 /' 20)
    $all | Set-Content -LiteralPath $logPath -Encoding utf8
    [Console]::WriteLine("`r`n[HOST] PREFLIGHT_OK: TV lasciata al prompt U-Boot.")
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
}
