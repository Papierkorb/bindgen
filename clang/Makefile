IGNORE   := $(shell crystal run find_clang.cr > Makefile.variables)
include Makefile.variables

UNAME_S := $(shell uname -s)

# If OSX
ifeq ($(UNAME_S),Darwin)
	include Makefile.osx
else
	LIBS     := $(CLANG_LIBS) -ldl -pthread -lz -lcurses -lpcre
	DEFINES  := -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS
	CXXFLAGS := -std=c++11 $(DEFINES) -Iinclude $(CLANG_INCLUDES)
endif # end ifeq ($(UNAME_S),Darwin)

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
