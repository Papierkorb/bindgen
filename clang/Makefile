LIBS := $(shell crystal run find_clang.cr) -ldl -pthread -lz -lcurses
DEFINES := -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS
CXXFLAGS := -std=c++11 $(DEFINES) $(LIBS)

all: bindgen

clean:
	rm -f bindgen

bindgen: bindgen.cpp helper.hpp json_stream.hpp structures.hpp
	g++ -o bindgen bindgen.cpp $(CXXFLAGS)

.PHONY: clean
