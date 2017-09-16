module Bindgen
  # Front-end tool class
  class Tool
    # Dummy error that can be thrown by a class to exit out of the tool.
    class ExitError < Exception
      # The exit code to signal.
      getter code : Int32

      def initialize(message = "Internal error", @code = 1)
        super(message)
      end
    end

    getter database : TypeDatabase

    # Path to the projects root, commonly the directory the YAML configuration
    # file is contained in.
    getter root_path : String

    def initialize(@root_path : String, @config : Configuration, @show_stats = false)
      @database = TypeDatabase.new(@config.types)

      # Add enum types to the db
      @config.enums.each do |cpp_name, crystal_name|
        @database.add_sparse_type cpp_name, crystal_name, Parser::Type::Kind::Enum
      end

      # Add classes too
      @config.classes.each do |cpp_name, crystal_name|
        @database.add_sparse_type cpp_name, crystal_name, Parser::Type::Kind::Class
      end

      # Build pipelines
      @processors = Processor::Runner.new(@config, @database)
      @generators = Generator::Runner.new(@config, @database)
    end

    # Runs the tool.  Returns the process exit code.
    def run! : Int32
      stats = run_steps

      if @show_stats
        puts "Timing statistics:"
        puts stats.to_s(depth: 1)
        puts "  Total time: #{stats.total_duration}"
      end

      0 # Success!
    rescue err : ExitError
      err.code # Failure
    end

    # Runs all steps in the tool, measuring each steps timings.
    private def run_steps : Statistics
      stats = Statistics.new

      document = stats.measure("Parse C++"){ parse_cpp_sources }
      graph = stats.measure("Build graph"){ build_graph(document) }

      stats.measure("Processors"){ @processors.process(graph, document) }
      stats.measure("Generators"){ @generators.process(graph) }

      stats
    end

    private def build_graph(document)
      builder = Graph::Builder.new(@database)
      graph = Graph::Namespace.new(@config.module, nil)
      builder.build_document(document, graph)

      Graph::Library.new( # Add `lib Binding`
        name: Graph::LIB_BINDING,
        parent: graph,
        ld_flags: templated_ld_flags,
      )

      graph
    end

    # Generates a `Parser::Document` from the given configuration and C/C++
    # header files.
    private def parse_cpp_sources
      parser = Parser::Runner.new(@config.classes.keys, @config.enums.keys, @config.parser, @root_path)
      parser.run_and_parse
    end

    # Returns the ld_flags for the `lib Binding` block.
    private def templated_ld_flags : String?
      haystack = @config.library
      return if haystack.nil?

      crystal_output = @config.generators["crystal"].output
      depth = File.dirname(crystal_output).count('/') + 1
      project_dir = ([ ".." ] * depth).join("/")

      Util.template(haystack, "\#{__DIR__}/#{project_dir}")
    end
  end
end
