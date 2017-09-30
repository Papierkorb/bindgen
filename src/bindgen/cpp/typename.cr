module Bindgen
  module Cpp
    # C++ type-name generation logic.
    struct Typename
      # Formats the type in *result* in C++ style.
      def full(result : Call::Expression) : String
        stars = "*" * result.pointer
        ref = "&" if result.reference
        const = "const " if result.type.const?
        "#{const}#{result.type_name}#{stars}#{ref}"
      end

      # Formats many *results*.
      def full(results : Enumerable(Call::Expression)) : Array(String)
        results.map{|result| full(result)}
      end
    end
  end
end
