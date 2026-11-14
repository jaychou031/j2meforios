# Keep pinned upstream files untouched. Compile generated translation units
# with explicit, checked compatibility additions.
function(j2me_apply_core_compatibility target core)
  set(original "${core}/src/midp/nj_lib_lcdui.c")
  file(READ "${original}" source)
  set(anchor "    M(\"getKeyName\",        \"(I)Ljava/lang/String;\", NJ_ACC_STATIC | NJ_ACC_PUBLIC),")
  string(FIND "${source}" "${anchor}" position)
  if(position EQUAL -1)
    message(FATAL_ERROR "Pinned Canvas key-method patch anchor changed")
  endif()
  set(addition "${anchor}
    /* iOS compatibility: inherited interface calls need instance entries.
     * Keep the original static entries first for legacy direct invocations. */
    M(\"getGameAction\",     \"(I)I\", NJ_ACC_PUBLIC),
    M(\"getKeyCode\",        \"(I)I\", NJ_ACC_PUBLIC),
    M(\"getKeyName\",        \"(I)Ljava/lang/String;\", NJ_ACC_PUBLIC),")
  string(REPLACE "${anchor}" "${addition}" patched "${source}")
  set(generated "${CMAKE_CURRENT_BINARY_DIR}/compat/nj_lib_lcdui.c")
  file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/compat")
  # configure_file avoids rebuilding the large unit when contents are unchanged.
  file(WRITE "${generated}.in" "${patched}")
  configure_file("${generated}.in" "${generated}" COPYONLY)
  get_target_property(sources ${target} SOURCES)
  list(FIND sources "src/midp/nj_lib_lcdui.c" index)
  if(index EQUAL -1)
    message(FATAL_ERROR "Pinned core source list changed")
  endif()
  list(REMOVE_ITEM sources "src/midp/nj_lib_lcdui.c")
  set_property(TARGET ${target} PROPERTY SOURCES "${sources}")
  target_sources(${target} PRIVATE "${generated}")
  target_include_directories(${target} PRIVATE "${core}/src/midp")

  # The core's Thread.yield is a no-op. Fast yield-driven game loops execute
  # thousands of times per millisecond; their integer moving-average delta
  # rounds to zero (City Bloxx), freezing timers despite a live Java thread.
  # Cooperatively park only the calling Java thread for one clock tick.
  file(READ "${core}/src/core/nj_lib_thread.c" thread_source)
  set(yield_original "NJFN(thread_yield)
{
    /* Cooperate: the scheduler picks the next runnable thread at the next
     * quantum boundary, which is at most NJ_SCHED_QUANTUM bytecodes away. */
    NJ_UNUSED(args);
    return NJ_OK;
}")
  string(FIND "${thread_source}" "${yield_original}" yield_position)
  if(yield_position EQUAL -1)
    message(FATAL_ERROR "Pinned Thread.yield patch anchor changed")
  endif()
  set(yield_replacement "NJFN(thread_yield)
{
    NJ_UNUSED(args);
    NJ_UNUSED(ret);
    /* One VM clock tick; never sleep the host or change the game clock. */
    return nj_thread_sleep(vm, th, 1);
}")
  string(REPLACE "${yield_original}" "${yield_replacement}" thread_patched "${thread_source}")
  set(thread_generated "${CMAKE_CURRENT_BINARY_DIR}/compat/nj_lib_thread.c")
  file(WRITE "${thread_generated}.in" "${thread_patched}")
  configure_file("${thread_generated}.in" "${thread_generated}" COPYONLY)
  get_target_property(sources ${target} SOURCES)
  list(FIND sources "src/core/nj_lib_thread.c" index)
  if(index EQUAL -1)
    message(FATAL_ERROR "Pinned thread source list changed")
  endif()
  list(REMOVE_ITEM sources "src/core/nj_lib_thread.c")
  set_property(TARGET ${target} PROPERTY SOURCES "${sources}")
  target_sources(${target} PRIVATE "${thread_generated}")
  target_include_directories(${target} PRIVATE "${core}/src/core")

  # A linked headless backend does not make an iOS userdata object headless.
  # The original stats path casts that object to the headless struct, reading
  # unrelated memory and printing bogus PCM/file counts on an embedded port.
  file(READ "${core}/src/runner/nj_run.c" runner_source)
  set(stats_original "            if (obs_file_opens(&port) >= 0 ||
                obs_tone_calls(&port) >= 0) {")
  string(FIND "${runner_source}" "${stats_original}" stats_position)
  if(stats_position EQUAL -1)
    message(FATAL_ERROR "Pinned port observation patch anchor changed")
  endif()
  set(stats_replacement "            if (port.name && strcmp(port.name, \"headless\") == 0 &&
                (obs_file_opens(&port) >= 0 || obs_tone_calls(&port) >= 0)) {")
  string(REPLACE "${stats_original}" "${stats_replacement}" runner_patched "${runner_source}")
  set(runner_generated "${CMAKE_CURRENT_BINARY_DIR}/compat/nj_run.c")
  file(WRITE "${runner_generated}.in" "${runner_patched}")
  configure_file("${runner_generated}.in" "${runner_generated}" COPYONLY)
  get_target_property(sources ${target} SOURCES)
  list(FIND sources "src/runner/nj_run.c" index)
  if(index EQUAL -1)
    message(FATAL_ERROR "Pinned runner source list changed")
  endif()
  list(REMOVE_ITEM sources "src/runner/nj_run.c")
  set_property(TARGET ${target} PROPERTY SOURCES "${sources}")
  target_sources(${target} PRIVATE "${runner_generated}")
  target_include_directories(${target} PRIVATE "${core}/src/port/posix")
  include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/SoundFont.cmake")
  j2me_apply_soundfont(${target} "${core}")
endfunction()
