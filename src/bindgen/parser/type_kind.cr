module Bindgen
  module Parser
    # Describes the declaration kind of a C++ type.
    enum TypeKind
      Class
      Struct
      CppUnion
      Interface
      Enum
    end
  end
end
