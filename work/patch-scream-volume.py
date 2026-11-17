#!/usr/bin/python3
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
needle = "int alsa_output_send(receiver_data_t *data)\n{\n"
replacement = needle + '''  /* H32 TV software gain. Quadratic response gives useful quiet levels. */
  int h32_volume = 10;
  FILE *h32_volume_file = fopen("/run/h32-scream-volume", "r");
  if (h32_volume_file) {
    if (fscanf(h32_volume_file, "%d", &h32_volume) != 1) h32_volume = 10;
    fclose(h32_volume_file);
  }
  if (h32_volume < 0) h32_volume = 0;
  if (h32_volume > 100) h32_volume = 100;
  if (data->format.sample_size == 16) {
    int h32_gain = h32_volume * h32_volume;
    for (unsigned int offset = 0; offset + 1 < data->audio_size; offset += 2) {
      int16_t sample = (int16_t)((uint16_t)data->audio[offset] |
                                 ((uint16_t)data->audio[offset + 1] << 8));
      int scaled = ((int)sample * h32_gain) / 10000;
      data->audio[offset] = (unsigned char)(scaled & 0xff);
      data->audio[offset + 1] = (unsigned char)((scaled >> 8) & 0xff);
    }
  }

'''
if 'H32 TV software gain' not in text:
    if needle not in text:
        raise SystemExit('alsa_output_send context not found')
    text = text.replace(needle, replacement, 1)
path.write_text(text)
print('SCREAM_VOLUME_PATCHED')
