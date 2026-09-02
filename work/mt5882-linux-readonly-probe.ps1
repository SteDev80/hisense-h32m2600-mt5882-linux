$ErrorActionPreference = 'Stop'

$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 3000

$logPath = 'C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\outputs\buildroot-h32m2600\uart-linux-readonly-probe.txt'
$all = ''

function Drain([int]$milliseconds) {
    $deadline = [DateTime]::UtcNow.AddMilliseconds($milliseconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text) {
            [Console]::Write($text)
            $script:all += $text
        }
        Start-Sleep -Milliseconds 20
    }
}

try {
    $serial.Open()
    $serial.Write("`r")
    Drain 1500
    if ($all -match 'login:\s*$') {
        $serial.Write("root`r")
        Drain 1500
    }

    $command = 'echo ===TTL_PROBE_BEGIN===; id; uname -a; echo ===FRAMEBUFFER===; ls -l /dev/fb* 2>&1; cat /proc/fb 2>&1; echo ===DISPLAY_DRIVERS===; dmesg | grep -Ei "framebuffer| fb[0-9]|osd|gfx|display" | tail -80; echo ===MEMORY===; free -m; echo ===FILESYSTEMS===; cat /proc/filesystems; echo ===TTL_PROBE_END==='
    $serial.Write($command + "`r")

    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while ([DateTime]::UtcNow -lt $deadline) {
        Drain 250
        if (([regex]::Matches($all, '===TTL_PROBE_END===').Count) -ge 2) { break }
    }
}
finally {
    [System.IO.File]::WriteAllText($logPath, $all)
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
