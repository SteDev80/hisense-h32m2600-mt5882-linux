$ErrorActionPreference='Stop'
throw 'Disabled: live U-Boot booted despite altered payload. Do not rely on verify=yes for autoboot.'
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
    throw 'U-Boot timeout; no persistent command sent'
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
    if($usb -notmatch '1 Storage Device\(s\) found'){throw 'Storage not found'}
    [void](Run 'mw.l 0x05000000 0 0x10')
    $loaded=Run 'fatload usb 0:1 0x05000000 uMulti-h32-usb-test-v2' 120
    if($loaded -notmatch '7004453 bytes read'){throw 'Incomplete image'}
    $info=Run 'iminfo 0x05000000'
    if($info -notmatch 'Verifying Checksum \.\.\. OK'){throw 'Initial CRC not valid'}
    [void](Run 'setenv verify yes')
    # Flip only the final payload byte of this exact image IN RAM.
    # Header and component length table remain intact.
    [void](Run 'mw.b 0x056ae124 ff 1')
    $result=Run 'bootm 0x05000000; version'
    if($result -notmatch 'Bad Data CRC' -or $result -notmatch 'GNU ld') {
        throw 'CRC rejection/fall-through not confirmed'
    }
    [void](Run 'mw.l 0x05000000 0 0x10')
    [void](Run 'printenv bootcmd')
    'MULTI_BAD_CRC_REJECTED; HELD_AT_UBOOT'
} finally {
    if($s.IsOpen){$s.Close()}; $s.Dispose()
    $transcript | Set-Content -LiteralPath (Join-Path $PSScriptRoot '..\outputs\usb-multi-test\uart-crc-test.txt') -Encoding utf8
}
