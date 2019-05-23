module Bindgen
  module Generator
    # Generator for Crystal `lib`.  Automatically invoked by `Crystal`.
    class CrystalLib < Base
      include Graph::Visitor

      PLATFORM = Graph::Platform::CrystalBinding

      def write(node : Graph::Container)
        raise "CrystalLib#write_all expects a Graph::Library" unless node.is_a?(Graph::Library)

        visit_node(node)
      end

      def visit_library(library)
        puts %<@[Link(ldflags: "#{library.ld_flags}")]> if library.ld_flags
        puts "lib #{library.name}"
        indented { super }
        puts "end"
      end

      def visit_class(klass)
        return unless @db.try_or(klass.origin.name, true, &.generate_binding)
        super
      end

      def visit_method(method)
        call = method.calls[PLATFORM]?
        return if call.nil? # Ignore non-bound methods
        puts call.body.to_code(call, PLATFORM)
      end

      def visit_struct(structure)
        puts "struct #{structure.name}"
        indented do
          structure.fields.each do |name, type|
            # can't use Void as a struct field type
            if type.type_name == "Void"
              puts "#{name} : #{type.type_name}*"
            else
              puts "#{name} : #{type.type_name}"
            end
          end
        end
        puts "end"
      end

      def visit_alias(alias_name)
        puts "alias #{alias_name.name} = #{alias_name.origin.type_name}"
      end
    end
  end
end
