module Bindgen
  module Processor
    # A processor setting up copied macro definitions.
    class Macros < Base
      # Finds back-references
      BACKREF_RX = /\\(\d)/

      def process(graph : Graph::Node, doc : Parser::Document)
        @config.macros.each do |regex, config|
          list = find_matching_macros(regex, doc.macros)
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
        parser = Cpp::LiteralParser.new
        builder = Graph::Builder.new(@db)
        path = Graph::Path.from(config.destination)
        parent = builder.get_or_create_path(root, path).as(Graph::Container)
        host = parent.platform_specific(Graph::Platform::Crystal)

        macros.each do |define, match|
          name = define_name(config, match).underscore.upcase
          value = parser.parse(define.value)

          Graph::Constant.new(
            name: name,
            value: value,
            parent: host,
          )
        end
      end

      # Builds an enumeration type out of *config* and *macros*.
      private def build_enum(config, macros, name) : Parser::Enum
        parser = Cpp::LiteralParser.new
        values = { } of String => Int64

        macros.each do |define, match|
          name = define_name(config, match).downcase.camelcase
          value = parser.parse(define.value)

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

      # Builds the name for *config* and its *match*.  The name is unprocessed
      # otherwise.
      private def define_name(config, match) : String
        if name = config.name
          name.gsub(BACKREF_RX) do |_, m| # Replace `FOO_\\1` to `FOO_BAR`
            match[m[1].to_i]
          end
        else # Default: Prefer first explicit capture-group, fall back to whole match
          match[1]? || match[0]
        end
      end

      # Finds all elements in *macros* matching the *regex*.
      private def find_matching_macros(regex, macros)
        rx = /^#{regex}$/

        matching = [ ] of { Parser::Macro, Regex::MatchData }
        macros.each do |define|
          next if define.function?

          if match = rx.match(define.name)
            matching << { define, match }
          end
        end

        matching
      end
    end
  end
end
