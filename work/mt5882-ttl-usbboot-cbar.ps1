$ErrorActionPreference = 'Stop'

$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 1000

$stage = 0
$buffer = ''
$breakSent = $false
$deadline = [DateTime]::UtcNow.AddMinutes(12)

function Send-Command([string]$command) {
    [Console]::WriteLine("`r`n[HOST] -> $command")
    $script:serial.Write($command + "`r")
    $script:buffer = ''
}

try {
    $serial.Open()
    [Console]::WriteLine('[HOST] COM3 aperta. In attesa del riavvio per il boot USB...')

    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text.Length -gt 0) {
            [Console]::Write($text)
            $buffer += $text
            if ($buffer.Length -gt 32768) {
                $buffer = $buffer.Substring($buffer.Length - 32768)
            }
        }

        if (-not $breakSent -and $buffer -match 'U-Boot 2011\.12\.12') {
            $serial.Write(' ')
            $breakSent = $true
            [Console]::WriteLine("`r`n[HOST] Autoboot interrotto.")
            $buffer = ''
        }
        elseif (-not $breakSent -and $buffer -match 'Hit any key to stop autoboot') {
            $serial.Write(' ')
            $breakSent = $true
            [Console]::WriteLine("`r`n[HOST] Autoboot interrotto.")
            $buffer = ''
        }

        if ($buffer -match 'mt5882\s*#\s*$') {
            Start-Sleep -Milliseconds 250
            switch ($stage) {
                0 { Send-Command 'usb start'; $stage = 1; break }
                1 { Send-Command 'fatls usb 0:1 /'; $stage = 2; break }
                2 { Send-Command 'fatload usb 0:1 0x02000000 uImage-h32m2600-series5-upnowait'; $stage = 3; break }
                3 {
                    if ($buffer -notmatch '2616360 bytes read') {
                        [Console]::WriteLine("`r`n[HOST] Dimensione non confermata: boot annullato.")
                        return
                    }
                    [Console]::WriteLine("`r`n[HOST] Immagine completa verificata da U-Boot.")
                    Send-Command 'setenv bootargs console=ttyMT0,115200n1 earlyprintk rdinit=/init loglevel=8 ignore_loglevel'
                    $stage = 4
                    break
                }
                4 { Send-Command 'bootm 0x02000000'; $stage = 5; break }
            }
        }

        Start-Sleep -Milliseconds 20
    }
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
    [Console]::WriteLine("`r`n[HOST] COM3 chiusa.")
}
