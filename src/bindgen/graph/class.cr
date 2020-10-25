module Bindgen
  module Graph
    # A `class` in Crystal, or a C++ `struct`.  We use a `struct` in C++ due to
    # it defaulting to `public` visibility.
    class Class < Container
      # When this tag is set, `Processor::CrystalWrapper` will emit the
      # `@unwrap` instance variable and the `#to_unsafe` method.  This overrides
      # its default behaviour of deducing if these are required.
      FORCE_UNWRAP_VARIABLE_TAG = "FORCE_UNWRAP_VARIABLE_TAG"

      # The origin class
      getter origin : Parser::Class

      # If this class is to be shadow sub-classed in C++, the full name of the
      # structure.  Processors make the assumption that if this is set, the
      # class will be sub-classed, and may generate code different to what they
      # would've done without.  This affects Crystal `#initialize` methods, and
      # the `CONSTRUCT` C++ wrappers.
      property cpp_sub_class : String?

      # If this is set, the class is assumed to be `abstract`.  This property
      # then contains the implementation class node.
      property wrap_class : Class?

      # Opposite direction of `#wrap_class`: From the `Impl` class back to its
      # `abstract` parent.
      property wrapped_class : Class?

      # Name of the base-class, if any.  Used by both Crystal and C++, and may
      # point at types outside the graph.
      property base_class : String?

      # List of included Crystal modules.  Used by wrapper classes only, and may
      # point at modules outside the graph.  Ignored by C++ structs.
      getter included_modules = Set(String).new

      # Is this class abstract?
      property? abstract : Bool = false

      # If the structure of this class is copied, the `Struct` or `CppUnion`
      # node.
      property structure : (Struct | CppUnion)?

      # Crystal instance vars in this class.  Will be ignored by the C++ code
      # paths.
      getter instance_variables = {} of String => Call::Result

      def initialize(@origin, name, parent = nil)
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
