# Telecomando IR e playlist

Integrazione sperimentale per la Hisense H32M2600/MT5882 collaudata. Tutti i
file di configurazione sono sulla chiavetta USB; non scrive eMMC o U-Boot.

## Componenti

- `h32-ir-manager.py`: interfaccia Python/Tk con schede Telecomando e Playlist.
- `S99zzzzinput`: carica il modulo USB HID esatto e avvia il demone IR.
- `H32-Musica-Test.m3u`: esempio con percorsi relativi; non include i brani.
- `h32-media-play`: applica il volume persistente e usa FFplay/ALSA della TV.
- `h32-desktop.py`: mostra accanto all'orologio lo stesso livello e permette
  di regolarlo con un cursore 0–100%.

Il programma verifica kernel `3.10.27`, root su `/dev/sda2` ed eMMC in sola
lettura prima di accedere al ricevitore. L'accesso MMIO è esclusivamente in
lettura. La mappa è `/root/.config/h32-ir-map.json`; il volume è
`/root/.config/h32-volume`, entrambi nel chroot Arch sulla USB.

## Uso

Nel catalogo aprire **Telecomando IR e playlist**. **Leggi codice** ascolta una
pressione e mostra nel riquadro un valore esadecimale ottenuto dalla sequenza di
impulsi. **Registra** salva la stessa impronta per la funzione selezionata;
**Prova** invia direttamente l'azione X11.

Azioni disponibili: frecce, OK, Indietro, Menu Start, Volume +/−, Play/Pausa e
Stop. Evitare Power durante l'apprendimento. Il demone ricarica la mappa a ogni
tasto, quindi non richiede un riavvio dopo la registrazione.

La scheda Playlist legge M3U, M3U8 e PLS, risolve i percorsi relativi rispetto
al file playlist e accetta URL. Riproduci selezionato, Riproduci tutto e Stop
usano `h32-media-play`, quindi l'audio esce dagli altoparlanti della TV.

## Limiti

Il decoder proprietario non espone evdev/rc-core. L'apprendimento passivo legge
il buffer impulsi MT5882 e dipende dal telecomando e dal profilo IR già attivo.
Non è garantito per telecomandi di altre marche. I profili diagnostici del
driver non vengono cambiati dal servizio automatico.

Questa funzione è sperimentale finché almeno due tasti distinti non vengono
acquisiti e verificati sul telecomando scelto. In caso di errore il resto del
desktop, USB HID, VNC e lettore rimangono indipendenti.
