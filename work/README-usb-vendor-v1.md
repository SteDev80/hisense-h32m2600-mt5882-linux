# Buildroot USB vendor v1

**Aggiornamento 4 settembre:** Wi-Fi collegato e audio TV con avvio automatico
sono stati successivamente completati. Vedi [guida attuale](../docs/GUIDA-ITALIANA.md)
e [audio](README-audio-permanente-usb.md). I risultati qui sotto descrivono la
prima installazione del 3 settembre, prima dell'integrazione audio e WPA.

Variante sperimentale provata sulla Hisense H32M2600 il 3 settembre 2026.
Il kernel resta il 3.10.27 SMP di recupero: i moduli originali recuperati dal
firmware sono stati compilati per quella release. Non e' un aggiornamento a
Linux 5.x/6.x, ne' un'installazione Arch con kernel mainline.

## Risultato verificato

- root filesystem: `/dev/sda2`, directory `h32linux-vendor-v1/rootfs`;
- nessuna partizione eMMC montata dalla variante USB;
- modulo `mt7603u_sta` caricato senza forzare vermagic o simboli;
- interfaccia `wlan0` creata, inizializzata con successo e MAC letto da eFuse;
- nessun SSID, password o collegamento Wi-Fi configurato;
- Ethernet ancora funzionante; Home Assistant risponde HTTP 200 sulla 8123;
- VNC raggiungibile sulla 5900, ancora Xvfb software;
- vecchio kernel, bootstrap p27 e root p27 mantenuti per il recupero.

I moduli recuperati sono sotto `/opt/h32-vendor/modules`. Solo il Wi-Fi viene
caricato da `S97vendor-wifi`. Mali richiede `mtk_fb_get_property`; `snd-mtk`
richiede le funzioni `AUD_*` del sottosistema vendor. DTV, Mali, audio e i moduli
duplicati USB/storage NON sono caricati automaticamente. Un controllo positivo
dei nomi dei simboli non garantisce da solo la compatibilita' ABI completa.

## Avvio

Il nuovo H32BootSelector Windows offre la casella **Variante USB con driver
recuperati (p27 non montata)**. Selezionarla, scegliere Buildroot o Arch e
accendere la TV con USB e TTL collegati. Deselezionandola si usa l'avvio precedente.
La variante Buildroot e' stata avviata e verificata; il percorso grafico Arch
rimane disponibile ma non e' stato riavviato separatamente durante questo test.

Bootstrap FAT32: `uInitrd-h32m2600-usb-vendor-v1`, 1.977.369 byte.
SHA-256: `fbf3bc9652539bb72f69d87b519dbdd4d0b5cbf8959579dd998251df232eb10a`.
Il file `BOOT-USB-VENDOR.txt` sulla FAT32 contiene i comandi U-Boot completi.
`h32vendor=0` disattiva il caricamento automatico del Wi-Fi per una diagnosi.

Questa variante richiede la chiavetta per l'intera sessione: non scollegarla
mentre Linux, Arch o Home Assistant sono in esecuzione.

## Preparazione

`check-vendor-module-symbols.py` confronta i simboli richiesti dai moduli con il
`Module.symvers` del kernel usato. `build-vendor-usb-package.py` prepara un bundle
privato usando le immagini recuperate localmente e sostituisce soltanto `/init`
nel bootstrap gzip/newc noto. `upload-vendor-usb-package.ps1` trasferisce il bundle
con un ricevitore LAN temporaneo autenticato, vincolato al dispositivo USB.

Su questo BusyBox tar non supporta `-z`: usare `zcat archivio | tar -xf -` con
pipefail. La FAT32 puo' essere gia' montata read-only dal vecchio bootstrap:
montare un alias ro, rimontarlo rw solo per la copia e riportarlo ro al termine.
`install-vendor-usb.sh` copia il root esistente in una nuova directory USB, non
sovrascrive l'originale e sposta lo script storico `.pre-homeassistant` fuori
dall'elenco degli script di avvio della copia.

Gli artefatti e i moduli estratti restano sotto `outputs/`, escluso da Git.
Non redistribuire firmware e dati del dispositivo insieme ai soli sorgenti.
