CLANG_LIBS := -lclangFrontend -lclangSerialization -lclangDriver -lclangTooling -lclangToolingCore -lclangParse -lclangRewriteFrontend -lclangStaticAnalyzerFrontend -lclangSema -lclangAnalysis -lclangEdit -lclangAST -lclangLex -lclangBasic  -lclangASTMatchers
LLVM_LIBS := -lLLVMX86AsmParser -lLLVMX86Desc -lLLVMX86AsmPrinter -lLLVMX86Info -lLLVMX86Utils -lLLVMipo -lLLVMScalarOpts -lLLVMInstCombine -lLLVMTransformUtils -lLLVMAnalysis -lLLVMTarget -lLLVMOption -lLLVMMCParser -lLLVMMC -lLLVMObject -lLLVMBitReader  -lLLVMCore -lLLVMProfileData -lLLVMSupport -lLLVMDemangle
LIBS := $(CLANG_LIBS) $(LLVM_LIBS) -ldl -pthread -lz -lcurses
DEFINES := -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS

CXXFLAGS := -std=c++11 $(DEFINES) $(LIBS)

all: bindgen

clean:
	rm -f bindgen

bindgen: bindgen.cpp helper.hpp json_stream.hpp structures.hpp
	g++ -o bindgen bindgen.cpp $(CXXFLAGS)

.PHONY: clean
