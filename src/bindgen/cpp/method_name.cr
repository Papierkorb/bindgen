module Bindgen
  module Cpp
    # Generator for calling methods by their name.
    struct MethodName
      GLOBAL_SCOPE = "::"

      include TypeHelper

      def initialize(@db : TypeDatabase)
      end

      # Generates the C++ *method* name.
      #
      # If this kind of method requires an instance, it will use *self_var* and
      # use `->` on it.
      #
      # If the *method* is any constructor, and the type is copied, the
      # constructor will be called without `new`, effectively returning a value.
      # Otherwise, a normal `new` is used to return a pointer.
      def generate(method : Parser::Method, self_var : String, type : Parser::Method::Type? = nil)
        type ||= method.type
        case type
        when .copy_constructor?, .constructor?
          if is_type_copied?(method.class_name)
            method.class_name
          else # Support shadow sub-classing.
            name = class_name_for_new(method.class_name)
            @db.cookbook.constructor_name(method.name, name)
          end
        when .member_method?, .member_getter?, .member_setter?, .signal?, .operator?
          "#{self_var}->#{method.name}"
        when .static_method?
          if method.class_name == GLOBAL_SCOPE
            "::#{method.name}"
          else
            "#{method.class_name}::#{method.name}"
          end
        else
          raise "BUG: Missing case for method type #{method.type.inspect}"
        end
      end

      # Finds *class_name* in the graph and checks if it's shadow sub-classed in
      # C++.  If so, returns the name of the shadow class.
      private def class_name_for_new(class_name)
        if klass = @db.try_or(class_name, nil, &.graph_node.as(Graph::Class))
          klass.cpp_sub_class || class_name
        else
          class_name
        end
      end
    end
  end
end
