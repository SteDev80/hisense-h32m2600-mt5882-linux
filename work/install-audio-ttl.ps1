param([switch]$EnableAutostart)
$ErrorActionPreference='Stop'
$serial=[IO.Ports.SerialPort]::new('COM3',115200,'None',8,'One')
$serial.DtrEnable=$false; $serial.RtsEnable=$false; $serial.WriteTimeout=5000
function Run([string]$line) {
    $marker='__AUDIO_'+[Guid]::NewGuid().ToString('N')
    $serial.Write('('+ $line + '); echo '+$marker+':$?' + "`r")
    $buf=''; $until=[DateTime]::UtcNow.AddSeconds(30)
    while([DateTime]::UtcNow -lt $until) {
        $buf+=$serial.ReadExisting()
        if($buf -match ([regex]::Escape($marker)+':(\d+)')) {
            if($Matches[1] -ne '0'){throw $buf}; return $buf
        }
        Start-Sleep -Milliseconds 30
    }
    throw "UART timeout: $buf"
}
try {
    $serial.Open(); $serial.Write("`r"); Start-Sleep -Seconds 1
    $initial=$serial.ReadExisting()
    if($initial -match 'login:\s*$') {$serial.Write("root`r"); Start-Sleep -Seconds 1; [void]$serial.ReadExisting()}
    [void](Run 'awk ''$1=="/dev/sda2" && $2=="/" {ok=1} END{exit !ok}'' /proc/mounts')
    $files=@{
        'h32-audio-start'='/usr/local/sbin/h32-audio-start'
        'h32-media-play'='/usr/local/bin/h32-media-play'
        'h32-audio-asound.conf'='/opt/h32-audio/asound.conf'
        'h32-arch-asound.conf'='/mnt/usb2/archlinux/rootfs/etc/asound.conf'
        'h32-desktop.py'='/mnt/usb2/archlinux/rootfs/usr/local/bin/h32-desktop.py'
    }
    if($EnableAutostart){$files['S99zzaudio']='/etc/init.d/S99zzaudio'}
    foreach($name in $files.Keys) {
        $dest=$files[$name]
        $data=[Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText((Join-Path $PSScriptRoot $name)).Replace("`r`n","`n"))
        $enc=[Convert]::ToBase64String($data)
        [void](Run ': > /tmp/h32-audio.b64')
        for($i=0;$i -lt $enc.Length;$i+=500){
            $part=$enc.Substring($i,[Math]::Min(500,$enc.Length-$i))
            [void](Run ("printf '%s' '"+$part+"' >> /tmp/h32-audio.b64"))
        }
        [void](Run ('mkdir -p /opt/h32-audio/backup; if test -f '+$dest+' && test ! -e /opt/h32-audio/backup/'+$name+'; then cp -p '+$dest+' /opt/h32-audio/backup/'+$name+'; fi'))
        $reply=Run ('base64 -d /tmp/h32-audio.b64 > '+$dest+'.new; sha256sum '+$dest+'.new')
        $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($data)).ToLowerInvariant()
        if($reply -notmatch $hash){throw "Hash mismatch for $name : $reply"}
        [void](Run ('chmod 755 '+$dest+'.new && mv '+$dest+'.new '+$dest))
    }
    [void](Run 'sync')
    'AUDIO_FILES_VERIFIED'
} finally {if($serial.IsOpen){$serial.Close()};$serial.Dispose()}
