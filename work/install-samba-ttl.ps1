param([switch]$UpdateOnly)
$ErrorActionPreference='Stop'
$s=[IO.Ports.SerialPort]::new('COM3',115200,'None',8,'One')
$s.DtrEnable=$false; $s.RtsEnable=$false; $s.WriteTimeout=5000
function Run([string]$line) {
    $marker='__SMB_'+[Guid]::NewGuid().ToString('N')
    $s.Write('('+ $line + '); echo '+$marker+':$?' + "`r")
    $buf=''; $until=[DateTime]::UtcNow.AddSeconds(30)
    while([DateTime]::UtcNow -lt $until) {
        $buf+=$s.ReadExisting()
        if($buf -match ([regex]::Escape($marker)+':(\d+)')) {
            if($Matches[1] -ne '0'){throw 'Remote Samba setup failed'}; return $buf
        }
        Start-Sleep -Milliseconds 30
    }
    throw 'Samba UART timeout'
}
try {
    $s.Open(); $s.Write("`r"); Start-Sleep -Seconds 1; [void]$s.ReadExisting()
    [void](Run 'awk ''$1=="/dev/sda2" && $2=="/" {ok=1} END{exit !ok}'' /proc/mounts')
    if (!$UpdateOnly) {
    [void](Run 'test -x /mnt/usb2/archlinux/rootfs/usr/bin/smbd && test ! -e /mnt/usb2/Condivisa && test ! -e /mnt/usb2/archlinux/rootfs/etc/samba/smb.conf')
    [void](Run 'chroot /mnt/usb2/archlinux/rootfs /usr/bin/useradd --system --no-create-home --shell /usr/bin/nologin tv')
    [void](Run 'mkdir -p /mnt/usb2/Condivisa /mnt/usb2/archlinux/rootfs/srv/condivisa /mnt/usb2/archlinux/rootfs/etc/samba; chroot /mnt/usb2/archlinux/rootfs /usr/bin/chown tv:tv /proc/1/root/mnt/usb2/Condivisa; chmod 770 /mnt/usb2/Condivisa')
    }
    $files=@{'h32-smb.conf'='/mnt/usb2/archlinux/rootfs/etc/samba/smb.conf';'S99zzzsamba'='/etc/init.d/S99zzzsamba'}
    foreach($name in $files.Keys) {
        $dest=$files[$name]
        $data=[Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText((Join-Path $PSScriptRoot $name)).Replace("`r`n","`n"))
        $enc=[Convert]::ToBase64String($data)
        [void](Run ': > /tmp/h32-smb-upload.b64')
        for($i=0;$i -lt $enc.Length;$i+=400){
            $part=$enc.Substring($i,[Math]::Min(400,$enc.Length-$i))
            [void](Run ("printf '%s' '"+$part+"' >> /tmp/h32-smb-upload.b64"))
        }
        $reply=Run ('base64 -d /tmp/h32-smb-upload.b64 > '+$dest+'.new; sha256sum '+$dest+'.new')
        $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($data)).ToLowerInvariant()
        if($reply -notmatch $hash){throw "Hash mismatch: $name"}
        [void](Run ('chmod 755 '+$dest+'.new && mv '+$dest+'.new '+$dest))
    }
    if (!$UpdateOnly) {
    $password='TV-'+[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(8))
    $credential=[PSCredential]::new('HISENSE-TV\tv',(ConvertTo-SecureString $password -AsPlainText -Force))
    $credential | Export-Clixml -LiteralPath (Join-Path $PSScriptRoot '..\outputs\h32-smb-credential.xml')
    [void](Run ("printf '%s\n%s\n' '"+$password+"' '"+$password+"' | chroot /mnt/usb2/archlinux/rootfs /usr/bin/smbpasswd -s -a tv"))
    $password=$null
    [void](Run 'test ! -e /mnt/usb2/archlinux/rootfs/root/Condivisa && ln -s /srv/condivisa /mnt/usb2/archlinux/rootfs/root/Condivisa')
    }
    Run '/etc/init.d/S99zzzsamba start; sync'
} finally {if($s.IsOpen){$s.Close()};$s.Dispose()}
