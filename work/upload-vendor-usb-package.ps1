param([string]$TvIp='192.168.1.50',[string]$PcIp='192.168.1.48', [string]$Package, [string]$Destination='/proc/1/root/mnt/usb2/h32-vendor-v1.tar.gz')
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$repo=Split-Path $PSScriptRoot -Parent
if (!$Package) { $Package=Join-Path $repo 'outputs\vendor-usb-v1\h32-vendor-v1.tar.gz' }
$remote='/tmp/h32-upload-'+[Guid]::NewGuid().ToString('N')
$token=[Guid]::NewGuid().ToString('N')+[Guid]::NewGuid().ToString('N')
$config=@{
    destination=$Destination
    client_ip=$PcIp; bind_ip=$TvIp; token=$token
    size=(Get-Item -LiteralPath $package).Length
    sha256=(Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
} | ConvertTo-Json -Compress
$s=[IO.Ports.SerialPort]::new('COM3',115200,'None',8,'One')
$s.DtrEnable=$false; $s.RtsEnable=$false; $s.WriteTimeout=5000
function Invoke-Line([string]$Line) {
    $s.Write($Line+"`r"); $buf=''; $deadline=[DateTime]::UtcNow.AddSeconds(30)
    do {
        $buf+=$s.ReadExisting()
        if($buf -match '(?m)^#\s*$'){return $buf}
        Start-Sleep -Milliseconds 30
    } while([DateTime]::UtcNow -lt $deadline)
    throw 'TTL shell response timeout'
}
function Send-File([byte[]]$Bytes,[string]$Path) {
    $encoded=[Convert]::ToBase64String($Bytes)
    for($offset=0;$offset -lt $encoded.Length;$offset+=200){
        $piece=$encoded.Substring($offset,[Math]::Min(200,$encoded.Length-$offset))
        [void](Invoke-Line ("printf '%s' '"+$piece+"' >> "+$Path+'.b64'))
    }
    $reply=Invoke-Line ('base64 -d '+$Path+'.b64 > '+$Path+' && sha256sum '+$Path)
    $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
    if($reply -notmatch $hash){throw 'Uploaded helper hash mismatch'}
}
try{
    $s.Open(); $s.DiscardInBuffer(); [void](Invoke-Line '')
    [void](Invoke-Line 'umask 077')
    Send-File ([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'receive-usb-package-once.py'))) ($remote+'.py')
    Send-File ([Text.Encoding]::UTF8.GetBytes($config)) ($remote+'.json')
    [void](Invoke-Line ('chroot /mnt/usb2/archlinux/rootfs /usr/bin/python3 -B /proc/1/root'+$remote+'.py /proc/1/root'+$remote+'.json > '+$remote+'.log 2>&1 < /dev/null &'))
    Start-Sleep -Seconds 2
    $reply=Invoke-Line ('cat '+$remote+'.log')
    if($reply -notmatch '(?m)^UPLOAD_READY\r?$'){throw 'USB receiver did not start'}
    $reply=Invoke-WebRequest -Uri ('http://'+$TvIp+':8099/package') -Method Put -InFile $package -Headers @{'X-Package-Key'=$token} -ContentType 'application/octet-stream' -TimeoutSec 180
    $body=if($reply.Content -is [byte[]]){[Text.Encoding]::UTF8.GetString($reply.Content)}else{[string]$reply.Content}
    if($body -notmatch 'USB_PACKAGE_VERIFIED'){throw 'Package upload not verified'}
    Write-Output 'USB_PACKAGE_VERIFIED'
}finally{if($s.IsOpen){$s.Close()}}
