$ErrorActionPreference='Stop'
$s=[IO.Ports.SerialPort]::new('COM3',115200,'None',8,'One')
$s.DtrEnable=$false; $s.RtsEnable=$false; $s.WriteTimeout=3000
$transcript=''
function Read-Prompt([int]$seconds) {
    $buf=''; $until=[DateTime]::UtcNow.AddSeconds($seconds)
    while([DateTime]::UtcNow -lt $until) {
        $part=$s.ReadExisting()
        if($part){$buf+=$part; [Console]::Write($part)}
        if($buf -match 'mt5882\s*#\s*$'){return $buf}
        Start-Sleep -Milliseconds 30
    }
    throw 'U-Boot response timeout; no persistent command sent'
}
function Run([string]$command,[int]$seconds=30) {
    $s.Write($command+"`r")
    $reply=Read-Prompt $seconds
    $script:transcript+=$reply
    return $reply
}
try {
    $s.Open(); $s.Write("`r"); [void](Read-Prompt 5)
    [void](Run 'version')
    $usb=Run 'usb start' 60
    if($usb -match 'Lexar|JumpDrive' -or $usb -notmatch 'No Device on prot 0'){throw 'USB absence not confirmed; test stopped'}
    [void](Run 'usb storage')
    $result=Run 'mw.l 0x05000000 0 0x10; fatload usb 0:1 0x05000000 uImage-h32m2600-rescue-initrd; bootm 0x05000000; version' 30
    if($result -notmatch 'Wrong Image Format' -or $result -notmatch 'GNU ld'){throw 'Fall-through not confirmed'}
    [void](Run 'printenv bootcmd')
    'USB_ABSENT_FALLTHROUGH_CONFIRMED; HELD_AT_UBOOT'
} finally {
    $transcript | Set-Content -LiteralPath (Join-Path $PSScriptRoot '..\outputs\usb-absent-ram-test.txt') -Encoding utf8
    if($s.IsOpen){$s.Close()}; $s.Dispose()
}
