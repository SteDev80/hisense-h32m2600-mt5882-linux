$ErrorActionPreference='Stop'
$source=Join-Path (Split-Path $PSScriptRoot -Parent) 'outputs/Prova-audio-10-secondi.mp3'
$dest='/mnt/usb2/archlinux/rootfs/root/Musica/Prova-audio-10-secondi.mp3'
$data=[IO.File]::ReadAllBytes($source)
$encoded=[Convert]::ToBase64String($data)
$serial=[IO.Ports.SerialPort]::new('COM3',115200,'None',8,'One')
$serial.WriteTimeout=5000
function Invoke-Line([string]$line) {
    $marker='__MP3_'+[Guid]::NewGuid().ToString('N')
    $serial.Write('('+ $line + '); echo '+$marker+':$?' + "`r")
    $buf=''; $until=[DateTime]::UtcNow.AddSeconds(20)
    while([DateTime]::UtcNow -lt $until) {
        $buf+=$serial.ReadExisting()
        if($buf -match ([regex]::Escape($marker)+':(\d+)')) {
            if($Matches[1] -ne '0'){throw $buf}
            return $buf
        }
        Start-Sleep -Milliseconds 50
    }
    throw 'Timeout seriale'
}
try {
    $serial.Open(); $serial.Write("`r"); Start-Sleep -Seconds 1; [void]$serial.ReadExisting()
    [void](Invoke-Line 'awk ''$1=="/dev/sda2" && $2=="/" {ok=1} END{exit !ok}'' /proc/mounts')
    [void](Invoke-Line 'mkdir -p /mnt/usb2/archlinux/rootfs/root/Musica; : > /tmp/h32-mp3.b64')
    for($i=0;$i -lt $encoded.Length;$i+=300){
        $part=$encoded.Substring($i,[Math]::Min(300,$encoded.Length-$i))
        [void](Invoke-Line ("printf '%s' '"+$part+"' >> /tmp/h32-mp3.b64"))
    }
    $hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    $out=Invoke-Line ('test ! -e '+$dest+' && base64 -d /tmp/h32-mp3.b64 > '+$dest+' && sha256sum '+$dest)
    if($out -notmatch $hash){throw 'Hash non corrispondente'}
    [void](Invoke-Line 'rm -f /tmp/h32-mp3.b64; sync')
    'MP3_UPLOAD_VERIFIED'
} finally {if($serial.IsOpen){$serial.Close()};$serial.Dispose()}
