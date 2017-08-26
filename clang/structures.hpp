#ifndef STRUCTURES_HPP
#define STRUCTURES_HPP

#include "helper.hpp"
#include "json_stream.hpp"

// Forward declare for `Type::templ`
struct Template;

struct Type {
	bool isConst = false; // Constant?
	bool isMove = false; // Move semantics?
	int pointer = 0; // Pointer depth
	bool isReference = false; // If this is a reference
	bool isBuiltin = false; // If this is a C++ built-in type.
	bool isVoid = false; // If the derefenced type is C++ `void`.
	std::string baseName; // Base type. E.g., `const Foo *&` => `Foo`
	std::string fullName; // Full name, for C++. E.g. `const Foo *&`

	CopyPtr<Template> templ = nullptr;
};

static JsonStream &writeTypeJson(JsonStream &s, const Type &value) {
	auto c = JsonStream::Comma;
	s << std::make_pair("isConst", value.isConst) << c
		<< std::make_pair("isMove", value.isMove) << c
		<< std::make_pair("isReference", value.isReference) << c
		<< std::make_pair("isBuiltin", value.isBuiltin) << c
		<< std::make_pair("isVoid", value.isVoid) << c
		<< std::make_pair("pointer", value.pointer) << c
		<< std::make_pair("baseName", value.baseName) << c
		<< std::make_pair("fullName", value.fullName) << c
		<< std::make_pair("template", value.templ);
	return s;
}

JsonStream &operator<<(JsonStream &s, const Type &value) {
	auto c = JsonStream::Comma;
	s << JsonStream::ObjectBegin;
	writeTypeJson(s, value);
	s << JsonStream::ObjectEnd;
	return s;
}

struct Template {
	std::string fullName; // The template class, e.g. `std::vector<_Tp, _Alloc>` in `std::vector<std::string>`
  std::string baseName; // The template class-name, e.g. `std::vector`
	std::vector<Type> arguments; // Arguments, e.g. `std::string`
};

JsonStream &operator<<(JsonStream &s, const Template &value) {
	auto c = JsonStream::Comma;
	s << JsonStream::ObjectBegin
	  << std::make_pair("baseName", value.baseName) << c
	  << std::make_pair("fullName", value.fullName) << c
	  << std::make_pair("arguments", value.arguments)
	 	<< JsonStream::ObjectEnd;
	return s;
}

struct Argument : public Type {
	bool hasDefault; // Does this argument have a default value?
	std::string name; // Name of the argument

	// Use this once C++17 compilers are widely used.
	// std::variant< bool, int64_t, uint64_t, double, JsonStream::Terminal > value;

	enum Kind {
		None,
		BoolKind,
		IntKind,
		UIntKind,
		DoubleKind,
		TerminalKind,
	};

	// If possible, the default value.
	Kind kind;

	union {
		bool bool_value;
		int64_t int_value;
		uint64_t uint_value;
		double double_value;
		JsonStream::Terminal terminal_value;
	};
};

JsonStream &operator<<(JsonStream &s, const Argument &value) {
	auto c = JsonStream::Comma;
	s << JsonStream::ObjectBegin;
	writeTypeJson(s, value) << c;
	s << std::make_pair("hasDefault", value.hasDefault) << c
		<< std::make_pair("name", value.name);

	// This will be much better with C++17 std::variant :)
	if (value.hasDefault && value.kind != Argument::None) {
		s << c << "value" << JsonStream::Separator;

		switch(value.kind) {
		case Argument::BoolKind:
			s << value.bool_value;
			break;
		case Argument::IntKind:
			s << value.int_value;
			break;
		case Argument::UIntKind:
			s << value.uint_value;
			break;
		case Argument::DoubleKind:
			s << value.double_value;
			break;
		case Argument::TerminalKind:
			s << value.terminal_value;
			break;
		}
	}

	s << JsonStream::ObjectEnd;
	return s;
}

struct Method {
	enum MethodType {
		Unknown, // Not exposed!
		Constructor,
		CopyConstructor,
		// Destructor,
		MemberMethod,
		StaticMethod,
		Operator, // Overloaded operator
		Signal, // Qt signal
	};

	MethodType type = Unknown; // Method type
	std::string name; // Name of the method.  Empty for de-/constructors.
	clang::AccessSpecifier access; // Access level
	bool isConst = false; // Is this method const qualified?
	bool isVirtual = false; // Is this method virtual?
	bool isPure = false; // Pure virtual?
	std::string className; // Name of the class.
	std::vector<Argument> arguments; // Arguments
	int firstDefaultArgument = -1;
	Type returnType; // Return type.  Not filled for a constructor.
};

JsonStream &operator<<(JsonStream &s, Method::MethodType value) {
	switch (value) {
		case Method::Constructor: return s << "Constructor";
		case Method::CopyConstructor: return s << "CopyConstructor";
		case Method::MemberMethod: return s << "MemberMethod";
		case Method::StaticMethod: return s << "StaticMethod";
		case Method::Operator: return s << "Operator";
		case Method::Signal: return s << "Signal";
		default: return s << "BUG IN BINDGEN";
	}
}

JsonStream &operator<<(JsonStream &s, const Method &value) {
	auto c = JsonStream::Comma;
	s << JsonStream::ObjectBegin
		<< std::make_pair("type", value.type) << c
		<< std::make_pair("access", value.access) << c
		<< std::make_pair("name", value.name) << c
		<< std::make_pair("isConst", value.isConst) << c
		<< std::make_pair("isVirtual", value.isVirtual) << c
		<< std::make_pair("isPure", value.isPure) << c
		<< std::make_pair("className", value.className) << c;

	if (value.firstDefaultArgument < 0) {
		s << std::make_pair("firstDefaultArgument", JsonStream::Null) << c;
	} else {
		s << std::make_pair("firstDefaultArgument", value.firstDefaultArgument) << c;
	}

	s << std::make_pair("arguments", value.arguments) << c
	  << std::make_pair("returnType", value.returnType)
		<< JsonStream::ObjectEnd;

	return s;
}

struct BaseClass {
	bool isVirtual; // Is this a virtual inheritance?
	bool inheritedConstructor; // Do we inherit a constructor from this class?
	std::string name; // Name of the class
	clang::AccessSpecifier access; // Access level
};

JsonStream &operator<<(JsonStream &s, clang::AccessSpecifier value) {
	switch (value) {
		case clang::AS_public: return s << "Public";
		case clang::AS_protected: return s << "Protected";
		case clang::AS_private: return s << "Private";
		case clang::AS_none: return s << "BUG IN Bindgen";
	}
}

JsonStream &operator<<(JsonStream &s, const BaseClass &value) {
	auto c = JsonStream::Comma;
	return s
		<< JsonStream::ObjectBegin
		<< std::make_pair("name", value.name) << c
		<< std::make_pair("isVirtual", value.isVirtual) << c
		<< std::make_pair("inheritedConstructor", value.inheritedConstructor) << c
		<< std::make_pair("access", value.access)
		<< JsonStream::ObjectEnd;
}

struct Field : public Type {
	clang::AccessSpecifier access;
	std::string name;
	int bitField = -1;
};

JsonStream &operator<<(JsonStream &s, const Field &value) {
	auto c = JsonStream::Comma;
	s << JsonStream::ObjectBegin;
	writeTypeJson(s, value) << c;
	s << std::make_pair("name", value.name) << c
		<< std::make_pair("access", value.access) << c;

	if (value.bitField > 0)
		s << std::make_pair("bitField", value.name);
	else
		s << std::make_pair("bitField", JsonStream::Null);

	return s << JsonStream::ObjectEnd;
}

struct Class {
	bool isClass; // Class or struct?
	bool hasDefaultConstructor;
	bool hasCopyConstructor;
	bool isDestructible = true; // Does this class have a public or protected destructor?
	bool isAbstract; // Does the class have pure virtual methods?
	int byteSize; // Size of an instance in memory.
	std::string name; // Fully::qualified::class::name
	std::vector<BaseClass> bases; // Names of base classes
	std::vector<Method> methods; // Methods
	std::vector<Field> fields; // Accessible fields
};

JsonStream &operator<<(JsonStream &s, const Class &value) {
	auto c = JsonStream::Comma;
	return s
		<< JsonStream::ObjectBegin
		<< std::make_pair("name", value.name) << c
		<< std::make_pair("byteSize", value.byteSize) << c
		<< std::make_pair("isClass", value.isClass) << c
		<< std::make_pair("isAbstract", value.isAbstract) << c
		<< std::make_pair("isDestructible", value.isDestructible) << c
		<< std::make_pair("hasDefaultConstructor", value.hasDefaultConstructor) << c
		<< std::make_pair("hasCopyConstructor", value.hasCopyConstructor) << c
		<< std::make_pair("bases", value.bases) << c
		<< std::make_pair("fields", value.fields) << c
		<< std::make_pair("methods", value.methods)
		<< JsonStream::ObjectEnd;
}

struct Enum {
	std::string name;
	std::string type;
	bool isFlags = false;
	std::vector<std::pair<std::string, int64_t>> values;
};

JsonStream &operator<<(JsonStream &s, const Enum &value) {
	auto c = JsonStream::Comma;
	s << JsonStream::ObjectBegin
		<< std::make_pair("name", value.name) << c
		<< std::make_pair("type", value.type) << c
		<< std::make_pair("isFlags", value.isFlags) << c
		<< "values" << JsonStream::Separator << JsonStream::ObjectBegin;

	bool first = true;
	for (const std::pair<std::string, int64_t> &elem : value.values) {
		if (!first) s << c;
		s << std::make_pair(elem.first, elem.second);
		first = false;
	}

	s << JsonStream::ObjectEnd << JsonStream::ObjectEnd;
	return s;
}

#endif // STRUCTURES_HPP
