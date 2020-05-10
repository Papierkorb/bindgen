cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
project(bindgen-clang)

######################
# LLVM Setup
######################

set(LLVM_ENABLE_LIBCXX ON)

# Search for LLVM
find_package(LLVM REQUIRED CONFIG)

message(STATUS "Found LLVM: ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")
string(REGEX MATCH "^([0-9]+)" LLVM_VER ${LLVM_PACKAGE_VERSION})
message(STATUS "LLVM Major version: ${LLVM_VER}")

# If LLVM 10+ change std version
if(LLVM_VER GREATER_EQUAL 10)
  message(STATUS "Setting std version: c++14")
  set(CMAKE_CXX_STANDARD_14)
else()
  set(CMAKE_CXX_STANDARD_11)
endif()

# Add llvm version definition
add_definitions(-D__LLVM_VERSION_${LLVM_VER})

# Find the LLVM clang++ path
message(STATUS "LLVM Tools Dir: ${LLVM_TOOLS_BINARY_DIR}")

find_program(clang_bin "clang++" PATHS: ${LLVM_TOOLS_BINARY_DIR})
# message(STATUS "Found clang bin: ${clang_bin}")
set(CMAKE_CXX_COMPILER ${clang_bin})
message(STATUS "Using clang++ exec: ${CMAKE_CXX_COMPILER}")

# Find llvm-config bin
find_program(llvm_config_bin "llvm-config" PATHS: ${LLVM_TOOLS_BINARY_DIR})
message(STATUS "Using llvm-config exec: ${llvm_config_bin}")

# Include LLVM dirs
message(STATUS "Include LLVM dirs: ${LLVM_INCLUDE_DIRS}")
include_directories(${LLVM_INCLUDE_DIRS})

message(STATUS "Add LLVM definitions: ${LLVM_DEFINITIONS}")
add_definitions(${LLVM_DEFINITIONS})

# Find the libraries that correspond to the LLVM components
# that we wish to use
llvm_map_components_to_libnames(llvm_libs all)

######################
# Gather info
######################

# Find crystal bin
if(NOT EXISTS ${crystal_bin})
  find_program(crystal_bin crystal)
  message(STATUS "Found crystal exec: ${crystal_bin}")
endif()

if(NOT EXISTS ${shards_bin})
  find_program(shards_bin shards)
  message(STATUS "Found shards exec: ${shards_bin}")
endif()

# Execute find_clang.cr
message(STATUS "Run: crystal find_clang.cr -- --clang ${CMAKE_CXX_COMPILER} --quiet")

execute_process(
        COMMAND ${crystal_bin} ${PROJECT_SOURCE_DIR}/find_clang.cr -- --clang ${CMAKE_CXX_COMPILER} --quiet
        # COMMAND_ECHO STDOUT
        ERROR_VARIABLE find_clang_error
        OUTPUT_FILE ${PROJECT_SOURCE_DIR}/Makefile.variables
)

if(NOT ${find_clang_error} STREQUAL "")
  message(FATAL_ERROR ${find_clang_error})
endif()

# Execute find_clang.cr for clang_libs
message(STATUS "Run: crystal find_clang.cr -- --clang-libs --clang ${CMAKE_CXX_COMPILER} --quiet")
execute_process(
        COMMAND ${crystal_bin} ${PROJECT_SOURCE_DIR}/find_clang.cr -- --clang-libs --clang ${CMAKE_CXX_COMPILER} --quiet
        # COMMAND_ECHO STDOUT
        OUTPUT_VARIABLE clang_libs
        ERROR_VARIABLE find_clang_error
)
if(NOT ${find_clang_error} STREQUAL "")
  message(FATAL_ERROR ${find_clang_error})
endif()


if("${llvm_libs}" STREQUAL "")
  message(WARNING "Unable to find llvm libs. Will run command manually" )

  # NOTE: This execute_process will use `llvm-config --libs all` to gather the libs
  # message(STATUS "Run: ${llvm_config_bin} --libs all")
  # execute_process(
  #         COMMAND bash -c "${llvm_config_bin} --libs all | sed -E 's/\-l/;/g' | sed -E 's/ //g'"
  #         # COMMAND_ECHO STDOUT
  #         # ERROR_VARIABLE find_clang_error
  #         OUTPUT_VARIABLE llvm_libs
  #         OUTPUT_STRIP_TRAILING_WHITESPACE
  # )

  # Execute find_clang.cr for clang_libs
  message(STATUS "Run: crystal find_clang.cr -- --llvm-libs --clang ${CMAKE_CXX_COMPILER} --quiet")
  execute_process(
          COMMAND ${crystal_bin} ${PROJECT_SOURCE_DIR}/find_clang.cr -- --llvm-libs --clang ${CMAKE_CXX_COMPILER} --quiet
          # COMMAND_ECHO STDOUT
          OUTPUT_VARIABLE llvm_libs
          ERROR_VARIABLE find_clang_error
  )

endif()




######################
# Configure sources
######################

# Setup sources
include_directories(${PROJECT_SOURCE_DIR}/src)
include_directories(${PROJECT_SOURCE_DIR}/include)

file(GLOB source_files "${PROJECT_SOURCE_DIR}/src/*.cpp")
add_executable(bindgen ${source_files})

# Link against clang libraries
target_link_libraries(bindgen ${clang_libs})
if ("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
  message(STATUS "CLang Libs: ${clang_libs}")
endif()

# Link against LLVM libraries
target_link_libraries(bindgen ${llvm_libs})
if ("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
  message(STATUS "LLVM Libs: ${llvm_libs}")
endif ()

message(STATUS "CMake System Name: ${CMAKE_SYSTEM_NAME}")

if ("${CMAKE_SYSTEM_NAME}" STREQUAL "Darwin")
  include_directories(/usr/local/include)

  # for MacOS X or iOS, watchOS, tvOS (since 3.10.3)
  if (${LLVM_PACKAGE_VERSION} VERSION_GREATER "4")
    # Enable threads if LLVM over 4
    set(THREADS_PREFER_PTHREAD_FLAG ON)
    find_package(Threads REQUIRED)
    target_link_libraries(bindgen Threads::Threads)
  endif ()
elseif ("${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
  # Add -ltinfo and -pthread
  target_link_libraries(bindgen tinfo)

  # Enable threads
  set(THREADS_PREFER_PTHREAD_FLAG ON)
  find_package(Threads REQUIRED)
  target_link_libraries(bindgen Threads::Threads)
endif ()

# -ldl -lz -lcurses -lpcre
target_link_libraries(bindgen dl z curses pcre)
