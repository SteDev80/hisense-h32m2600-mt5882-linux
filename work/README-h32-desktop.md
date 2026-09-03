# Desktop H32 sulla USB

Installato il 3 settembre 2026 sul sistema USB Buildroot con Arch ARM in chroot.
Non modifica eMMC, firmware Hisense o ambiente U-Boot.

## Uso

- Collegarsi via VNC all'indirizzo della TV, attualmente `192.168.1.52:5900`.
- **Start** apre il menu; **Programmi** apre il catalogo.
- **File manager → Apri** avvia il gestore integrato (navigazione, nuova
  cartella, apertura testo con Nano e apertura video). Non richiede PCManFM.
- **Lettore video → Apri** permette di scegliere un file e usa FFplay del
  sistema Buildroot; premere `q` per uscire. VNC non trasporta l'audio.
- **Installa** apre un terminale con pacchetti, dimensioni e conferma pacman.
- Dopo l'installazione premere **Aggiorna elenco**, poi **Apri**.
- **Personalizza** cambia palette dello sfondo e salva la scelta sulla USB.
- **Desktop** minimizza/ripristina le finestre; non chiude i documenti.
- **Start → Spegni Linux** arresta il sistema prima di rimuovere la USB.

Nano e Htop sono installati e rispondono correttamente al controllo versione.
Gli altri programmi nel catalogo sono disponibili nei repository ARM, ma non
sono tutti collaudati sul kernel vendor 3.10. Non viene eseguito un aggiornamento
completo della distribuzione e non vengono disabilitate le firme pacman.
Se l'orologio torna al 1970, l'installer tenta la sincronizzazione e si ferma
se non riesce: occorre correggere data e ora prima di installare.

## File

- `h32-desktop.py`: wallpaper, dock, Start e catalogo, Python/Tk dentro Arch.
- `h32-package-task`: installer interattivo con lista di pacchetti consentiti.
- `h32-desktop-start`, `S99zzdesktop`: avvio nel desktop VNC esistente.
- `h32-fluxbox.style`, `h32-fluxbox.init`: tema e configurazione Fluxbox.
- `install-desktop-ttl.ps1`: distribuzione su COM3 con controllo root USB,
  verifica SHA-256 e backup dei file esistenti in `/opt/h32-desktop-backup`.

Dipendenze Arch aggiunte: Tk, font DejaVu e relative librerie X11.
Lo sfondo viene salvato in `/root/.config/h32-wallpaper` dentro Arch.
Log avvio: `/var/log/h32-desktop.log` sul sistema host USB.
Log applicazioni: `/tmp/h32-applications.log` dentro Arch.

Correzioni: il PATH del desktop include anche `/usr/sbin` e `/sbin`, necessari
al comando host `chroot` negli avvii da xterm. PCManFM e MPV non erano installati;
il download delle dipendenze falliva con timeout DNS. Le due funzioni principali
usano ora componenti locali senza scaricare il relativo stack GTK/Mesa/MPV.
Il successivo tentativo di installazione ha aggiunto PCManFM, ma un riavvio ha
interrotto l'installazione di alsa-lib. La libreria è stata reinstallata dalla
cache con verifica della firma: `pacman -Dk` non segnala errori e `pacman -Qk
alsa-lib` non segnala file mancanti. MPV non risulta installato.
FFplay è stato verificato con un breve AVI MPEG-4 generato localmente e rendering
software (uscita regolare, codice 0). Non sono garantiti tutti i codec o l'audio.

Per disabilitare solo il nuovo desktop al prossimo avvio, togliere il permesso
eseguibile a `/etc/init.d/S99zzdesktop`. Il servizio VNC originale resta separato.
