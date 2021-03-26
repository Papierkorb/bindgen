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
if(LLVM_VER GREATER 9)
  message(STATUS "Setting std version: c++14")
  set(CMAKE_CXX_STANDARD 14)
else()
  message(STATUS "Setting std version: c++11")
  set(CMAKE_CXX_STANDARD 11)
endif()

# Add llvm version definition
add_definitions(-D__LLVM_VERSION_${LLVM_VER})

# Find the LLVM clang++ path
message(STATUS "LLVM Tools Dir: ${LLVM_TOOLS_BINARY_DIR}")

find_program(llvm_clang_bin NAMES "clang++" PATHS ${LLVM_TOOLS_BINARY_DIR} NO_DEFAULT_PATH REQUIRED)
# message(STATUS "Found clang bin: ${llvm_clang_bin}")
set(CMAKE_CXX_COMPILER ${llvm_clang_bin})
message(STATUS "Using clang++ exec: ${CMAKE_CXX_COMPILER}")

# Find llvm-config bin
find_program(llvm_config_bin NAMES "llvm-config" PATHS ${LLVM_TOOLS_BINARY_DIR} NO_DEFAULT_PATH REQUIRED)
message(STATUS "Found llvm-config bin: ${llvm_config_bin}")
set(LLVM_CONFIG ${llvm_config_bin})
message(STATUS "Using llvm-config exec: ${LLVM_CONFIG}")

# Include LLVM dirs
message(STATUS "Include LLVM dirs: ${LLVM_INCLUDE_DIRS}")
include_directories(${LLVM_INCLUDE_DIRS})

message(STATUS "Add LLVM definitions: ${LLVM_DEFINITIONS}")
add_definitions(${LLVM_DEFINITIONS})