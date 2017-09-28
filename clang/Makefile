LIBS     := $(shell crystal run find_clang.cr) -ldl -pthread -lz -lcurses
DEFINES  := -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS
CXXFLAGS := -std=c++11 $(DEFINES) -Iinclude

HEADERS  := $(wildcard include/*.hpp)
SOURCES  := $(wildcard src/*.cpp)
OBJECTS  := $(patsubst src/%.cpp,build/%.o,$(SOURCES))
BINARY   := bindgen

RM       ?= rm
CXX      ?= g++

all: $(BINARY)

clean:
	$(RM) -f bindgen

build/%.o: src/%.cpp $(HEADERS)
	$(CXX) -c -o $@ $< $(CXXFLAGS)

$(BINARY): $(OBJECTS)
	$(CXX) -o $(BINARY) $(OBJECTS) $(LIBS)

.PHONY: clean
