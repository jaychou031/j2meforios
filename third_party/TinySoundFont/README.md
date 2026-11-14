# TinySoundFont provenance

Vendored unchanged from the user-provided TinySoundFont-main.zip on 2026-11-14.
The header identifies itself as v0.9. Exact header, license and original ZIP
SHA-256 hashes are in ../../audio-dependencies.lock.json.

Source: https://github.com/schellingb/TinySoundFont
License: MIT; original LICENSE and the notice in tsf.h are retained.

Only the synthesizer is used. The existing pinned nano_j2me MIDI parser remains
in use; TinyMidiLoader is not compiled or vendored. All adaptations live in
../../ios/SoundFontSynth.cpp, SoundFontPull.inc and ../../cmake/SoundFont.cmake.
The GeneralUser bank and its separate original license are in ../../ios/SoundFont.
