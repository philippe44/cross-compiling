set(_CONFIG_ITEMS addons alac faad flac mad ogg opus opusfile opusurl shine soxr utf8 vorbis vorbisenc vorbisfile)
set(_CONFIG_DIR ${CMAKE_CURRENT_LIST_DIR}/targets)

# set if there is a group library that aggregates them all
set(_CONFIG_GROUP codecs)

# choose one or the other
#set(_CONFIG_INC_PATH "${_CONFIG_DIR}/${HOST}/${PLATFORM}/include")
set(_CONFIG_INC_PATH "${_CONFIG_DIR}/include")

message(STATUS "Using package ${CMAKE_FIND_PACKAGE_NAME} in ${_CONFIG_DIR}/${HOST}/${PLATFORM}")

if(MSVC)
set(_CONFIG_EXT lib)
else()
set(_CONFIG_EXT a)
endif()

# Protect against multiple inclusion, which would fail when already imported targets are added once more.
set(_targetsDefined)
set(_targetsNotDefined)
set(_expectedTargets)
foreach(_expectedTarget ${_CONFIG_ITEMS})
  set(_expectedTarget ${CMAKE_FIND_PACKAGE_NAME}::${_expectedTarget})
  list(APPEND _expectedTargets ${_expectedTarget})
  if(NOT TARGET ${_expectedTarget})
    list(APPEND _targetsNotDefined ${_expectedTarget})
  endif()
  if(TARGET ${_expectedTarget})
    list(APPEND _targetsDefined ${_expectedTarget})
  endif()
endforeach()
if("${_targetsDefined}" STREQUAL "${_expectedTargets}")
  unset(_targetsDefined)
  unset(_targetsNotDefined)
  unset(_expectedTargets)
  return()
endif()
if(NOT "${_targetsDefined}" STREQUAL "")
  message(FATAL_ERROR "Some (but not all) targets in this export set were already defined.\nTargets Defined: ${_targetsDefined}\nTargets not yet defined: ${_targetsNotDefined}\n")
endif()
unset(_targetsDefined)
unset(_targetsNotDefined)
unset(_expectedTargets)

function(SetProperties ITEM)
	add_library(${CMAKE_FIND_PACKAGE_NAME}::${ITEM} STATIC IMPORTED)

	set_property(TARGET ${CMAKE_FIND_PACKAGE_NAME}::${ITEM} APPEND 
			 	 PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
	set_property(TARGET ${CMAKE_FIND_PACKAGE_NAME}::${ITEM} APPEND 
				 PROPERTY IMPORTED_CONFIGURATIONS NOCONFIG)

	set_target_properties(${CMAKE_FIND_PACKAGE_NAME}::${ITEM} PROPERTIES
						  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "C"
						  IMPORTED_LOCATION_RELEASE "${_CONFIG_DIR}/${HOST}/${PLATFORM}/lib${ITEM}.${_CONFIG_EXT}")
	set_target_properties(${CMAKE_FIND_PACKAGE_NAME}::${ITEM} PROPERTIES
						  IMPORTED_LINK_INTERFACE_LANGUAGES_NOCONFIG "C"
						  IMPORTED_LOCATION_NOCONFIG "${_CONFIG_DIR}/${HOST}/${PLATFORM}/lib${ITEM}.${_CONFIG_EXT}")
endfunction()

foreach(ITEM ${_CONFIG_ITEMS})
	SetProperties(${ITEM})
	set_target_properties(${CMAKE_FIND_PACKAGE_NAME}::${ITEM} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${INC_PATH}/${ITEM}")
	list(APPEND _CONFIG_GROUP_INC "${_CONFIG_INC_PATH}/${ITEM}")
endforeach()

if(_CONFIG_GROUP)
	SetProperties(${_CONFIG_GROUP})
	set_target_properties(${CMAKE_FIND_PACKAGE_NAME}::${_CONFIG_GROUP} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${_CONFIG_GROUP_INC}")
endif()

# Commands beyond this point should not need to know about these
unset(_CONFIG_DIR)
unset(_CONFIG_ITEMS)
unset(_CONFIG_GROUP)
unset(_CONFIG_GROUP_INC)
unset(_CONFIG_EXT)
unset(_CONFIG_INC_PATH)
