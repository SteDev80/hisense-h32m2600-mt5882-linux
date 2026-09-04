# Suono di sistema pronto

Installato solo nel Linux USB, senza cambiare U-Boot o eMMC.
Melodia originale di quattro note, PCM mono 48 kHz, circa 1,5 secondi,
tramite il lettore audio TV esistente (volume 10%, nessuna finestra).

`/etc/init.d/S99zzzzready` avvia in background
`/usr/local/sbin/h32-ready-sound`. Il servizio non blocca il boot.
Attende audio inizializzato, processo desktop, collegamento LAN 192.168.1.x,
risposta VNC, porta SMB disponibile e connessione al display X.
Non certifica Home Assistant o ogni funzione delle applicazioni.
I controlli sono limitati nel tempo; se non riescono, non emette il suono.
Se un lettore e' gia' attivo, salta la notifica per non interferire.

Un blocco atomico con boot_id impedisce doppie riproduzioni nello stesso
avvio. Log: `/var/log/h32-ready-sound.log`, successo `H32_READY_SOUND_PLAYED`.
L'esito software non sostituisce una conferma uditiva dell'utente.
Conferma uditiva ricevuta il 4 settembre 2026 dopo un ulteriore riavvio:
l'utente ha sentito la melodia dagli altoparlanti della TV.

Per disabilitare creare `/mnt/usb2/H32-STARTUP-SOUND-DISABLED`.
Rimuovere quel solo file per riattivare al riavvio seguente.

File: `/opt/h32-audio/ready.wav`, helper Arch
`/usr/local/bin/h32-ready-check.py`. Nessun file audio preesistente sostituito.
Gli hash dei quattro file installati sono stati verificati dopo la copia.
La prima prova manuale ha completato la riproduzione; un secondo richiamo
non l'ha ripetuta. Riavvio completo verificato il 4 settembre 2026:
nuovo boot_id 66568f96-b9c6-402d-b691-e3745d617a61, riproduzione automatica
terminata con H32_READY_SOUND_PLAYED, VNC risponde RFB 003.008 e
condivisione Windows accessibile. Data/ora risincronizzate dal PC.
