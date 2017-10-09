module Bindgen
  module Processor
    # A processor setting up copied macro definitions.
    class Macros < Base
      include Util::FindMatching(Parser::Macro)

      def process(graph : Graph::Node, doc : Parser::Document)
        @config.macros.each do |regex, config|
          list = find_matching(regex, doc.macros)
          handle_macros(graph, config, list)
        end
      end

      private def handle_macros(root, config, macros)
        case config.map_as
        when .enum?
          create_enum(root, config, macros)
        when .constant?
          create_constants(root, config, macros)
        else
          raise "BUG: Missing case in #handle_macros"
        end
      end

      # Adds the enum described in *config* to the graph, using *macros* as
      # values.
      private def create_enum(root, config, macros)
        builder = Graph::Builder.new(@db)
        path = Graph::Path.from(config.destination)

        # Traverse, create missing namespaces on the way.
        parent, local_name = builder.parent_and_local_name(root, path)

        Graph::Enum.new(
          name: local_name,
          parent: parent,
          origin: build_enum(config, macros, local_name),
        )
      end

      # Adds all *macros* into the graph.
      private def create_constants(root, config, macros)
        type = Crystal::Type.new(@db)
        builder = Graph::Builder.new(@db)
        path = Graph::Path.from(config.destination)
        parent = builder.get_or_create_path(root, path).as(Graph::Container)
        host = parent.platform_specific(Graph::Platform::Crystal)

        macros.each do |define, match|
          next if define.function?
          name = Util.pattern_rewrite(config.name, match).underscore.upcase
          value = type.convert(define.evaluated, define.type.not_nil!)

          next if value.nil?

          Graph::Constant.new(
            name: name,
            value: value,
            parent: host,
          )
        end
      end

      # Builds an enumeration type out of *config* and *macros*.
      private def build_enum(config, macros, name) : Parser::Enum
        values = { } of String => Int64

        macros.each do |define, match|
          name = Util.pattern_rewrite(config.name, match).downcase.camelcase
          value = define.evaluated

          unless value.is_a? Int
            raise "Macro enum #{config.destination}: Value for #define #{define.name} is non-Int: #{value.inspect}"
          end

          values[name] = value.to_i64
        end

        Parser::Enum.new(
          name: name,
          values: values,
          type: config.type,
          isFlags: config.flags,
        )
      end
    end
  end
end
