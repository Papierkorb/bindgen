module Bindgen
  module Processor
    # Checks that all default-constructible classes have a default constructor
    # defined.
    class DefaultConstructor < Base
      def visit_class(klass : Graph::Class)
        return unless klass.origin.has_default_constructor?
        return if klass.wrapped_class # Skip `Impl` classes.
        return if has_default_initialize?(klass)
        return if has_private_constructor?(klass.origin)

        ctor = build_default_constructor(klass.origin)

        Graph::Method.new(
          origin: ctor,
          name: ctor.name,
          parent: klass,
        )
      end

      private def build_default_constructor(klass : Parser::Class)
        Parser::Method.build(
          type: Parser::Method::Type::Constructor,
          name: "",
          class_name: klass.name,
          arguments: [ ] of Parser::Argument,
          return_type: Parser::Type::VOID,
        )
      end

      private def has_default_initialize?(klass : Graph::Class)
        klass.nodes.any? do |node|
          next unless node.is_a?(Graph::Method)
          default_constructor?(node.origin)
        end
      end

      private def default_constructor?(method : Parser::Method) : Bool
        return false unless method.any_constructor?

        # We also accept a constructor where all arguments have an exposed
        # default value.
        required = method.arguments.size - method.arguments.count(&.value.!= nil)

        # Found?
        required == 0
      end

      private def has_private_constructor?(klass)
        ctor = klass.methods.find{|method| default_constructor? method}

        if ctor
          ctor.private?
        else
          false # Doesn't exist: Not private.
        end
      end
    end
  end
end
