H32BootSelector - Hisense H32M2600 / MediaTek MT5882

1. Lascia la TV spenta.
2. Inserisci la chiavetta Lexar e collega il TTL al PC.
3. Apri H32BootSelector.exe.
4. Per il sistema attuale seleziona "Variante USB con driver recuperati
   (p27 non montata)" e poi "Avvia Buildroot USB + driver".
   La modalita Arch separata rimane sperimentale.
5. Accendi la TV quando il programma mostra che e' in attesa.

Buildroot:
  VNC <indirizzo-TV>:5900, password mostrata sulla console UART all'avvio
  Telnet <indirizzo-TV>:23, shell privilegiata di laboratorio: solo LAN fidata

Arch sperimentale:
  VNC <indirizzo-TV>:5900, password mostrata sulla console UART all'avvio
  Shell Arch Telnet <indirizzo-TV>:2323
  Buildroot resta il supervisore hardware; systemd e' disabilitato.

Il programma non esegue saveenv, mmc write, erase o upgrade.
U-Boot e il firmware Hisense non vengono modificati.
Audio: altoparlanti della TV; quattro note a desktop/rete/audio pronti.
Guida aggiornata: docs/GUIDA-ITALIANA.md nella radice del repository.
