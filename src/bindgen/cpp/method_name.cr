module Bindgen
  module Cpp
    # Generator for calling methods by their name.
    struct MethodName
      include TypeHelper

      def initialize(@db : TypeDatabase)
      end

      # Generates the C++ *method* name.  The class name is not taken from
      # *method* to support sub-classing: The user doesn't really know we
      # sub-classed the real class, and in these cases *klass* contains the
      # actual name (Something like `BgInherit_CLASSNAME`).
      #
      # If this kind of method requires an instance, it will use *self_var* and
      # use `->` on it.
      #
      # If the *method* is any constructor, and the type is copied, the
      # constructor will be called without `new`, effectively returning a value.
      # Otherwise, a normal `new` is used to return a pointer.
      def generate(method : Parser::Method, klass : String, self_var : String)
        case method
        when .copy_constructor?, .constructor?
          if is_type_copied?(method.class_name)
            klass
          else
            "new (UseGC) #{klass}"
          end
        when .member_method?, .signal?, .operator?
          "#{self_var}->#{method.name}"
        when .static_method?
          "#{method.class_name}::#{method.name}"
        else
          raise "BUG: Missing case for method type #{method.type.inspect}"
        end
      end
    end
  end
end
