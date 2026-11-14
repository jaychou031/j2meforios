/* Included only inside the generated pinned nj_midi.c, after its parser and
 * live-event merge helpers. Keep the core's timing and MIDIControl queues. */
static void sf_apply_ctl(nj_midi_stream *s, const mid_ctl *ctl)
{
    nj_u4 ch = ctl->chan, a = ctl->a;
    switch (ctl->kind) {
    case MID_CTL_BEND: s->bend_now[ch] = a; break;
    case MID_CTL_RANGE: s->range_now[ch] = a; break;
    case MID_CTL_PEDAL: s->pedal_now[ch] = a >= 64u;
        nj_sf_control(s->sf, ch, 64, a); break;
    case MID_CTL_MOD: s->mod_now[ch] = a;
        nj_sf_control(s->sf, ch, 1, a); break;
    case MID_CTL_REVERB: s->rev_now[ch] = a;
        nj_sf_control(s->sf, ch, 91, a); break;
    case MID_CTL_CHORUS: s->chorus_now[ch] = a;
        nj_sf_control(s->sf, ch, 93, a); break;
    case MID_CTL_PAN: s->pan_now[ch] = a;
        nj_sf_control(s->sf, ch, 10, a); break;
    case MID_CTL_VOL: s->vol_now[ch] = a;
        nj_sf_control(s->sf, ch, 7, a); break;
    case MID_CTL_EXPR: s->expr_now[ch] = a;
        nj_sf_control(s->sf, ch, 11, a); break;
    case MID_CTL_PROG: s->prog_now[ch] = a;
        nj_sf_program(s->sf, ch, s->bank_now[ch], a); break;
    case MID_CTL_BANK: s->bank_now[ch] = a;
        /* Bank select affects the next program change. */
        break;
    }
    if (ctl->kind == MID_CTL_BEND || ctl->kind == MID_CTL_RANGE)
        nj_sf_pitch(s->sf, ch, s->bend_now[ch], s->range_now[ch]);
}

static nj_u4 sf_stream_pull(nj_midi_stream *s, nj_u1 *out, nj_u4 want)
{
    nj_u4 n = 0u;
    if (s->nlive) mid_settle_notes(s);
    while (n < want && s->i < s->frames) {
        nj_u4 end = s->frames;
        /* Match the core: controllers before notes at equal timestamps. */
        while (s->cev < s->song.nctls) {
            const mid_ctl *ctl = &s->song.ctls[s->cev];
            nj_u4 at = mid_sample_rate(s, ctl->tick);
            if (at > s->i) { if (at < end) end = at; break; }
            sf_apply_ctl(s, ctl);
            s->cev++;
        }
        while (s->ev < s->song.nnotes) {
            const mid_note *note = &s->song.notes[s->ev];
            nj_u4 at = mid_sample_rate(s, note->tick);
            if (at > s->i) { if (at < end) end = at; break; }
            nj_sf_note(s->sf, note->chan, note->note, note->velocity, note->on);
            s->ev++;
        }
        {
            nj_u4 count = end - s->i;
            if (count > want - n) count = want - n;
            if (count > 64u) count = 64u;
            nj_sf_render(s->sf, out + n * 4u, count);
            /* A sampled instrument may have a longer release than the old
             * oscillator. Taper the final 5 ms instead of ending on a step. */
            {
                nj_u4 j;
                const nj_u4 fade = NJ_MIDI_RATE / 200u;
                for (j = 0; j < count; ++j) {
                    nj_u4 left = s->frames - (s->i + j) - 1u;
                    if (left < fade) {
                        nj_u4 c;
                        for (c = 0; c < 2u; ++c) {
                            nj_u1 *p = out + (n + j) * 4u + c * 2u;
                            nj_s4 value = (nj_s2)((nj_u4)p[0] | ((nj_u4)p[1] << 8));
                            value = value * (nj_s4)left / (nj_s4)fade;
                            p[0] = (nj_u1)(value & 255); p[1] = (nj_u1)((value >> 8) & 255);
                        }
                    }
                }
            }
            n += count; s->i += count;
        }
    }
    /* Live events need the current playhead, including gaps between notes. */
    s->tick_now = mid_tick_at(s, s->i);
    return n;
}
