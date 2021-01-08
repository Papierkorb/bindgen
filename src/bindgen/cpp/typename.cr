module Bindgen
  module Cpp
    # C++ type-name generation logic.
    struct Typename
      # Formats the type in *result* in C++ style.
      def full(result : Call::Expression) : String
        full(result.type_name, result.type.const?, result.pointer, result.reference)
      end

      # ditto
      def full(base_name : String, const, pointer, is_reference) : String
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

      # Generates the C++ type name of a *template* class with the given
      # template type *arguments*.
      def template_class(template : String, arguments : Enumerable(String)) : String
        String.build do |b|
          b << template << '<'

          first = true
          needs_space = false
          arguments.each do |arg|
            b << ", " unless first
            b << arg
            first = false
            needs_space = arg.ends_with?('>')
          end

          b << ' ' if needs_space
          b << '>'
        end
      end
    end
  end
end
