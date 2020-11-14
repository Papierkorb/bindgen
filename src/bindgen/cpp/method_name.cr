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
      #
      # If *exact_member* is true and *method* is a member method, the qualified
      # method is called, bypassing dynamic lookup.
      def generate(
        method : Parser::Method, self_var : String,
        type : Parser::Method::Type? = nil, exact_member = false
      )
        type ||= method.type
        case type
        when .any_constructor?
          if type_copied?(method.class_name)
            method.class_name
          else # Support shadow sub-classing.
            name = class_name_for_new(method.class_name)
            @db.cookbook.constructor_name(method.name, name)
          end
        when .member_method?, .member_getter?, .member_setter?, .signal?, .operator?
          if exact_member
            "#{self_var}->#{qualified method}"
          else
            "#{self_var}->#{method.name}"
          end
        when .static?
          qualified(method)
        else
          raise "BUG: Missing case for method type #{method.type.inspect}"
        end
      end

      # Returns the qualified name of a method.
      private def qualified(method)
        if method.class_name == GLOBAL_SCOPE
          "::#{method.name}"
        else
          "#{method.class_name}::#{method.name}"
        end
      end

      # Finds *class_name* in the graph and checks if it's shadow sub-classed in
      # C++.  If so, returns the name of the shadow class.
      private def class_name_for_new(class_name)
        @db.try_or(class_name, class_name) do |rules|
          rules.graph_node.as?(Graph::Class).try(&.cpp_sub_class)
        end
      end
    end
  end
end
