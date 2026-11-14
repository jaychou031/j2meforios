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
