module Bindgen
  module Parser
    # Enumeration type as found by the clang tool.
    class Enum
      include JSON::Serializable

      # Map of enumerations.
      alias Collection = Hash(String, Enum)

      # Name of the enumeration type.
      property name : String
      # C++ type name, to be mapped later.
      property type : String
      # Is this enumeration a flag type?
      property isFlags : Bool
      # Enum fields
      property values : Hash(String, Int64)

      def initialize(@name, @values, @type = "unsigned int", @isFlags = false)
      end

      # Tries to figure out if this enumeration is actually a bit-mask flag.
      def flags?
        @isFlags
      end

      def_equals_and_hash @name, @type, @isFlags, @values
    end
  end
end
