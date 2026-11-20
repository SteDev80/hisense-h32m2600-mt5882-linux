#include <alsa/asoundlib.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
int main(void) {
    snd_pcm_t *p=0; int rc=snd_pcm_open(&p,"hw:0,0",SND_PCM_STREAM_PLAYBACK,0);
    if(rc<0){fprintf(stderr,"open: %s\n",snd_strerror(rc));return 2;}
    rc=snd_pcm_set_params(p,SND_PCM_FORMAT_S16_LE,SND_PCM_ACCESS_RW_INTERLEAVED,2,48000,1,100000);
    if(rc<0){fprintf(stderr,"stereo params: %s\n",snd_strerror(rc));return 3;}
    puts("HARDWARE_STEREO_ACCEPTED"); fflush(stdout);
    int16_t b[480];
    for(int side=0;side<2;side++) {
        puts(side?"RIGHT_4_SECONDS":"LEFT_4_SECONDS"); fflush(stdout);
        for(int k=0;k<800;k++) { for(int i=0;i<240;i++){double t=(k*240+i)/48000.0;int16_t s=(int16_t)(sin(2*M_PI*(side?880:440)*t)*5000);b[2*i]=side?0:s;b[2*i+1]=side?s:0;} rc=snd_pcm_writei(p,b,240);if(rc<0)snd_pcm_recover(p,rc,1);}
        snd_pcm_drop(p); snd_pcm_prepare(p); sleep(1);
    }
    snd_pcm_drop(p); snd_pcm_close(p); return 0;
}
