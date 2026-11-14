function(j2me_apply_soundfont target core)
  get_filename_component(root "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/.." ABSOLUTE)
  file(READ "${core}/src/midp/nj_midi.c" midi)
  # Fail closed when updating the pinned core: these edits depend on its private
  # stream structure. Parsing, rate/tempo, live events and seek remain upstream.
  macro(sf_replace before after)
    string(FIND "${midi}" "${before}" at)
    if(at EQUAL -1)
      message(FATAL_ERROR "Pinned SoundFont integration anchor changed: ${before}")
    endif()
    string(REPLACE "${before}" "${after}" midi "${midi}")
  endmacro()
  sf_replace("#include \"nj_midi.h\"" "#include \"nj_midi.h\"\n#include \"SoundFontSynth.h\"")
  sf_replace("typedef struct nj_midi_stream {" "typedef struct nj_midi_stream {\n    void *sf;")
  sf_replace("    s->mem.free(s->mem.ud, s->song.notes);" "    nj_sf_destroy(s->sf); s->sf = NULL;\n    s->mem.free(s->mem.ud, s->song.notes);")
  # init failure is subsequently handled by mid_stream_drop: do not free the
  # parser arrays twice on a valid MIDI containing only controller events.
  sf_replace("        return 0;            /* nothing to play: let the caller stay silent */"
             "        s->song.notes = NULL; s->song.ctls = NULL;\n        return 0;            /* nothing to play: let the caller stay silent */")
  sf_replace("    return s;\n}\n\nnj_u1 *nj_midi_render_ex"
             "    s->sf = nj_sf_create();\n    if (s->sf) s->chans = 2u;\n    return s;\n}\n\nnj_u1 *nj_midi_render_ex")
  sf_replace("nj_u4 nj_midi_stream_pull(nj_midi_stream *s, nj_u1 *out, nj_u4 want)"
             "#include \"SoundFontPull.inc\"\n\nnj_u4 nj_midi_stream_pull(nj_midi_stream *s, nj_u1 *out, nj_u4 want)")
  sf_replace("    i = s->i;\n    for (n = 0u; n < want"
             "    if (s->sf) return sf_stream_pull(s, out, want);\n    i = s->i;\n    for (n = 0u; n < want")
  set(generated "${CMAKE_CURRENT_BINARY_DIR}/compat/nj_midi.c")
  file(WRITE "${generated}.in" "${midi}")
  configure_file("${generated}.in" "${generated}" COPYONLY)
  get_target_property(sources ${target} SOURCES)
  list(FIND sources "src/midp/nj_midi.c" index)
  if(index EQUAL -1)
    message(FATAL_ERROR "Pinned MIDI source list changed")
  endif()
  list(REMOVE_ITEM sources "src/midp/nj_midi.c")
  set_property(TARGET ${target} PROPERTY SOURCES "${sources}")
  target_sources(${target} PRIVATE "${generated}" "${root}/ios/SoundFontSynth.cpp")
  target_include_directories(${target} PRIVATE "${root}/ios" "${root}/third_party/TinySoundFont")
  target_compile_features(${target} PRIVATE cxx_std_17)
endfunction()
