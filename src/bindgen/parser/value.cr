module Bindgen
  module Parser
    alias DefaultValueTypes = Bool | UInt64 | Int64 | Float64 | String | Nil

    # Reads a `DefaultValueTypes`, while trying to retain as much original
    # information as possible.
    module ValueConverter
      def self.from_json(pull)
        case pull.kind
        when :null
          pull.read_null
        when :int
          # HACK: The pull parser can't distinguish Int64 from UInt64 by itself.
          integer = pull.read_int
          if pull.raw_value.starts_with?('-')
            integer.to_i64
          else
            integer.to_u64
          end
        when :float
          pull.read_float
        when :bool
          pull.read_bool
        when :string
          pull.read_string
        else
          raise "Unexpected JSON kind #{pull.kind.inspect}"
        end
      end

      def self.to_json(builder, value)
        value.to_json(builder)
      end
    end
  end
end
