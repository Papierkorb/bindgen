module Bindgen
  module Parser
    # Stores information about a template `Type`.
    class Template
      include JSON::Serializable

      # Full name, like `std::vector<_Tp, _Alloc>`
      @[JSON::Field(key: "fullName")]
      getter full_name : String

      # Base name of the type, like `std::vector`
      @[JSON::Field(key: "baseName")]
      getter base_name : String

      # Template arguments
      getter arguments : Array(Type)

      def initialize(@full_name, @base_name, @arguments)
      end

      def_equals_and_hash @full_name, @base_name, @arguments

      # Returns the mangled name of the template arguments.
      def mangled_name : String
        @arguments.map(&.mangled_name).join("_")
      end
    end
  end
end
