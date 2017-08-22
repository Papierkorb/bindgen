module Bindgen
  module Parser
    # Stores information about a template `Type`.
    class Template
      JSON.mapping(
        # Full name, like `std::vector<_Tp, _Alloc>`
        fullName: String,

        # Base name of the type, like `std::vector`
        baseName: String,

        # Template arguments
        arguments: Array(Type),
      )
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
  end
end
