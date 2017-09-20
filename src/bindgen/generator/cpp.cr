module Bindgen
  module Generator
    # Generator for C functions calling C++ code.
    class Cpp < Base
      include Graph::Visitor

      PLATFORM = Graph::Platform::Cpp

      def write(node : Graph::Container)
        visit_children(node)
      end

      def visit_platform_specific(specific)
        super if specific.platform == PLATFORM
      end

      def visit_library(_library)
        nil # Don't visit a `lib`
      end

      def visit_class(klass)
        begin_section klass.name
        super
      end

      def visit_alias(alias_name)
        typer = Bindgen::Cpp::Typename.new
        type_name = typer.full(alias_name.origin)
        puts "typedef #{type_name} #{alias_name.name};"
      end

      def visit_struct(structure)
        prototype = type_prototype :struct, structure.name, structure.base_class
        puts "#{prototype} {"
        indented do
          if structure.tag?(Graph::Struct::INHERIT_CONSTRUCTORS_TAG)
            base = structure.base_class
            puts "using #{base}::#{base};" # C++11
          end

          structure.fields.each do |name, type|
            puts "#{type.type_name} #{name};"
          end

          super # Implement methods, if any
        end
        puts "};"
      end

      def visit_method(method)
        if call = method.calls[PLATFORM]?
          puts call.body.to_code(call, PLATFORM)
        end
      end

      private def type_prototype(kind, name, base) : String
        suffix = " : public #{base}" if base
        "#{kind} #{name}#{suffix}"
      end
    end
  end
end
