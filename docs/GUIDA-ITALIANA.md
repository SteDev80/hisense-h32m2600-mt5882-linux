# Guida H32 Linux USB

Configurazione provata fino al 10 settembre 2026, non procedura universale per altre TV.

## Accensione

1. A TV spenta inserisci la USB Linux già preparata.
2. Accendi normalmente: non occorrono PC, selettore Windows o TTL.
3. Attendi: quattro note indicano audio, desktop, LAN, VNC e SMB pronti.

Se la chiavetta è assente, U-Boot avvia automaticamente il sistema Hisense.
Il TTL resta uno strumento di recupero e non deve rimanere collegato nell'uso
quotidiano.

Buildroot contiene già desktop e programmi Arch in chroot: non serve scegliere
il percorso Arch sperimentale separato. La USB deve restare inserita.

Alternativa, dalla directory del progetto, con TV ferma al prompt U-Boot:

```powershell
.\work\mt5882-boot-dual.ps1 -UsbVendor -Mode buildroot
```

Per attendere un'accensione fisica aggiungere `-WaitForPowerCycle`.
Gli script storici hanno percorsi e COM3 specifici del laboratorio: controllarli
prima dell'uso su altri PC. Non impartire `saveenv`.

## Desktop e applicazioni

Client VNC: `<IP-TV>:5900`, nel laboratorio `192.168.1.54:5900`.
Usa la password privata configurata sulla TV, non una credenziale pubblica.

- **Start**: applicazioni, terminali, Wi-Fi, arresto.
- **Programmi → Apri**: applicazione disponibile; **Installa** mostra pacchetti,
  dimensioni e chiede conferma. Aggiorna l'elenco dopo l'installazione.
- **Personalizza**: palette dello sfondo; immagine in basso a destra.
- **Desktop**: minimizza/ripristina senza chiudere documenti.
- **Vol 0–100%** accanto all'orologio: trascina il cursore per salvare il
  livello sulla USB. Se FFplay è attivo, il desktop invia anche la variazione
  corrente a passi del 10%; altrimenti il valore vale dalla prossima apertura.

Il catalogo non garantisce compatibilità di ogni pacchetto ARM moderno con il
kernel 3.10.27. Non aggiornare tutto alla cieca o disabilitare le firme pacman.
Il fuso Arch è Europe/Rome. `S99zzzztime` sincronizza l'orologio tramite NTP
quando la rete diventa disponibile e poi ogni ora; in caso di errore riprova.
Richiede il pacchetto Arch `ntp`, che fornisce `sntp`.

## Audio, video e melodia

Apri MP3/WAV/video dal file manager o lettore. **Il suono esce dalla TV**, non
dal PC VNC. Volume iniziale 10%: `9` diminuisce, `0` aumenta, spazio pausa,
`q` chiude. Un solo lettore alla volta; video con rendering software.

Se un file condiviso non parte da `/root/Condivisa`, aprilo da `/srv/condivisa`:
il launcher non risolve ancora ogni link assoluto passando dal chroot all'host.

La melodia dura circa 1,5 secondi, una volta per boot, dopo i controlli dei
servizi. Non attende Home Assistant, non suona se i servizi non risultano pronti
entro il limite e viene saltata se un lettore è già in esecuzione.

Per disabilitarla, dal terminale **Buildroot**:

```sh
touch /mnt/usb2/H32-STARTUP-SOUND-DISABLED
```

Per riabilitarla al prossimo boot rimuovere soltanto quel file.
Log: `/var/log/h32-ready-sound.log` → `H32_READY_SOUND_PLAYED`.
Audio: `/var/log/h32-audio.log` → `H32_AUDIO_READY`.

## Telecomando IR e playlist

Apri **Programmi → Telecomando IR e playlist**. Nella scheda Telecomando:

1. **Leggi codice** mostra nel riquadro il codice grezzo quantizzato senza
   associarlo a un'azione.
2. **Registra** accanto a una funzione, poi una pressione breve sul telecomando,
   salva l'associazione in `/root/.config/h32-ir-map.json` sulla USB.
3. **Prova** invia l'azione al desktop. Non registrare Power durante i test.

Il telecomando deve essere rilevato dal ricevitore e dal protocollo configurato
nel driver MediaTek. Non è garantita la compatibilità con ogni telecomando IR;
un ricevitore USB supportato da Linux è l'alternativa per LIRC generico.

La scheda Playlist apre file M3U, M3U8 e PLS, inclusi percorsi relativi e URL,
e li riproduce con l'uscita audio della TV. Un esempio è
`work/H32-Musica-Test.m3u`; i brani citati non sono inclusi nel repository.
Il volume scelto viene memorizzato in `/root/.config/h32-volume` sulla USB ed è
condiviso con il cursore accanto all'orologio.

## Condivisione Windows 11

In Esplora file apri `\\192.168.1.54\Condivisa`, adattando l'IP.
Account `HISENSE-TV\tv`, password privata impostata nella preparazione.
Connetti un'unità di rete con una lettera libera; nella macchina di prova è T:.

Dati USB: `/mnt/usb2/Condivisa`; nel desktop Arch: `/srv/condivisa`.
SMB2/3 autenticato e firmato, niente guest/SMB1 o condivisione dell'intero root.
Non è garantita la comparsa automatica nell'elenco Rete. Sulla macchina di prova
il router riserva `192.168.1.54` al MAC Wi-Fi della TV. Non esporre i servizi a
Internet.

## Wi-Fi e Home Assistant

Dal terminale Buildroot: `h32-wifi-setup` chiede SSID/password e salva solo sulla
USB; `h32-wifi-status` mostra lo stato. Non pubblicare configurazione WPA o log
contenenti dati personali. La password non viene mostrata durante l'immissione.

Home Assistant Core: `http://<IP-TV>:8123` dopo il proprio avvio. Non è HA OS,
né una configurazione certificata per centrali o impianti critici.

## Spegnimento

Usa **Start → Spegni Linux** e attendi l'arresto prima di togliere USB o corrente.
Non rinominare o eliminare `uMulti-h32-usb-test-v2` dalla partizione FAT32.

## Ricostruzione e installazione

Il repository è un archivio di sorgenti e integrazione, non un'immagine USB
completa. Servono kernel 3.10.27, bootstrap e rootfs compatibili, Buildroot/Arch,
driver e componenti vendor estratti dalla propria TV. Non forzare moduli con
release, simboli o hash diversi. Gli artefatti locali non sono distribuiti qui.

- [Bootstrap USB](../work/README-usb-vendor-v1.md).
- [Runtime audio e installer](../work/README-audio-permanente-usb.md).
- [Desktop e dipendenze](../work/README-h32-desktop.md).
- [Telecomando IR e playlist](../work/README-ir-playlist.md).
- [Samba e account](../work/README-samba-usb.md).
- [Melodia e controlli](../work/README-ready-sound.md).

Compila il selettore su Windows con .NET 8:

```powershell
dotnet build windows/H32BootSelector/H32BootSelector.csproj -c Release
```

`python3 work/build-ready-chime.py` rigenera la melodia; copia pronta in
`assets/audio/ready.wav`. Per una prima installazione il programma
`work/install-ready-sound.sh` attende `h32-ready-sound`, `h32-ready-check.py`,
`S99zzzzready` e `ready.wav` nella condivisione `h32-ready-install`.
Eseguirlo dal terminale Buildroot dopo runtime audio e desktop. Rifiuta di
sovrascrivere un'installazione esistente.

Sfondo: copiare `assets/desktop/portrait.jpg` nel chroot Arch come
`/usr/local/share/h32-desktop/portrait.jpg`, poi riavviare il desktop.

## Avvio autonomo e limite conosciuto

Il contenitore unico kernel/initramfs è stato installato nella catena di boot.
Il fallback al firmware originale è stato provato realmente con USB rimossa;
l'avvio Linux è stato provato senza TTL. Questa vecchia build `bootm` non rifiuta
però ogni alterazione del payload nonostante `verify=yes`: una USB corrotta può
bloccarsi dopo l'ingresso nel kernel. Rimuovendola al riavvio torna Hisense.

Il kernel USB supera gli slot originali da 4 MiB: non flasharlo lì. Comando,
backup e ripristino sono nella [guida all'autoboot](../work/README-autoboot-usb.md).
