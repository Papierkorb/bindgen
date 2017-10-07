module Bindgen
  module Parser
    alias DefaultValueTypes = Bool | UInt64 | Int64 | Float64 | String | Nil

    # Reads a `DefaultValueTypes`, while trying to retain as much original
    # information as possible.
    module ValueConverter
      def self.from_json(pull)
        if pull.kind == :null
          pull.read_null
        elsif value = pull.read?(UInt64)
          value
        elsif value = pull.read?(Int64)
          value
        elsif value = pull.read?(Float64)
          value
        elsif (value = pull.read?(Bool)) != nil
          value
        elsif value = pull.read?(String)
          value
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
