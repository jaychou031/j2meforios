/* Included after nj_internal.h. Only the iOS outer frame pacer uses this.
 * Never sleep over runnable Java work, a timer, or the next display deadline. */
static nj_s8 ios_pacer_idle_ms(nj_vm *vm, nj_s8 now, nj_s8 limit)
{
    nj_u2 i;
    for (i = 0; i < vm->nthreads; ++i) {
        nj_thread *t = vm->threads[i];
        nj_s8 due = 0;
        if (!t || t->state == NJ_THREAD_DEAD || t->state == NJ_THREAD_NEW) continue;
        if (t->state == NJ_THREAD_SLEEPING) due = t->wake_at_ms;
        else if (t->state == NJ_THREAD_WAITING) {
            if (t->wait_ready) return 0; /* scheduler must try the monitor */
            due = t->wait_deadline;
            if (!due) continue;
        } else if (t->state == NJ_THREAD_RUNNING && t->nframes && !t->in_c_call) {
            return 0;
        }
        else continue; /* blocked or owned by the current native C stack */
        if (due <= now) return 0;
        if (due - now < limit) limit = due - now;
    }
    return limit;
}
