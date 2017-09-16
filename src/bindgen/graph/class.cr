module Bindgen
  module Graph
    # A `class` in Crystal, or a C++ `struct`.  We use a `struct` in C++ due to
    # it defaulting to `public` visibility.
    class Class < Container
      # The origin class
      getter origin : Parser::Class

      # If this class is to be shadow sub-classed in C++, the full name of the
      # structure.  Processors make the assumption that if this is set, the
      # class will be sub-classed, and may generate code different to what they
      # would've done without.  This affects Crystal `#initialize` methods, and
      # the `CONSTRUCT` C++ wrappers.
      property cpp_sub_class : String?

      # If this is set, the class is assumed to be `abstract`.  This property
      # then contains the qualified Crystal name of the implementation class.
      property wrap_class : String?

      # Name of the base-class, if any.
      property base_class : String?

      # Is this class abstract?
      property? abstract : Bool = false

      # If the structure of this class is copied, the `Struct` node.
      property structure : Struct?

      # Crystal instance vars in this class.  Will be ignored by the C++ code
      # paths.
      getter instance_variables = { } of String => Call::Result

      def initialize(@origin, name, parent)
        super(name, parent)
      end

      # The mangled name of this class, used to build structures with a class
      # name component.
      def mangled_name
        @name.gsub(/[^a-z0-9]/i, "_")
      end
    end
  end
end
