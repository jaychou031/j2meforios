#include "SoundFontSynth.h"
#define TSF_IMPLEMENTATION
#include "tsf.h"
#include <array>
#include <atomic>
#include <cmath>
#include <mutex>
#include <new>
#include <string>

namespace {
constexpr unsigned rate = 22050, block = 64;
std::mutex bankMutex; // TSF's shared-sample reference counter is not atomic.
tsf *bank = nullptr;
std::string bankPath;
std::atomic<uint64_t> opened{0}, fallback{0}, limited{0}, failures{0}, active{0};

struct Channel {
    tsf *font = nullptr;
    int modulation = 0, reverb = 0, chorus = 0;
};
struct Synth {
    tsf *seed = nullptr;
    std::array<Channel, 16> channels{};
    // Sample data are shared; voices, controllers and effect tails are private.
    std::array<float, (rate / 10) * 2> roomA{};
    std::array<float, (rate / 14) * 2> roomB{};
    std::array<float, (rate / 50) * 2> chorus{};
    unsigned pa = 0, pb = 0, pc = 0;
    uint64_t position = 0;
    ~Synth() {
        std::lock_guard<std::mutex> guard(bankMutex);
        for (auto &c : channels) tsf_close(c.font);
        tsf_close(seed);
    }
    tsf *channel(int index) {
        auto &c = channels[(unsigned)index & 15];
        if (c.font) return c.font;
        {
            std::lock_guard<std::mutex> guard(bankMutex);
            c.font = tsf_copy(seed);
        }
        if (!c.font) { ++failures; return nullptr; }
        tsf_set_output(c.font, TSF_STEREO_INTERLEAVED, rate, -9.0f);
        if (!tsf_set_max_voices(c.font, 64) ||
            !tsf_channel_set_presetnumber(c.font, 0, 0, index == 9) ||
            !tsf_channel_midi_control(c.font, 0, 7, 100)) {
            ++failures;
            std::lock_guard<std::mutex> guard(bankMutex);
            tsf_close(c.font); c.font = nullptr;
        }
        return c.font;
    }
};
}

extern "C" int nj_sf_load_bank(const char *path) {
    std::lock_guard<std::mutex> guard(bankMutex);
    if (path && bank && bankPath == path) return 1;
    tsf *fresh = path ? tsf_load_filename(path) : nullptr;
    if (!fresh) return 0; // Keep a previously valid bank on a failed reload.
    tsf_close(bank); bank = fresh; bankPath = path;
    return 1;
}
extern "C" void *nj_sf_create(void) {
    auto *s = new (std::nothrow) Synth;
    if (s) {
        std::lock_guard<std::mutex> guard(bankMutex);
        s->seed = tsf_copy(bank);
    }
    if (!s || !s->seed) { delete s; ++fallback; return nullptr; }
    ++opened; ++active;
    return s;
}
extern "C" void nj_sf_destroy(void *ptr) {
    if (ptr) { delete static_cast<Synth *>(ptr); --active; }
}
extern "C" void nj_sf_note(void *ptr, int ch, int key, int velocity, int on) {
    auto *f = static_cast<Synth *>(ptr)->channel(ch);
    if (!f) return;
    if (on && velocity) {
        if (!tsf_channel_note_on(f, 0, key & 127, (velocity & 127) / 127.0f)) ++failures;
    } else tsf_channel_note_off(f, 0, key & 127);
}
extern "C" void nj_sf_program(void *ptr, int ch, int presetBank, int program) {
    auto *f = static_cast<Synth *>(ptr)->channel(ch);
    if (!f) return;
    tsf_channel_set_bank(f, 0, presetBank & 16383);
    if (!tsf_channel_set_presetnumber(f, 0, program & 127, ch == 9)) ++failures;
}
extern "C" void nj_sf_control(void *ptr, int ch, int cc, int value) {
    auto *s = static_cast<Synth *>(ptr);
    auto &c = s->channels[(unsigned)ch & 15];
    value &= 127;
    if (cc == 1) c.modulation = value;
    else if (cc == 91) c.reverb = value;
    else if (cc == 93) c.chorus = value;
    else if (auto *f = s->channel(ch)) tsf_channel_midi_control(f, 0, cc, value);
}
extern "C" void nj_sf_pitch(void *ptr, int ch, int wheel, int range) {
    if (auto *f = static_cast<Synth *>(ptr)->channel(ch)) {
        tsf_channel_set_pitchrange(f, 0, (float)range);
        tsf_channel_set_pitchwheel(f, 0, wheel & 16383);
    }
}
extern "C" void nj_sf_render(void *ptr, unsigned char *out, unsigned frames) {
    auto *s = static_cast<Synth *>(ptr);
    while (frames) {
        unsigned n = frames < block ? frames : block;
        float mix[block * 2]{}, room[block * 2]{}, send[block * 2]{};
        for (auto &c : s->channels) {
            if (!c.font) continue;
            // External CC1 vibrato; SF2's own instrument LFO remains in TSF.
            float vibrato = 0.35f * c.modulation / 127.0f *
                (float)std::sin(s->position * (6.283185307179586 * 5.0 / rate));
            tsf_channel_set_tuning(c.font, 0, vibrato);
            float buffer[block * 2];
            tsf_render_float(c.font, buffer, (int)n, 0);
            for (unsigned i = 0; i < n * 2; ++i) {
                mix[i] += buffer[i];
                room[i] += buffer[i] * (c.reverb / 127.0f);
                send[i] += buffer[i] * (c.chorus / 127.0f);
            }
        }
        // Per-channel sends into bounded shared stereo effects. This preserves
        // CC91/93 behavior without relying on TSF's unsupported SF2 generators.
        for (unsigned i = 0; i < n; ++i) {
            unsigned delay = rate / 125 + (unsigned)((1.0 +
                std::sin((s->position + i) * (6.283185307179586 * 0.7 / rate))) * (rate / 250));
            unsigned rp = (s->pc + rate / 50 - delay) % (rate / 50);
            for (unsigned lr = 0; lr < 2; ++lr) {
                unsigned j = i * 2 + lr;
                float a = s->roomA[s->pa * 2 + lr], b = s->roomB[s->pb * 2 + lr];
                s->roomA[s->pa * 2 + lr] = room[j] + a * 0.46f;
                s->roomB[s->pb * 2 + lr] = room[j] + b * 0.37f;
                float wet = s->chorus[rp * 2 + lr];
                s->chorus[s->pc * 2 + lr] = send[j];
                float value = mix[j] + (a + b) * 0.18f + wet * 0.16f;
                float magnitude = std::fabs(value);
                if (!std::isfinite(value)) { value = 0; ++failures; }
                else if (magnitude > 0.9f) {
                    // Continuous soft knee; no hard wrap/clamp at full scale.
                    float over = magnitude - 0.9f;
                    value = std::copysign(0.9f + 0.1f * over / (0.1f + over), value);
                    ++limited;
                }
                int sample = (int)(value * 32767.0f);
                out[j * 2] = (unsigned char)(sample & 255);
                out[j * 2 + 1] = (unsigned char)((sample >> 8) & 255);
            }
            s->pa = (s->pa + 1) % (rate / 10);
            s->pb = (s->pb + 1) % (rate / 14);
            s->pc = (s->pc + 1) % (rate / 50);
        }
        s->position += n; frames -= n; out += n * 4;
    }
}
extern "C" nj_sf_stats nj_sf_get_stats(void) {
    return {opened.load(), fallback.load(), limited.load(), failures.load(), active.load()};
}
