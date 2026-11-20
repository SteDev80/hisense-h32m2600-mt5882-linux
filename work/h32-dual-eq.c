#include <ladspa.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BANDS 10
#define PORTS 27

typedef struct { double b0,b1,b2,a1,a2,z1,z2,last_gain; } Biquad;
typedef struct {
    LADSPA_Data *gain[2][BANDS], *level[2], *master, *in[2], *out[2];
    Biquad q[2][BANDS];
    unsigned long rate;
} DualEq;

static const double freq[BANDS] = {31,63,125,250,500,1000,2000,4000,8000,16000};

static void coefficients(Biquad *q, double gain, double f, double rate) {
    double A = pow(10.0, gain / 40.0), w = 2.0 * M_PI * f / rate;
    double alpha = sin(w) / (2.0 * 1.20), c = cos(w);
    double a0 = 1.0 + alpha / A;
    q->b0 = (1.0 + alpha * A) / a0;
    q->b1 = (-2.0 * c) / a0;
    q->b2 = (1.0 - alpha * A) / a0;
    q->a1 = (-2.0 * c) / a0;
    q->a2 = (1.0 - alpha / A) / a0;
    q->last_gain = gain;
}

static LADSPA_Handle instantiate(const LADSPA_Descriptor *d, unsigned long rate) {
    (void)d; DualEq *e = calloc(1, sizeof(*e)); if (e) e->rate = rate; return e;
}
static void connect_port(LADSPA_Handle h, unsigned long p, LADSPA_Data *data) {
    DualEq *e = h;
    if (p < 10) e->gain[0][p] = data;
    else if (p < 20) e->gain[1][p-10] = data;
    else if (p == 20) e->level[0] = data;
    else if (p == 21) e->level[1] = data;
    else if (p == 22) e->master = data;
    else if (p == 23) e->in[0] = data;
    else if (p == 24) e->in[1] = data;
    else if (p == 25) e->out[0] = data;
    else if (p == 26) e->out[1] = data;
}
static void activate(LADSPA_Handle h) {
    DualEq *e = h; memset(e->q, 0, sizeof(e->q));
    for (int c=0;c<2;c++) for (int b=0;b<BANDS;b++) e->q[c][b].last_gain=999;
}
static void run(LADSPA_Handle h, unsigned long n) {
    DualEq *e = h;
    for (int c=0;c<2;c++) for (int b=0;b<BANDS;b++) {
        double g = e->gain[c][b] ? *e->gain[c][b] : 0;
        if (g != e->q[c][b].last_gain) coefficients(&e->q[c][b], g, freq[b], e->rate);
    }
    for (unsigned long i=0;i<n;i++) for (int c=0;c<2;c++) {
        double x = e->in[c][i];
        for (int b=0;b<BANDS;b++) {
            Biquad *q=&e->q[c][b]; double y=q->b0*x+q->z1;
            q->z1=q->b1*x-q->a1*y+q->z2; q->z2=q->b2*x-q->a2*y; x=y;
        }
        double level = (e->level[c] ? *e->level[c] : 0.0) + (e->master ? *e->master : 0.0);
        x *= (level <= -60.0) ? 0.0 : pow(10.0, level / 20.0);
        if (x>1.0) x=1.0; else if (x<-1.0) x=-1.0;
        e->out[c][i]=(LADSPA_Data)x;
    }
}
static void cleanup(LADSPA_Handle h) { free(h); }

static LADSPA_Descriptor desc;
static LADSPA_PortDescriptor ports[PORTS];
static LADSPA_PortRangeHint hints[PORTS];
static const char *names[PORTS];
static char gain_names[20][24];

__attribute__((constructor)) static void init_desc(void) {
    static const char *bn[BANDS]={"31 Hz","63 Hz","125 Hz","250 Hz","500 Hz","1 kHz","2 kHz","4 kHz","8 kHz","16 kHz"};
    memset(&desc,0,sizeof(desc)); desc.UniqueID=41001; desc.Label="H32DualEq";
    desc.Name="H32 Dual Speaker 10-band EQ"; desc.Maker="Hisense H32 Linux project"; desc.Copyright="GPLv3";
    desc.PortCount=PORTS; desc.PortDescriptors=ports; desc.PortNames=names; desc.PortRangeHints=hints;
    for(int c=0;c<2;c++) for(int b=0;b<BANDS;b++) { int p=c*10+b;
        snprintf(gain_names[p],sizeof(gain_names[p]),"%s %s",c?"Right":"Left",bn[b]); names[p]=gain_names[p];
        ports[p]=LADSPA_PORT_INPUT|LADSPA_PORT_CONTROL; hints[p].HintDescriptor=LADSPA_HINT_BOUNDED_BELOW|LADSPA_HINT_BOUNDED_ABOVE|LADSPA_HINT_DEFAULT_0; hints[p].LowerBound=-12; hints[p].UpperBound=12;
    }
    names[20]="Left output level dB"; names[21]="Right output level dB";
    ports[20]=ports[21]=LADSPA_PORT_INPUT|LADSPA_PORT_CONTROL;
    hints[20].HintDescriptor=hints[21].HintDescriptor=LADSPA_HINT_BOUNDED_BELOW|LADSPA_HINT_BOUNDED_ABOVE|LADSPA_HINT_DEFAULT_0;
    hints[20].LowerBound=hints[21].LowerBound=-60; hints[20].UpperBound=hints[21].UpperBound=6;
    names[22]="Master output level dB"; ports[22]=LADSPA_PORT_INPUT|LADSPA_PORT_CONTROL;
    hints[22].HintDescriptor=LADSPA_HINT_BOUNDED_BELOW|LADSPA_HINT_BOUNDED_ABOVE|LADSPA_HINT_DEFAULT_0;
    hints[22].LowerBound=-60; hints[22].UpperBound=6;
    names[23]="Left input"; names[24]="Right input"; names[25]="Left output"; names[26]="Right output";
    ports[23]=ports[24]=LADSPA_PORT_INPUT|LADSPA_PORT_AUDIO; ports[25]=ports[26]=LADSPA_PORT_OUTPUT|LADSPA_PORT_AUDIO;
    desc.instantiate=instantiate; desc.connect_port=connect_port; desc.activate=activate; desc.run=run; desc.cleanup=cleanup;
}

const LADSPA_Descriptor *ladspa_descriptor(unsigned long index) { return index==0 ? &desc : NULL; }
