# Condivisione file TV / Windows 11

Windows: unita T:, percorso `\\192.168.1.52\Condivisa`.
Z: e' gia usata dal NAS ed e' rimasta invariata.
Account dedicato `HISENSE-TV\tv`; password casuale salvata nel Gestore
credenziali di Windows. Copia DPAPI locale in outputs/h32-smb-credential.xml:
non pubblicarla e non includerla negli archivi del progetto.

## Percorsi e avvio

- Dati USB: `/mnt/usb2/Condivisa`.
- Nel chroot Arch: `/srv/condivisa`, bind mount della sola cartella dati.
- Desktop: collegamento `/root/Condivisa` nel file manager.
- Config: chroot `/etc/samba/smb.conf`.
- Avvio: host `/etc/init.d/S99zzzsamba`, dopo preparazione Arch e rete.
- Il servizio attende fino a 90 secondi l'indirizzo LAN: la sola fine dello
  script Wi-Fi non garantisce che DHCP sia gia completato.
- Log: host `/var/log/h32-samba.log` e chroot `/var/log/samba`.
- Samba 4.24.6 dal repository Arch Linux ARM; pacman -Dk senza errori.

SMB2/SMB3, firma richiesta, nessun SMB1 o guest; solo account tv.
Sono ammessi loopback e LAN 192.168.1.0/24. Solo TCP445, senza discovery
NetBIOS; usare T: o il percorso UNC, non dipendere dalla comparsa automatica
nella pagina Rete. Nessuna condivisione homes, stampanti o filesystem root.
I link simbolici nella condivisione non vengono seguiti.
Il vecchio kernel non usa io_uring/AIO per questa condivisione.

La TV deve essere accesa nel Linux USB; non esporre il servizio su Internet.
Se il DHCP cambia l'IP, aggiornare la mappatura o riservare .52 nel router.
Non modificati U-Boot, eMMC, NAS Z: o impostazioni di sicurezza SMB di Windows.

## Verifiche

Copia di LEGGIMI.txt da Windows verso T: e rilettura con SHA256 identico.
Credenziali Windows salvate, mappatura persistente T:.
La directory dati era nuova: nessun contenuto esistente sovrascritto.
Accesso anonimo alla condivisione verificato: NT_STATUS_ACCESS_DENIED.
Riavvio completo con attesa DHCP: T: riconnessa automaticamente, hash del
LEGGIMI.txt identico; Z: ancora OK. Audio H32_AUDIO_READY e VNC attivi.
