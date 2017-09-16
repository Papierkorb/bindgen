module Bindgen
  module Cpp
    # C++ type-name generation logic.
    struct Typename
      # Formats the type in *result* in C++ style.
      def full(result : Call::Expression)
        stars = "*" * result.pointer
        ref = "&" if result.reference
        "#{result.type_name}#{stars}#{ref}"
      end
    end
  end
end
