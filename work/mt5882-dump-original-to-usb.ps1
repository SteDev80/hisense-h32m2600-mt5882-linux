$ErrorActionPreference = 'Stop'
$serial = [System.IO.Ports.SerialPort]::new('COM3', 115200, 'None', 8, 'One')
$serial.Handshake = 'None'
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 100
$serial.WriteTimeout = 1000
$logPath = 'C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\outputs\buildroot-h32m2600\uart-dump-original.txt'
$all = ''

function Invoke-Uboot([string]$command, [int]$timeoutSeconds = 60) {
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
            $script:all | Set-Content -LiteralPath $script:logPath -Encoding utf8
        }
        if ($buffer -match 'mt5882\s*#\s*$') { return $buffer }
        Start-Sleep -Milliseconds 20
    }
    throw "Timeout dopo: $command"
}

try {
    $serial.Open()
    [Console]::WriteLine('[HOST] DUMP_LISTENER_READY: riavvia ora alimentazione TV.')
    $buffer = ''
    $deadline = [DateTime]::UtcNow.AddMinutes(8)
    while ([DateTime]::UtcNow -lt $deadline) {
        $text = $serial.ReadExisting()
        if ($text.Length -gt 0) { [Console]::Write($text); $all += $text; $buffer += $text }
        if ($buffer -match 'U-Boot 2011\.12\.12|Hit any key to stop autoboot') { $serial.Write(' ') }
        if ($buffer -match 'mt5882\s*#\s*$') { break }
        Start-Sleep -Milliseconds 10
    }
    if ($buffer -notmatch 'mt5882\s*#\s*$') { throw 'Prompt U-Boot non ricevuto.' }

    [Console]::WriteLine("`r`n[HOST] Attendo 15 secondi per stabilizzare la Lexar...")
    Start-Sleep -Seconds 15
    $usbStart = Invoke-Uboot 'usb start' 50
    if ($usbStart -notmatch '1 Storage Device\(s\) found') {
        throw 'Lexar non enumerata al primo usb start ritardato; nessun secondo tentativo automatico.'
    }
    $fat = Invoke-Uboot 'fatls usb 0:1 /' 20
    $ext = Invoke-Uboot 'ext4ls usb 0:2 /' 30
    if ($fat -notmatch 'uinitrd-h32m2600-buildroot' -or $ext -notmatch '<DIR>\s+2048 bin') {
        throw 'Lexar o partizione Buildroot non confermata: dump annullato.'
    }

    [void](Invoke-Uboot 'mw.b 0x02000000 0x5a 0x1000' 20)
    [void](Invoke-Uboot 'ext4write usb 0:2 /uboot-write-test.bin 0x02000000 0x1000' 60)
    $testListing = Invoke-Uboot 'ext4ls usb 0:2 /' 30
    if ($testListing -notmatch '4096 uboot-write-test.bin') {
        throw 'Test scrittura ext4 legacy non confermato: dump annullato.'
    }

    $kernelRead = Invoke-Uboot 'mmc read 0 0x02000000 0x2400 0x2000' 90
    if ($kernelRead -notmatch '8192 blocks read: OK') { throw 'Lettura kernelA non confermata.' }
    [void](Invoke-Uboot 'crc32 0x02000000 0x00400000' 30)
    [void](Invoke-Uboot 'ext4write usb 0:2 /kernelA-h32m2600.bin 0x02000000 0x00400000' 180)
    $kernelListing = Invoke-Uboot 'ext4ls usb 0:2 /' 30
    if ($kernelListing -notmatch '4194304 kernelA-h32m2600.bin') {
        throw 'Scrittura kernelA su USB non confermata.'
    }

    for ($index = 0; $index -lt 19; $index++) {
        $block = 0x6400 + ($index * 0x2000)
        $count = if ($index -eq 18) { 0x1800 } else { 0x2000 }
        $bytes = if ($index -eq 18) { 0x00300000 } else { 0x00400000 }
        $name = ('/rootfsA-h32m2600-{0:d2}.bin' -f $index)
        $readCommand = 'mmc read 0 0x02000000 0x{0:x} 0x{1:x}' -f $block, $count
        $writeCommand = 'ext4write usb 0:2 {0} 0x02000000 0x{1:x8}' -f $name, $bytes
        $rootRead = Invoke-Uboot $readCommand 90
        if ($rootRead -notmatch ("$count blocks read: OK")) { throw "Lettura rootfsA chunk $index non confermata." }
        [void](Invoke-Uboot ('crc32 0x02000000 0x{0:x8}' -f $bytes) 30)
        [void](Invoke-Uboot $writeCommand 180)
    }
    $listing = Invoke-Uboot 'ext4ls usb 0:2 /' 40
    if ($listing -notmatch 'kernelA-h32m2600.bin' -or $listing -notmatch 'rootfsA-h32m2600-18.bin') {
        throw 'File copiati ma elenco finale non confermato.'
    }
    $all | Set-Content -LiteralPath $logPath -Encoding utf8
    [Console]::WriteLine("`r`n[HOST] DUMP_OK: kernelA e rootfsA copiati sulla Lexar; TV al prompt U-Boot.")
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
}
