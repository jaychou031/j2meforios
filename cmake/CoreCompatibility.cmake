# Keep pinned upstream files untouched. Compile a generated copy of this one
# translation unit with an explicit, checked compatibility addition.
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
endfunction()
