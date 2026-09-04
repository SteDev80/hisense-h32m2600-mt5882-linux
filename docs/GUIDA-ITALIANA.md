# Guida H32 Linux USB

Configurazione provata il 4 settembre 2026, non procedura universale per altre TV.

## Accensione

1. Lascia la TV spenta, inserisci la USB Linux già preparata e collega il TTL
   al PC con il cablaggio già verificato. Non cambiare tensioni o collegamenti.
2. Chiudi gli altri programmi che occupano la seriale.
3. Apri H32BootSelector, scegli la porta e attiva **Variante USB con driver
   recuperati (p27 non montata)**.
4. Scegli **Avvia Buildroot USB + driver**, accendi la TV quando richiesto.
5. Attendi: quattro note indicano audio, desktop, LAN, VNC e SMB pronti.

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

Client VNC: `<IP-TV>:5900`, nel laboratorio `192.168.1.52:5900`.
Usa la password privata configurata sulla TV, non una credenziale pubblica.

- **Start**: applicazioni, terminali, Wi-Fi, arresto.
- **Programmi → Apri**: applicazione disponibile; **Installa** mostra pacchetti,
  dimensioni e chiede conferma. Aggiorna l'elenco dopo l'installazione.
- **Personalizza**: palette dello sfondo; immagine in basso a destra.
- **Desktop**: minimizza/ripristina senza chiudere documenti.

Il catalogo non garantisce compatibilità di ogni pacchetto ARM moderno con il
kernel 3.10.27. Non aggiornare tutto alla cieca o disabilitare le firme pacman.
Correggi data e ora prima di usare TLS o installare programmi. Il fuso Arch è
Europe/Rome; la sincronizzazione con il PC è stata fatta durante i test, non
è garantita automaticamente a ogni accensione.

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

## Condivisione Windows 11

In Esplora file apri `\\192.168.1.52\Condivisa`, adattando l'IP.
Account `HISENSE-TV\tv`, password privata impostata nella preparazione.
Connetti un'unità di rete con una lettera libera; nella macchina di prova è T:.

Dati USB: `/mnt/usb2/Condivisa`; nel desktop Arch: `/srv/condivisa`.
SMB2/3 autenticato e firmato, niente guest/SMB1 o condivisione dell'intero root.
Non è garantita la comparsa automatica nell'elenco Rete. Riserva l'IP nel router
oppure aggiorna i collegamenti quando cambia. Non esporre i servizi a Internet.

## Wi-Fi e Home Assistant

Dal terminale Buildroot: `h32-wifi-setup` chiede SSID/password e salva solo sulla
USB; `h32-wifi-status` mostra lo stato. Non pubblicare configurazione WPA o log
contenenti dati personali. La password non viene mostrata durante l'immissione.

Home Assistant Core: `http://<IP-TV>:8123` dopo il proprio avvio. Non è HA OS,
né una configurazione certificata per centrali o impianti critici.

## Spegnimento

Usa **Start → Spegni Linux** e attendi l'arresto prima di togliere USB o corrente.
La semplice accensione con USB inserita **non basta ancora**: serve il TTL.
Nessuna modifica U-Boot permanente è stata installata.

## Ricostruzione e installazione

Il repository è un archivio di sorgenti e integrazione, non un'immagine USB
completa. Servono kernel 3.10.27, bootstrap e rootfs compatibili, Buildroot/Arch,
driver e componenti vendor estratti dalla propria TV. Non forzare moduli con
release, simboli o hash diversi. Gli artefatti locali non sono distribuiti qui.

- [Bootstrap USB](../work/README-usb-vendor-v1.md).
- [Runtime audio e installer](../work/README-audio-permanente-usb.md).
- [Desktop e dipendenze](../work/README-h32-desktop.md).
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

## Avvio autonomo: limite conosciuto

Il contenitore unico kernel/initramfs parte, ma `bootm` ha avviato anche una
copia con payload alterato nonostante `verify=yes`. `iminfo` verifica il CRC;
il selettore Windows ne controlla il risultato prima di inviare `bootm`.
Il parser di questo U-Boot non supporta le condizioni normalmente usate per
decidere in autonomia: non basta concatenare i comandi e salvarli.

Occorrono un controllo affidabile e un recupero collaudato. Il kernel USB
supera gli slot originali da 4 MiB: non flasharlo lì. Dettagli nel
[rapporto del test](../work/README-usb-multi-test.md).
