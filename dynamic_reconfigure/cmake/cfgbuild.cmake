# Return a list of all cfg/.cfg files
set(GENERATED_CFG_FILES "")

macro(add_generated_cfg)
  list(APPEND GENERATED_CFG_FILES ${ARGV})
endmacro(add_generated_cfg)

macro(get_cfgs cfgvar)
  file(GLOB _cfg_files RELATIVE "${PROJECT_SOURCE_DIR}/cfg" "${PROJECT_SOURCE_DIR}/cfg/*.cfg")
  set(${cfgvar} ${GENERATED_CFG_FILES})
  # Loop over each .cfg file, establishing a rule to compile it
  foreach(_cfg ${_cfg_files})
    # Make sure we didn't get a bogus match (e.g., .#Foo.cfg, which Emacs
    # might create as a temporary file).  the file()
    # command doesn't take a regular expression, unfortunately.
    if(${_cfg} MATCHES "^[^\\.].*\\.cfg$")
      list(APPEND ${cfgvar} ${_cfg})
    endif(${_cfg} MATCHES "^[^\\.].*\\.cfg$")
  endforeach(_cfg)
endmacro(get_cfgs)

add_custom_target(rospack_gencfg ALL)
add_dependencies(rospack_genmsg_libexe rospack_gencfg)

macro(gencfg)
  add_custom_target(rospack_gencfg_real ALL)
  add_dependencies(rospack_gencfg_real rospack_gencfg)
  include_directories(${PROJECT_SOURCE_DIR}/cfg/cpp)
endmacro(gencfg)

rosbuild_find_ros_package(dynamic_reconfigure)

macro(gencfg_cpp)
  get_cfgs(_cfglist)
  set(_autogen "")
  foreach(_cfg ${_cfglist})
    message("MSG: gencfg_cpp on:" ${_cfg})
    # Construct the path to the .cfg file
    set(_input ${PROJECT_SOURCE_DIR}/cfg/${_cfg})
  
    rosbuild_gendeps(${PROJECT_NAME} ${_cfg})

    # The .cfg file is its own generator.
    set(gencfg_cpp_exe "")
    set(gencfg_build_files 
      ${dynamic_reconfigure_PACKAGE_PATH}/templates/ConfigType.py
      ${dynamic_reconfigure_PACKAGE_PATH}/templates/ConfigType.h
      ${dynamic_reconfigure_PACKAGE_PATH}/src/dynamic_reconfigure/parameter_generator.py)

    string(REPLACE ".cfg" "" _cfg_bare ${_cfg})

    set(_output_cpp ${PROJECT_SOURCE_DIR}/cfg/cpp/${PROJECT_NAME}/${_cfg_bare}Config.h)
    set(_output_dox ${PROJECT_SOURCE_DIR}/dox/${_cfg_bare}Config.dox)
    set(_output_usage ${PROJECT_SOURCE_DIR}/dox/${_cfg_bare}Config-usage.dox)
    set(_output_py ${PROJECT_SOURCE_DIR}/src/${PROJECT_NAME}/cfg/${_cfg_bare}Config.py)

    # Add the rule to build the .h the .cfg and the .msg
    # FIXME Horrible hack. Can't get CMAKE to add dependencies for anything
    # but the first output in add_custom_command.
    add_custom_command(OUTPUT ${_output_cpp} ${_output_dox} ${_output_usage} ${_output_py}
                       COMMAND ${gencfg_cpp_exe} ${_input}
                       DEPENDS ${_input} ${gencfg_cpp_exe} ${ROS_MANIFEST_LIST} ${gencfg_build_files} ${gencfg_extra_deps})
    list(APPEND _autogen ${_output_cpp} ${_output_msg} ${_output_getsrv} ${_output_setsrv} 
      ${_output_dox} ${_output_usage} ${_output_py})
  endforeach(_cfg)
  # Create a target that depends on the union of all the autogenerated
  # files
  add_custom_target(ROSBUILD_gencfg_cpp DEPENDS ${_autogen})
  # Add our target to the top-level gencfg target, which will be fired if
  # the user calls gencfg()
  add_dependencies(rospack_gencfg ROSBUILD_gencfg_cpp)
endmacro(gencfg_cpp)

# Call the macro we just defined.
gencfg_cpp()
