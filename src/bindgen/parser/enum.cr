module Bindgen
  module Parser
    # Enumeration type as found by the clang tool.
    class Enum
      # Map of enumerations.
      alias Collection = Hash(String, Enum)

      JSON.mapping(
        name: String, # Name of the enumeration type.
        type: String, # C++ type name, to be mapped later.
        isFlags: Bool, # Is this enumeration a flag type?
        values: Hash(String, Int64), # Enum fields
      )

      # Tries to figure out if this enumeration is actually a bit-mask flag.
      def flags?
        @isFlags
      end
    end
  end
end
