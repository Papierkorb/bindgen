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
          values: camelcase_fields(fields),
        )
      end

      # CamelCases all field names, if they're not already camel-cased.
      private def camelcase_fields(fields)
        fields.map do |key, value|
          unless key[0]?.try(&.uppercase?) && key[1]?.try(&.lowercase?)
            key = key.downcase.camelcase
          end

          { key, value }
        end.to_h
      end

      # Removes the common *prefix* from all *fields*.  If *prefix* is `true`,
      # finds the common prefix of *fields* automatically.
      private def remove_key_prefix(prefix : String | Bool, fields)
        return fields if prefix == false

        if prefix == true # Auto prefix detection
          prefix = Util::Prefix.common(fields.keys)
          return fields if prefix == 0
        end

        remove_hash_key_prefix(prefix.as(Int32 | String), fields)
      end

      private def remove_hash_key_prefix(prefix : Int32, hash)
        hash.map do |key, value|
          { key[prefix..-1], value }
        end.to_h
      end

      private def remove_hash_key_prefix(prefix : String, hash)
        hash.map do |key, value|
          key = key[prefix.size..-1] if key.starts_with?(prefix)

          { key, value }
        end.to_h
      end
    end
  end
end
