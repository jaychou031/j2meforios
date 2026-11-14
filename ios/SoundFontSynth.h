#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Called on the VM worker, before opening any MIDI streams. */
int nj_sf_load_bank(const char *path);
void *nj_sf_create(void);
void nj_sf_destroy(void *synth);
void nj_sf_note(void *synth, int channel, int key, int velocity, int on);
void nj_sf_program(void *synth, int channel, int bank, int program);
void nj_sf_control(void *synth, int channel, int controller, int value);
void nj_sf_pitch(void *synth, int channel, int wheel, int range);
void nj_sf_render(void *synth, unsigned char *stereo_pcm, unsigned frames);
typedef struct nj_sf_stats {
    uint64_t opened, fallback, limited_samples, errors, active;
} nj_sf_stats;
nj_sf_stats nj_sf_get_stats(void);
#ifdef __cplusplus
}
#endif
