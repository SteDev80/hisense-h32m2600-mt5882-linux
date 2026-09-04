# Audio altoparlanti Hisense nel Linux USB

La configurazione riguarda il rootfs Buildroot USB con kernel 3.10.27 e
chroot Arch; non cambia U-Boot, firmware originale o selezione del sistema.
Il selettore Windows/TTL continua ad avviare Linux come prima.

## Componenti

- `/etc/init.d/S99zzaudio` avvia `/usr/local/sbin/h32-audio-start` dopo
  la preparazione del chroot Arch, prima del desktop.
- Controlli: root su USB, nessun mount eMMC, kernel esatto e hash dei moduli.
- Il dispositivo eMMC e le sue partizioni sono impostati in sola lettura
  nel block layer. Un modulo proprietario può comunque accedere direttamente
  all'hardware: questa protezione non equivale a un audit del driver.
- `dtv_driver.ko panel_early_init=-1`, poi `snd-mtk.ko`, senza forzature.
- Librerie Buildroot ALSA 1.2.13 e SDL 2.30.12 ricompilata completamente
  con ALSA, isolate in `/opt/h32-audio/runtime-v2`.
- `/usr/local/bin/h32-media-play` usa queste librerie e FFplay esistente.
- Conversione automatica a mono S16_LE, 48 kHz; niente SDL dummy.
- Il desktop richiama il nuovo lettore. Anche ALSA nel chroot Arch ha
  il dispositivo predefinito configurato per la TV.

La soluzione evita `snd_pcm_drain`, che rimane difettoso nel vecchio probe:
SDL chiude il dispositivo con il proprio percorso standard, verificato senza
timeout. Non è stata corretta internamente la funzione del driver proprietario.

## Utilizzo

Aprire un file dal file manager oppure dal Lettore video. Il suono esce
dalla TV, non dal computer VNC. Volume iniziale prudente al 10%; nel lettore
usare `9` per diminuirlo, `0` per aumentarlo, spazio per pausa e `q` per uscire.
Provare `/root/Video/Prova-TV-con-audio.mkv` o il file MP3 in `/root/Musica`.
Usare un lettore audio alla volta: non è stato configurato un mixer multi-app.

## Diagnostica e disattivazione

Log: `/var/log/h32-audio.log`, con `H32_AUDIO_READY` a fine inizializzazione.
`cat /proc/asound/cards` deve elencare `mtk-hisense`.

Per escludere l'avvio audio creare `/mnt/usb2/H32-AUDIO-DISABLED` nel Linux
USB e riavviare con il selettore consueto. Non forzare la rimozione di mtk_mod.
Rimuovere quel solo file per riabilitarlo al riavvio seguente.
Backup degli script sostituiti in `/opt/h32-audio/backup`.

## Build e installazione

Buildroot: integrare `audio-buildroot.fragment`, eseguire `olddefconfig`,
compilare alsa-lib e riconfigurare SDL2; pulire e ricompilare completamente
SDL2 per non conservare il vecchio elenco dei backend audio.
Il pacchetto runtime contiene solo libasound, SDL2 e usr/share/alsa,
non firmware proprietario. Upload verificato SHA256 con il ricevitore USB.
`install-audio-ttl.ps1 -EnableAutostart` installa script, configurazioni e
integrazione desktop, conservando i backup e verificando gli hash.

Pacchetto verificato `h32-audio-runtime-v2.tar.gz`:
SHA256 `29270541e65269a08cf3159da62f21420619aa50a24dda22adba29116a3c1d25`.
La prima collocazione del servizio (S96) non trovava /dev nel chroot:
è stata sostituita da S99zzaudio; la copia precedente è disabilitata nel backup.

## Verifica conclusiva — 4 settembre 2026

- Utente: confermata melodia dal nuovo FFplay/SDL ALSA.
- MP3 e video MKV con audio: uscita 0, dispositivo chiuso regolarmente.
- Riavvio USB con servizio S99zzaudio: `H32_AUDIO_READY`, scheda mtk-hisense,
  parametro panel_early_init=-1 senza caricamenti manuali.
- MP3 intero dopo il riavvio: `PLAYER_EXIT=0`, nessun timeout drain.
- Desktop attivo; VNC 192.168.1.52:5900 risponde `RFB 003.008`.
- Non verificati mixer simultanei multi-app né uso di formati multicanale
  nativi: l'uscita configurata converte in mono.
