# Validation

controls_test.cpp checks viewport geometry, multi-finger key transitions,
gap-free hit regions, boundary jitter, sliding between keys and cancellation.
test_packaging.py checks archive paths, permissions and rejection of incompatible
Mach-O targets. These tests do not replace Xcode compilation or iPhone testing.

input_queue_test.cpp checks rapid taps, multi-key batches, pointer coalescing,
preserved release edges and latency counters. storage_test.mm exercises real
Foundation file operations in an isolated temporary directory on the Mac CI
runner; it checks sibling-game/shared-file preservation and path rejection.
test_icons.py validates every iPhone icon slot, dimensions and opaque RGB PNGs.

canvas_fixture.py generates our own small MIDlet without a JDK. Run it through
scripts/smoke-canvas.py against the patched host core from tests/core. All nine
interface/virtual/static key-query results must match. No user games are
redistributed by these fixtures or source packages.

yield_fixture.py / scripts/smoke-yield.py execute 96 explicit Thread.yield
calls through the real interpreter, checking clock progress and native resume.
pcm_buffer_test.cpp checks exact mono/stereo sample order at 8/22.05/44.1/48/192
kHz, short writes, wrapping, in-flight accounting, silence only when empty,
and the simple tone envelope. AudioQueue/device behavior still needs Apple
compilation and phone testing; portable tests do not emulate the audio driver.

port_stats_test.c runs the demo through the same backend twice, with headless
and custom port names. VM counters must appear in both cases, while headless
userdata observations must appear only for the headless port. Run in a build
temporary directory to keep demo persistence out of the source tree.

soundfont_test.cpp links the actual patched core and the actual bundled SF2.
It tests fallback, stream isolation, seek/restart, tempo/rate, live volume,
pan, pitch bend, sustain, program/drum differences, effects and cleanup.
render_midi.cpp renders a user-provided MIDI to optional WAV plus numeric stats;
soundfont_runner.cpp runs an actual MIDlet with the loaded bank and checks that
all stream instances close. User game files are not committed or packaged.
verify-audio.py checks pinned dependencies; verify-app-audio.py checks the
actual device bundle before packaging. None of these checks replace device audio.
