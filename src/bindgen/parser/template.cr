module Bindgen
  module Parser
    # Stores information about a template `Type`.
    class Template
      include JSON::Serializable

      # Full name, like `std::vector<_Tp, _Alloc>`
      property fullName : String

      # Base name of the type, like `std::vector`
      property baseName : String

      # Template arguments
      property arguments : Array(Type)

      def initialize(@fullName, @baseName, @arguments)
      end

      def_equals_and_hash @fullName, @baseName, @arguments

      # Full name, like `std::vector<_Tp, _Alloc>`
      def full_name : String
        @fullName
      end

      # Base name of the type, like `std::vector`
      def base_name : String
        @baseName
      end

      # Returns the mangled name of the template arguments.
      def mangled_name : String
        @arguments.map(&.mangled_name).join("_")
      end
    end
  end
end
