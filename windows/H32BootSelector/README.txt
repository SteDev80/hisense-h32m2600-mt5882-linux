H32BootSelector - Hisense H32M2600 / MediaTek MT5882

1. Lascia la TV spenta.
2. Inserisci la chiavetta Lexar e collega il TTL al PC.
3. Apri H32BootSelector.exe.
4. Scegli Buildroot oppure Arch Linux ARM sperimentale.
5. Accendi la TV quando il programma mostra che e' in attesa.

Buildroot:
  VNC <indirizzo-TV>:5900, password mostrata sulla console UART all'avvio
  Telnet 192.168.1.50:23, utente root senza password

Arch sperimentale:
  VNC <indirizzo-TV>:5900, password mostrata sulla console UART all'avvio
  Shell Arch Telnet 192.168.1.50:2323
  Buildroot resta il supervisore hardware; systemd e' disabilitato.

Il programma non esegue saveenv, mmc write, erase o upgrade.
U-Boot e il firmware Hisense non vengono modificati.
