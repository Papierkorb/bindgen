module Bindgen
  module Cpp
    # Parser for C++ literal types.
    struct LiteralParser
      NUMERIC_RX = /^([+-]?[0-9\.e]+)(f|U|L|UL|ULL|LL|)$/

      # Tries to read *literal* into a Crystal variable.  Raises if it's not a
      # literal.
      #
      # Supported literals: String, boolean, integers and floating-types.
      def parse(literal : String)
        if literal.starts_with?('"')
          string_literal(literal)
        elsif literal == "true"
          true
        elsif literal == "false"
          false
        elsif match = NUMERIC_RX.match(literal)
          number_literal(match[1].not_nil!, match[2].not_nil!)
        else
          raise "Can't parse C++ literal #{literal.inspect}"
        end
      end

      private def number_literal(value, type_hint)
        case type_hint
        when ""
          if value.includes?('.') || value.includes?('e')
            value.to_f64
          else
            value.to_i32
          end
        when "f"
          value.to_f32
        when "L" # Assume non-Windows!
          value.to_i32
        when "LL"
          value.to_i64
        when "U"
          value.to_u32
        when "UL" # Assume non-Windows!
          value.to_u32
        when "ULL"
          value.to_u64
        else
          raise "Unreachable"
        end
      end

      # Interprets *literal* as C/C++ string literal.
      # Supports `"simple"` and `"spl" "it"` literals.
      def string_literal(literal : String) : String
        in_string = false
        special_char = false

        String.build do |b|
          literal.each_char do |char|
            is_special = special_char
            special_char = false

            case { is_special, char }
            when { false, '"' }
              in_string = !in_string
            when { true, 't' }
              b << '\t'
            when { true, 'r' }
              b << '\r'
            when { true, 'n' }
              b << '\n'
            when { true, 'v' }
              b << '\v'
            when { true, '\\' }
              b << '\\'
            when { false, '\\' }
              special_char = true # Escape sequence!
            else
              b << char if in_string
            end
          end
        end
      end
    end
  end
end
