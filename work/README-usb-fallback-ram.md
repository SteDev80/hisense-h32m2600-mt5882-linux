# Prova di continuazione comandi U-Boot in RAM

4 settembre 2026, MT5882 U-Boot 2011.12.12.
Script: mt5882-boot-dual.ps1 -UsbVendor -Mode buildroot
-RebootFromLinux -UsbFallbackRamTest.

Caricata copia valida del kernel in RAM a 0x05000000, CRC verificato.
Azzerati i soli 64 byte dell'intestazione prima di tentare un caricamento
da un nome inesistente sulla chiavetta. bootm ha rifiutato l'immagine e il
successivo comando version e' stato eseguito. Ripetuto con intestazione nulla.
Kernel/initramfs consueti caricati separatamente e Linux USB riavviato.
Nessun saveenv, cambio bootcmd persistente o scrittura eMMC impartiti.

Successiva prova con USB fisicamente rimossa, TV ferma in U-Boot:
usb storage conferma nessun dispositivo; fatload fallisce; bootm rifiuta
l'intestazione azzerata; version viene eseguito. bootcmd ancora originale.
Script: test-uboot-usb-absent.ps1; log: outputs/usb-absent-ram-test.txt.

Limiti: version era un marcatore innocuo, NON eboot. Non provati
recupero originale, corpo immagine con CRC errato,
caricamenti parziali, sequenza persistente dopo cold boot. Non e' autoboot.

Possibile sviluppo: immagine multi kernel+initramfs con CRC unico, evitando
che un kernel valido venga avviato con initramfs mancante. Ripristinare i
bootargs originali prima dell'eventuale eboot di fallback. Questi passaggi
restano da implementare e provare; non salvare la catena attuale in bootcmd.
Prima del test senza USB, fermare la TV in U-Boot: non estrarre la USB
mentre il Linux che la usa come rootfs e' in funzione.

Log: outputs/usb-fallback-ram-test.txt.
