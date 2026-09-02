$ErrorActionPreference = 'Stop'
$serial = [System.IO.Ports.SerialPort]::new('COM3',115200,'None',8,'One')
$serial.Handshake='None'; $serial.DtrEnable=$false; $serial.RtsEnable=$false
$serial.ReadTimeout=100; $serial.WriteTimeout=1000
$output='C:\Users\steki\Documents\Codex\2026-08-30\referenced-chatgpt-conversation-this-is-an\outputs\buildroot-h32m2600\kernelA-mdl-uart.txt'
$writer=[System.IO.StreamWriter]::new($output,$false,[System.Text.UTF8Encoding]::new($false))
$received=0L; $nextProgress=1MB; $tail=''
try{
    $serial.Open(); $serial.Write("`r"); Start-Sleep -Milliseconds 250
    $initial=$serial.ReadExisting(); if($initial-notmatch'mt5882\s*#'){throw 'Prompt U-Boot non confermato; dump annullato.'}
    [Console]::WriteLine('[HOST] UART_KERNEL_DUMP_STARTED: 0x2aabf8 byte da RAM.')
    $serial.Write("md.l 0x02000000 0x0aaafe`r")
    $deadline=[DateTime]::UtcNow.AddMinutes(45)
    while([DateTime]::UtcNow-lt$deadline){
        $text=$serial.ReadExisting()
        if($text.Length-gt 0){
            $writer.Write($text);$writer.Flush();$received+=$text.Length
            $tail+= $text;if($tail.Length-gt 512){$tail=$tail.Substring($tail.Length-512)}
            if($received-ge$nextProgress){[Console]::WriteLine(('[HOST] UART dump ricevuti {0:N1} MiB di testo...' -f ($received/1MB)));$nextProgress+=1MB}
            if($tail-match'mt5882\s*#\s*$'){[Console]::WriteLine(('[HOST] UART_KERNEL_DUMP_OK: {0} caratteri acquisiti.' -f $received));break}
        }
        Start-Sleep -Milliseconds 10
    }
    if($tail-notmatch'mt5882\s*#\s*$'){throw 'Timeout o dump UART incompleto.'}
}finally{
    $writer.Dispose();if($serial.IsOpen){$serial.Close()}
}
