#include "nj_internal.h"
#include "IdlePacer.h"
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
int main(void) {
    nj_vm *vm=(nj_vm*)calloc(1,sizeof(nj_vm));
    nj_thread *t=(nj_thread*)calloc(1,sizeof(nj_thread));
    assert(vm && t); vm->nthreads=1; vm->threads[0]=t;
    t->state=NJ_THREAD_RUNNING; t->in_c_call=1; t->nframes=1;
    assert(ios_pacer_idle_ms(vm,100,16)==16); /* outer native owns this stack */
    t->in_c_call=0; assert(ios_pacer_idle_ms(vm,100,16)==0);
    t->nframes=0; assert(ios_pacer_idle_ms(vm,100,16)==16); t->nframes=1;
    t->state=NJ_THREAD_SLEEPING; t->wake_at_ms=107;
    assert(ios_pacer_idle_ms(vm,100,16)==7);
    assert(ios_pacer_idle_ms(vm,100,4)==4);
    assert(ios_pacer_idle_ms(vm,107,16)==0);
    t->state=NJ_THREAD_WAITING; t->wait_deadline=105;
    assert(ios_pacer_idle_ms(vm,100,16)==5);
    t->wait_deadline=0; assert(ios_pacer_idle_ms(vm,100,16)==16);
    t->wait_ready=1; assert(ios_pacer_idle_ms(vm,100,16)==0);
    t->state=NJ_THREAD_BLOCKED; assert(ios_pacer_idle_ms(vm,100,16)==16);
    t->state=NJ_THREAD_DEAD; assert(ios_pacer_idle_ms(vm,100,16)==16);
    free(t);free(vm);puts("Idle pacer: runnable work, sleeps, timed waits, parked stacks and frame deadlines passed.");
    return 0;
}
