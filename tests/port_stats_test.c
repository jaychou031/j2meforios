/* A custom port must not be inspected as headless just because it is linked. */
#include "nj2me/nj.h"
#include <stdio.h>
#include <string.h>

static int saw_stats, saw_observed;
static void capture(void *ud, int level, const char *msg)
{
    (void)ud;
    (void)level;
    if (strstr(msg, "stats: frames=")) saw_stats = 1;
    if (strstr(msg, "observed: threads=")) saw_observed = 1;
}

int main(int argc, char **argv)
{
    int custom;
    if (argc != 2) return 2;
    for (custom = 0; custom < 2; ++custom) {
        nj_port port;
        nj_run_opts opts = {0};
        int result;
        if (nj_port_headless(&port) != NJ_OK) return 3;
        /* Keep valid backend storage; only the declared port identity differs. */
        if (custom) port.name = "ios-test";
        port.log = capture;
        opts.jar_path = argv[1];
        opts.stats = 1;
        opts.run_frames = 2;
        opts.heap_bytes = 32u * 1024u * 1024u;
        saw_stats = saw_observed = 0;
        result = nj_run(&port, &opts);
        nj_port_shutdown(&port);
        if (result || !saw_stats || saw_observed != !custom) {
            fprintf(stderr, "custom=%d result=%d stats=%d observed=%d\n",
                    custom, result, saw_stats, saw_observed);
            return 1;
        }
    }
    puts("Port stats: headless observations retained; custom port excluded.");
    return 0;
}
