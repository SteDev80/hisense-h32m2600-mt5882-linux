$ErrorActionPreference='Stop'
$s=[IO.Ports.SerialPort]::new('COM3',115200,'None',8,'One')
$s.DtrEnable=$false
$s.RtsEnable=$false
$s.WriteTimeout=5000
function Invoke-Line([string]$line) {
    $marker='__DESKTOP_'+[Guid]::NewGuid().ToString('N')
    $s.Write('('+ $line + '); echo '+$marker+':$?' + "`r")
    $buf=''
    $until=[DateTime]::UtcNow.AddSeconds(30)
    while([DateTime]::UtcNow -lt $until) {
        $buf+=$s.ReadExisting()
        if($buf -match ([regex]::Escape($marker)+':(\d+)')) {
            if($Matches[1] -ne '0'){throw "Remote command failed: $line`n$buf"}
            return $buf
        }
        Start-Sleep -Milliseconds 20
    }
    throw 'Serial timeout'
}
try {
    $s.Open(); $s.Write("`r"); Start-Sleep -Seconds 1
    $initial=$s.ReadExisting()
    if($initial -match 'login:\s*$') {$s.Write("root`r"); Start-Sleep -Seconds 1; [void]$s.ReadExisting()}
    [void](Invoke-Line 'awk ''$1=="/dev/sda2" && $2=="/" {ok=1} END{exit !ok}'' /proc/mounts')
    $files=@{
        'h32-desktop.py'='/mnt/usb2/archlinux/rootfs/usr/local/bin/h32-desktop.py'
        'h32-fluxbox.style'='/usr/share/fluxbox/styles/H32'
        'h32-fluxbox.init'='/root/.fluxbox/init'
        'h32-package-task'='/mnt/usb2/archlinux/rootfs/usr/local/bin/h32-package-task'
        'h32-desktop-start'='/usr/local/sbin/h32-desktop-start'
        'S99zzdesktop'='/etc/init.d/S99zzdesktop'
        'capture-h32-desktop.py'='/mnt/usb2/archlinux/rootfs/usr/local/bin/capture-h32-desktop.py'
    }
    foreach($name in $files.Keys) {
        $dest=$files[$name]
        $sourceText=[IO.File]::ReadAllText((Join-Path $PSScriptRoot $name)).Replace("`r`n","`n")
        $data=[Text.Encoding]::UTF8.GetBytes($sourceText)
        $encoded=[Convert]::ToBase64String($data)
        [void](Invoke-Line ('mkdir -p '+($dest.Substring(0,$dest.LastIndexOf('/')))+'; : > /tmp/h32-desktop-upload.b64'))
        for($i=0;$i -lt $encoded.Length;$i+=600){
            $part=$encoded.Substring($i,[Math]::Min(600,$encoded.Length-$i))
            [void](Invoke-Line ("printf '%s' '"+$part+"' >> /tmp/h32-desktop-upload.b64"))
        }
        [void](Invoke-Line ('mkdir -p /opt/h32-desktop-backup; if test -f '+$dest+' && test ! -f /opt/h32-desktop-backup/'+$name+'; then cp -p '+$dest+' /opt/h32-desktop-backup/'+$name+'; fi'))
        $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($data)).ToLowerInvariant()
        $out=Invoke-Line ('base64 -d /tmp/h32-desktop-upload.b64 > '+$dest+'; chmod 755 '+$dest+'; sha256sum '+$dest)
        if($out -notmatch $hash){throw 'Hash mismatch'}
    }
    [void](Invoke-Line 'rm -f /tmp/h32-desktop-upload.b64; sync')
    'DESKTOP_FILES_VERIFIED'
} finally {if($s.IsOpen){$s.Close()};$s.Dispose()}
