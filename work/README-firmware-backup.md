# Estrazione firmware H32M2600

La procedura legge l'eMMC e salva nuove immagini sulla seconda partizione
ext4 della Lexar. Non modifica U-Boot, le partizioni sorgente o il loro stato
read-only. Le partizioni sorgente devono risultare non montate.

## Ambito

- `mmcblk0p1`–`mmcblk0p26`: partizioni firmware e configurazioni presenti
- `mmcblk0boot0`, `mmcblk0boot1`: aree hardware di avvio
- esclusi `p27` (Linux modificato e attivo), RPMB e spazio non partizionato

Non e' una clonazione completa dell'eMMC, ne' una prova che tutte le partizioni
contengano ancora dati di fabbrica. I file riproducono i byte presenti al momento
dell'acquisizione. Le impostazioni personali possono essere incluse.

## Script

1. `run-firmware-backup-ttl.ps1` invia `backup-original-partitions.sh` via UART
   e ne verifica l'hash prima dell'esecuzione. Richiede una shell root Linux
   gia' aperta, non il prompt U-Boot.
2. Lo script verifica che `/mnt/usb2` sia la Lexar `/dev/sda2`, controlla spazio
   e mount, copia ogni sorgente con `dd if=... of=<file-su-USB> conv=fsync`,
   confronta lunghezza e SHA-256, poi rinomina il file `.partial`.
3. `fetch-firmware-backup.ps1 -Tag <cartella>` usa temporaneamente Python nel
   chroot Arch per trasmettere un archivio gzip al PC. Il server accetta solo
   l'IP indicato e un token casuale, serve unicamente quel backup e si chiude
   dopo il trasferimento. IP predefiniti: TV `192.168.1.50`, PC `192.168.1.48`.
4. `verify-firmware-archive.py <archivio.partial> [report.json]` confronta i 28
   hash, controlla il CRC gzip e calcola SHA-256 dell'archivio. Rinominare
   `.tar.gz.partial` in `.tar.gz` soltanto dopo un esito positivo.

Il trasporto HTTP/Telnet e' per la sola LAN fidata: non e' cifrato. Non esporre
le porte al router o a Internet. Nessun server viene installato permanentemente.

Il Buildroot attualmente in uso ha la radice su `p27` montata in scrittura:
le normali attivita' del sistema possono continuare a scrivere su quella
partizione, che non viene acquisita. La procedura di dump non vi scrive file.

## Riservatezza e integrita'

I dump possono contenere identificatori, configurazioni e materiale specifico
del dispositivo. Restano sotto `outputs/`, escluso da Git; non caricarli su
GitHub o servizi pubblici. Conservare `manifest.tsv`, `SHA256SUMS` e report.
Un'interruzione conserva i file parziali: non considerarli backup validi.

Non scollegare una USB ancora usata dal chroot Arch/Home Assistant. Un backup
gia' trasferito e verificato sul PC permette di lasciarla inserita nella TV.
