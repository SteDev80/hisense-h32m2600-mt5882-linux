Hisense H32M2600 / MT5882 - avvio Linux non distruttivo
======================================================

La chiavetta contiene:

  Partizione 1, FAT32, etichetta MT5882BOOT
    uInitrd-h32m2600-buildroot  initramfs Buildroot in formato U-Boot legacy
    rootfs.cpio.gz              initramfs grezzo
    boot-original-usb.txt       comandi di prova per il kernel originale

  Partizione 2, ext4, etichetta H32ROOT
    root filesystem Buildroot minimale con BusyBox e console ttyMT0

REGOLE DI SICUREZZA
-------------------

Non eseguire saveenv, mmc write, erase, format o update da U-Boot.
I setenv proposti sono solo in RAM e spariscono al riavvio.
Il rootfs Buildroot non contiene comandi automatici che montano la eMMC.

Prima prova consigliata
-----------------------

Al prompt "mt5882 #":

  usb start
  usb start
  fatls usb 0:1 /
  setenv bootargs 'console=ttyMT0,115200n1 earlyprintk loglevel=8 root=/dev/sda2 rootwait rootfstype=ext4 ro init=/sbin/init'
  eboot.lzo kernelA

La seconda esecuzione di "usb start" e' intenzionale: questa Lexar viene spesso
rilevata solo al secondo tentativo. Non usare "rootfsA" nel comando eboot.lzo,
perche' quel parametro potrebbe ripristinare il rootfs interno.

Se "eboot.lzo kernelA" richiede obbligatoriamente un secondo argomento, fermarsi
e acquisire l'output di:

  help eboot.lzo

Prova initramfs separato (solo se il kernel originale e' caricabile con bootm)
----------------------------------------------------------------------------

  usb start
  usb start
  fatload usb 0:1 0x03000000 uInitrd-h32m2600-buildroot
  setenv bootargs 'console=ttyMT0,115200n1 earlyprintk rdinit=/sbin/init loglevel=8'
  bootm <indirizzo-kernel> 0x03000000

Non inventare <indirizzo-kernel>: va ricavato dal caricamento reale del kernel.

