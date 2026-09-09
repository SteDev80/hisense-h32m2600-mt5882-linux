param(
    [Parameter(Mandatory=$true)][string[]]$Command,
    [int]$TimeoutSeconds = 120,
    [string]$Port = 'COM3'
)
$ErrorActionPreference='Stop'
$serial=[IO.Ports.SerialPort]::new($Port,115200,'None',8,'One')
$serial.Handshake='None'; $serial.DtrEnable=$false; $serial.RtsEnable=$false
$serial.ReadTimeout=100; $serial.WriteTimeout=5000
try {
    $serial.Open(); $serial.Write("`r"); Start-Sleep -Milliseconds 300
    $initial=$serial.ReadExisting(); [Console]::Write($initial)
    foreach($line in $Command) {
        [Console]::WriteLine("`r`n[HOST] -> $line")
        $serial.Write($line+"`r")
        $buffer=''; $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        while([DateTime]::UtcNow-lt$deadline) {
            $text=$serial.ReadExisting()
            if($text){[Console]::Write($text);$buffer+=$text}
            if($buffer-match'mt5882\s*#\s*$'){break}
            Start-Sleep -Milliseconds 20
        }
        if($buffer-notmatch'mt5882\s*#\s*$'){throw "U-Boot prompt timeout after: $line"}
    }
} finally {if($serial.IsOpen){$serial.Close()};$serial.Dispose()}
