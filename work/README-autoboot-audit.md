# Verifica non persistente avvio selettivo — 4 settembre 2026

Obiettivo richiesto: chiavetta-chiave presente -> Linux personalizzato;
assente -> Hisense originale, senza TTL. Nessuna modifica persistente
all'avvio autorizzata/eseguita in questa verifica.

## Evidenze

- U-Boot 2011.12.12 del 30 giugno 2017, interrogato direttamente via UART.
- bootcmd originale: `eboot.lzo kernelA rootfsA`; bootdelay=0; preboot assente.
- Comandi `run`, `test` e sintassi `if ... then ... fi` rifiutati.
- `usbboot` e `load` presenti ma help insufficiente per dedurne il comportamento.
  Non eseguiti come esperimenti alla cieca.
- Kernel attuale via USB: 5.027.136 byte, maggiore dei singoli slot kernelA/B
  da 4 MiB. Non e' quindi un'immagine da scrivere direttamente in quegli slot.
- eMMC 3.817.472 KiB complessivi; p27 2 GiB ext4, non montata.
- Superblocco p27: 524288 blocchi, 461491 liberi, 4096 byte/blocco;
  flag needs_recovery presente: non effettuata riparazione ne' journal replay.
- Arch USB: du -sxh nel chroot circa 6,2 GiB; non entra integralmente in p27.
- Backup del 3 settembre: 28 immagini p1-p26 e boot0/boot1 verificate nel
  report esistente; esclusi p27, RPMB e aree non partizionate. Nessun test
  di ripristino completo validato. Non equivale a recupero garantito.

## Esito

Non installato autoboot. Nessun saveenv, flash, erase, ripartizionamento,
mount eMMC o copia di rootfs su eMMC eseguiti. Il normale bootstrap USB e'
stato riavviato con impostazioni volatili gia' usate dal selettore Windows.

Un prototipo futuro deve essere compatibile con il parser semplice e
provato in RAM per USB presente, assente, file mancanti e immagini corrotte.
Non basta concatenare fatload e bootm: occorre escludere l'uso di dati RAM
residui in caso di caricamento fallito e mantenere un ritorno originale certo.
Un selettore personalizzato resta da progettare e verificare. Nessuna
garanzia sul funzionamento del firmware originale e' ricavabile dal solo
bootcmd, e avviarlo puo' comportare normali scritture ai suoi dati.

Prima di qualsiasi modifica persistente: backup aggiornato del layout
coinvolto, comprensione del formato/CRC/ridondanza dell'ambiente, recupero
UART verificato e scelta esplicita tra sistema completo USB o versione
interna ridotta. Non sovrascrivere kernelA/B o il bootloader per fare spazio.

Log della prova: outputs/uboot-readonly-audit.txt.
