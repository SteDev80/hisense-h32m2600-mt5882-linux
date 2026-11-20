# Audio stereo MT5882 ed equalizzatore

Collaudato sulla specifica Hisense H32M2600 del progetto con kernel vendor
`3.10.27 SMP PREEMPT`. Il modulo Hisense verificato limita la struttura ALSA a
un canale, benché il motore MediaTek e il sorgente GPL MT5882 supportino PCM
interleaved a due canali.

## Driver

Il repository non distribuisce `snd-mtk.ko`. Estrarlo dalla propria TV e
verificare che il suo SHA-256 sia:

```text
fc93bbed1bea9bea5f6e5ed83de279c431d87c119005309b0dbb6d3c5a2be044
```

Creare la copia stereo:

```bash
python3 patch-snd-mtk-stereo.py snd-mtk.ko snd-mtk-stereo.ko
```

Lo script rifiuta automaticamente versioni diverse. La copia risultante ha
SHA-256 `16991ef3f4026398a8b3a12bbda1967c892905ac3ecebb7d111c6bcbedfb0fba`.
La modifica cambia esclusivamente `channels_max` da 1 a 2 nella struttura
`snd_pcm_hardware`; `vermagic`, codice DSP e simboli restano invariati.

Conservare sempre `snd-mtk.ko.original-mono`. Aggiornare l'hash controllato da
`h32-audio-start` solo dopo una prova a caldo riuscita. Non usare questo modulo
su altri modelli o kernel.

## Equalizzatore

`h32-dual-eq.c` è un plugin LADSPA dedicato con:

- dieci bande da 31 Hz a 16 kHz per il canale sinistro;
- dieci bande indipendenti per il canale destro;
- livello finale sinistro e destro da -60 a +6 dB;
- master comune da -60 a +6 dB.

Compilazione nel chroot Arch:

```bash
gcc -O3 -fPIC -shared -o /usr/lib/ladspa/h32-dual-eq.so h32-dual-eq.c -lm
```

Servono `alsa-plugins`, `ladspa` e gli header LADSPA. `h32-equalizer` genera la
configurazione ALSA, salva il profilo sulla USB e riavvia il solo ricevitore.
Il pannello si apre da **Start -> Audio PC Wi-Fi -> Equalizzatore**.

## Ripristino

Fermare il ricevitore, ripristinare il modulo originale e l'hash originale in
`h32-audio-start`, quindi riavviare. Non occorre scrivere sull'eMMC: tutti i
file del progetto restano sulla chiavetta USB.
