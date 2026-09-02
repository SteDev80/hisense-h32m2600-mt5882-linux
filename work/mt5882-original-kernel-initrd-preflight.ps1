$ErrorActionPreference = 'Stop'
$serial = [System.IO.Ports.SerialPort]::new('COM3',115200,'None',8,'One')
$serial.Handshake='None'; $serial.DtrEnable=$false; $serial.RtsEnable=$false
$serial.ReadTimeout=100; $serial.WriteTimeout=1000
$logPath='C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\outputs\buildroot-h32m2600\uart-original-initrd-preflight.txt'
$all=''
function Run([string]$command,[int]$seconds=60){
    [Console]::WriteLine("`r`n[HOST] -> $command"); $script:serial.Write($command+"`r")
    $buffer=''; $deadline=[DateTime]::UtcNow.AddSeconds($seconds)
    while([DateTime]::UtcNow-lt$deadline){$text=$script:serial.ReadExisting();if($text){[Console]::Write($text);$script:all+=$text;$buffer+=$text;$script:all|Set-Content $script:logPath -Encoding utf8};if($buffer-match'mt5882\s*#\s*$'){return $buffer};Start-Sleep -Milliseconds 20}
    throw "Timeout dopo: $command"
}
try{
    $serial.Open();[Console]::WriteLine('[HOST] INITRD_PREFLIGHT_READY: riavvia ora alimentazione TV.')
    $buffer='';$deadline=[DateTime]::UtcNow.AddMinutes(8)
    while([DateTime]::UtcNow-lt$deadline){$text=$serial.ReadExisting();if($text){[Console]::Write($text);$all+=$text;$buffer+=$text};if($buffer-match'U-Boot 2011\.12\.12|Hit any key to stop autoboot'){$serial.Write(' ')};if($buffer-match'mt5882\s*#\s*$'){break};Start-Sleep -Milliseconds 10}
    if($buffer-notmatch'mt5882\s*#\s*$'){throw 'Prompt U-Boot non ricevuto'}
    Start-Sleep -Seconds 15
    $usb=Run 'usb start' 50;if($usb-notmatch'1 Storage Device\(s\) found'){throw 'Lexar non enumerata'}
    $initrd=Run 'fatload usb 0:1 0x03000000 uInitrd-h32m2600-buildroot' 90
    if($initrd-notmatch'1973403 bytes read'){throw 'uInitrd non caricato completamente'}
    $kernel=Run 'mmc read 0 0x02000000 0x2400 0x2000' 90
    if($kernel-notmatch'8192 blocks read: OK'){throw 'kernelA non caricato completamente'}
    [void](Run 'crc32 0x02000000 0x00400000' 30)
    [void](Run 'md.b 0x02000000 0x80' 30)
    [void](Run 'iminfo 0x02000000' 30)
    $all|Set-Content $logPath -Encoding utf8
    [Console]::WriteLine("`r`n[HOST] INITRD_PREFLIGHT_OK: immagini in RAM; TV lasciata al prompt.")
}finally{if($serial.IsOpen){$serial.Close()}}
