module Bindgen
  # Methods to format Crystal value literals.
  class CrystalLiteralFormatter
    def initialize(@db : TypeDatabase)
    end

    # Generates a literal value suitable for Crystal code, using the *value*
    # of *type_name*.  *type_name* is a completely deduced Crystal type-name.
    #
    # Returns `nil` if *type_name* is unknown (It's not built-in).  Try
    # `#qualified_enum_name` in that case if it might be an enum.
    def literal(type_name, value) : String?
      case value
      when String then value.inspect
      when Number then number_literal(type_name, value)
      when Bool
        if type_name == "Bool"
          value.to_s
        else # Special case: This is an Object with a null-pointer.
          "nil"
        end
      else
        nil
      end
    end

    # Returns the number literal of *type_name* with *value*.  The result is
    # valid a Crystal literal, and can be directly written.
    def number_literal(type_name, value) : String?
      if suffix = number_literal_suffix(type_name)
        if floating_type?(type_name)
          value = value.to_f
        else
          value = value.to_i
        end

        "#{value}#{suffix}" # TODO: Literal thousand's grouping
      end
    end

    # Returns the qualified name of *value* in the enum called *enum_name*.
    # Builds a `.flags(...)` list if the enum turns out to be a `@[Flags]`.
    def qualified_enum_name(type : Parser::Type, value : Int) : String?
      enum_type = @db.enum?(type)
      rules = @db[type]?
      return nil if enum_type.nil? || rules.nil?

      enum_name = rules.wrapper_type
      if enum_type.flags?
        "#{enum_name}#{format_flags_enum(enum_type.values, value)}"
      else
        if key = enum_type.values.key?(value)
          "#{enum_name}::#{key}"
        else
          "#{enum_name}.from_value(#{value})"
        end
      end
    end

    # Generates the flag-list of an enum.
    private def format_flags_enum(values, bitmask) : String
      names = [ ] of String

      # Find all names of all set bits in *bitmask*
      (0...64).each do |bit_idx|
        value = 1u64 << bit_idx
        next if (bitmask & value) == 0

        # Does a name exist?
        if name = values.key?(value)
          names << name
        else # There's no name, fallback!
          return ".from_value(#{bitmask})"
        end
      end

      if names.empty?
        "::None"
      else # All names found: Build a nice `.flags` list
        ".flags(#{names.join(", ")})"
      end
    end

    # Returns `true` if *type_name* is a Crystal floating-type.
    def floating_type?(type_name) : Bool
      { "Float32", "Float64" }.includes?(type_name)
    end

    # Returns the literal-suffix for Crystal code, to signify a literal
    # matching the intended *type_name*.
    #
    # If *type_name* is unknown, returns `nil`.
    def number_literal_suffix(type_name) : String?
      case type_name
      when "UInt8" then "u8"
      when "UInt16" then "u16"
      when "UInt32" then "u32"
      when "UInt64" then "u64"
      when "Int8" then "i8"
      when "Int16" then "i16"
      when "Int32" then "" # Default type, don't clutter
      when "Int64" then "i64"
      when "Float32" then "f32"
      when "Float64" then "f64"
      else
        nil
      end
    end
  end
end
