IGNORE   := $(shell crystal run find_clang.cr > Makefile.variables)
include Makefile.variables

STD_VER      := c++11
CLANG_MAJOR  := $(shell $(CLANG_BINARY) --version |awk '/clang version/{print $$3}' |cut -f1 -d.)
CLANG_GTE_10 := $(shell test $(CLANG_MAJOR) -ge 10 && echo yes)
ifeq ($(CLANG_GTE_10), yes)
	STD_VER := c++14
endif

LIBS     := $(CLANG_LIBS) -ldl -pthread -lz -lcurses -ltinfo -lpcre
DEFINES  := -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS
DBGFLAGS := -O0 -g -fno-inline-functions -fno-omit-frame-pointer
WARFLAGS := -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable
CXXFLAGS := $(DBGFLAGS) $(WARFLAGS) -fexceptions -fstack-protector-strong -std=$(STD_VER) $(DEFINES) -Iinclude $(CLANG_INCLUDES)

HEADERS  := $(wildcard include/*.hpp)
SOURCES  := $(wildcard src/*.cpp)
OBJECTS  := $(patsubst src/%.cpp,build/%.o,$(SOURCES))
BINARY   := bindgen

RM       ?= rm
CXX      := $(CLANG_BINARY)

all: $(BINARY)

clean:
	$(RM) -f bindgen $(OBJECTS)

build/%.o: src/%.cpp $(HEADERS)
	$(CXX) -c -o $@ $< $(CXXFLAGS)

$(BINARY): $(OBJECTS)
	$(CXX) -o $(BINARY) $(OBJECTS) $(LIBS)

.PHONY: clean
