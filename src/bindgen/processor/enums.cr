module Bindgen
  module Processor
    # Adds enumerations to the graph.
    class Enums < Base
      def process(graph : Graph::Node, doc : Parser::Document)
        doc.enums.each do |name, enumeration|
          config = @config.enums[name]
          add_enum(graph, config, enumeration)
        end
      end

      # Adds *enumeration* according to *config* into the *root*.
      private def add_enum(root, config, enumeration)
        builder = Graph::Builder.new(@db)
        origin = reconfigure_enum(config, enumeration)

        builder.build_enum(origin, config.destination, root)
      end

      # Reconfigures *enumeration* according to the users *config*.
      private def reconfigure_enum(config, enumeration : Parser::Enum) : Parser::Enum
        is_flags = config.flags.get(enumeration.flags?)
        fields = remove_key_prefix(config.prefix, enumeration.values)

        Parser::Enum.new(
          name: enumeration.name,
          type: enumeration.type, # Make configurable?
          isFlags: is_flags,
          values: camelcase_fields(config, fields),
        )
      end

      # CamelCases all field names, if they're not already camel-cased.
      private def camelcase_fields(config, fields)
        fields.map do |key, value|
          if config.camelcase
            unless key[0]?.try(&.uppercase?) && key[1]?.try(&.lowercase?)
              key = key.downcase.camelcase
            end
          else
            if key[0]?.try(&.lowercase?)
              key = key.capitalize
            end
          end

          { key, value }
        end.to_h
      end

      # Removes the common *prefix* from all *fields*.  If *prefix* is `true`,
      # finds the common prefix of *fields* automatically.
      private def remove_key_prefix(prefix : String | Bool, fields)
        return fix_constant_names(fields) if prefix == false

        if prefix == true # Auto prefix detection
          prefix = Util::Prefix.common(fields.keys)
          return fields if prefix == 0
        end

        remove_hash_key_prefix(prefix.as(Int32 | String), fields)
      end

      # Removes the first *prefix* characters from each key in *hash*.
      private def remove_hash_key_prefix(prefix : Int32, hash)
        transform_keys_unique(hash) do |key|
          key[prefix..-1]
        end
      end

      # Removes the *prefix* of each key in *hash*, but only for those key
      # starting with *prefix*.
      private def remove_hash_key_prefix(prefix : String, hash)
        transform_keys_unique(hash) do |key|
          if key.starts_with?(prefix)
            key[prefix.size..-1]
          else
            key
          end
        end
      end

      # Yields all keys in *hash* and returns a new hash with the yield
      # returned new keys.  Keys are tracked to make sure they're unique.
      # Keys are afterwards sent through `#fixed_constant_name`.
      private def transform_keys_unique(hash : Hash(K, _)) forall K
        seen = Hash(K, Int32).new(default_value: 0)

        hash.map do |key, value|
          key = fixed_constant_name(yield(key))

          count = (seen[key] += 1)
          key = "#{key}_#{count}" if count > 1 # Make sure keys are unique

          { key, value }
        end.to_h
      end


      private def fixed_constant_name(key : String) : String
        if key.empty?
          "Unnamed"
        elsif key[0].number?
          "Digit#{key}"
        elsif key[0] == '_'
          "Underscore#{key[1..-1]}"
        else
          key
        end
      end

      # Maps the keys in *hash* using `#fixed_constant_name`.
      private def fix_constant_names(hash)
        # Will fix the name by itself.
        transform_keys_unique(hash, &.itself)
      end
    end
  end
end
