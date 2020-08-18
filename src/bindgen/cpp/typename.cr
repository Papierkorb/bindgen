module Bindgen
  module Cpp
    # C++ type-name generation logic.
    struct Typename
      # Formats the type in *result* in C++ style.
      def full(result : Call::Expression) : String
        full(result.type_name, result.type.const?, result.pointer, result.reference, result.type.extents)
      end

      # ditto
      def full(base_name : String, const, pointer, is_reference, extents) : String
        String.build do |b|
          b << "const " if const
          b << base_name

          stars = "*" * pointer if pointer > 0
          subscripts = extents.map {|v| "[#{v unless v.zero?}]"}.join unless
            extents.nil? || extents.empty?
          ref = "&" if is_reference

          b << ' ' if stars || ref || subscripts
          b << stars << subscripts << ref
        end
      end

      # Formats many *results*.
      def full(results : Enumerable(Call::Expression)) : Array(String)
        results.map { |result| full(result) }
      end
    end
  end
end
