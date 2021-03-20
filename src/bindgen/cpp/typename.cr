module Bindgen
  module Cpp
    # C++ type-name generation logic.
    struct Typename
      # Formats the type in *result* in C++ style.
      def full(result : Call::Expression) : String
        full(result.type_name, result.type.const?, result.pointer, result.reference)
      end

      # :ditto:
      def full(base_name : String, const, pointer, is_reference) : String
        stars = "*" * pointer
        ref = "&" if is_reference

        String.build do |b|
          b << "const " if const
          b << base_name

          if pointer > 0 || is_reference
            b << ' ' << ("*" * pointer)
            b << '&' if is_reference
          end
        end
      end

      # Formats many *results*.
      def full(results : Enumerable(Call::Expression)) : Array(String)
        results.map { |result| full(result) }
      end
    end
  end
end
