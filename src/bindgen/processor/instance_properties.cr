module Bindgen
  module Processor
    # Processor to add getter and setter methods for instance variables.
    class InstanceProperties < Base
      def initialize(*args)
        super
      end

      def visit_class(klass : Graph::Class)
        # Skip `Impl` classes.  Also skip classes whose structures are copied
        # into `Binding`, as all fields are directly accessible anyway.
        return if klass.wrapped_class || @db[klass.name]?.try(&.copy_structure)

        klass.origin.each_field do |field|
          # Ignore private fields.  Also ignore all reference fields for now.
          next if field.private? || field.reference? || field.move?

          add_getter(klass, field)
          add_setter(klass, field) unless field.const?
        end

        super
      end

      # Builds a C++ wrapper method for an instance variable getter.  The `lib`
      # binding and the Crystal wrapper method are generated later.
      private def add_getter(klass, field)
        # C++'s `protected` is closer to Crystal's `private` than to `protected`
        access = field.protected? ?
          Parser::AccessSpecifier::Private : Parser::AccessSpecifier::Public

        method_origin = Parser::Method.new(
          name: field.name,
          className: klass.origin.name,
          returnType: field.as(Parser::Type),
          arguments: [] of Parser::Argument,
          type: Parser::Method::Type::MemberGetter,
          access: access,
          isConst: true,
        )

        method = Graph::Method.new(
          name: method_origin.name,
          origin: method_origin,
          parent: klass,
        )

        body = GetterBody.new
        target = CallBuilder::CppCall.new(@db).build(method_origin, body: body)
        call = CallBuilder::CppWrapper.new(@db).build(method_origin, target)
        method.calls[Graph::Platform::Cpp] = call
      end

      # Code body for reading from a C++ instance variable.
      private class GetterBody < Call::Body
        def to_code(call : Call, _platform : Graph::Platform) : String
          code = call.name

          if templ = call.result.conversion
            code = Util.template(templ, code)
          end

          code
        end
      end

      # Builds a C++ wrapper method for an instance variable setter.  The `lib`
      # binding and the Crystal wrapper method are generated later.
      private def add_setter(klass, field)
        # C++'s `protected` is closer to Crystal's `private` than to `protected`
        access = field.protected? ?
          Parser::AccessSpecifier::Private : Parser::AccessSpecifier::Public

        arg = Parser::Argument.new(field.name, field.as(Parser::Type))

        method_origin = Parser::Method.new(
          name: field.name,
          className: klass.origin.name,
          returnType: Parser::Type::VOID,
          arguments: [arg],
          type: Parser::Method::Type::MemberSetter,
          access: access,
        )

        method = Graph::Method.new(
          name: method_origin.name,
          origin: method_origin,
          parent: klass,
        )

        body = SetterBody.new
        target = CallBuilder::CppCall.new(@db).build(method_origin, body: body)
        call = CallBuilder::CppWrapper.new(@db).build(method_origin, target)
        method.calls[Graph::Platform::Cpp] = call
      end

      # Code body for writing to a C++ instance variable.
      private class SetterBody < Call::Body
        def to_code(call : Call, _platform : Graph::Platform) : String
          code = call.arguments.first.call

          if templ = call.result.conversion
            code = Util.template(templ, code)
          end

          "#{call.name} = #{code}"
        end
      end
    end
  end
end
