module Bindgen
  spoved_logger

  # Front-end tool class
  class Tool
    spoved_logger

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
      logger.info &.emit "new bindgen tool", root_path: @root_path, show_stats: @show_stats

      @database = TypeDatabase.new(@config.types, @config.cookbook)

      # Add enum types to the db
      @config.enums.each do |cpp_name, crystal_name|
        @database.add_sparse_type cpp_name, crystal_name.destination, Parser::Type::Kind::Enum
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
      print_stats(stats) if @show_stats
      logger.info { "success!" }
      0 # Success!


    rescue err : ExitError
      logger.error(exception: err) { err.message }
      err.code # Failure
    rescue ex
      logger.error(exception: ex) { ex.message }
      1
    end

    private def print_stats(stats)
      gc = GC.stats

      puts stats.to_s(depth: 1)
      puts "  Total time: #{stats.total_duration}"
      puts "  Heap size : #{Util.format_bytes gc.heap_size}"
    end

    # Runs all steps in the tool, measuring each steps timings.
    private def run_steps : Statistics
      stats = Statistics.new

      logger.info { "find paths" }
      if path_config = @config.find_paths
        stats.measure("Find paths") { find_paths(path_config) }
      end

      logger.info { "Parse C++" }
      document = stats.measure("Parse C++") { parse_cpp_sources }

      logger.info { "Build graph" }
      graph = stats.measure("Build graph") { build_graph(document) }

      logger.info { "Processors" }
      stats.measure("Processors") { @processors.process(graph, document) }

      logger.info { "Generators" }
      stats.measure("Generators") { @generators.process(graph) }

      stats.finish!
    end

    # Finds all paths per the user configuration.
    private def find_paths(config)
      finder = FindPath.new(root: @root_path, variables: ENV)
      errors = finder.find_all!(config)
      dump_find_path_errors(errors)
    end

    # Prints all find_path errors to the screen.
    private def dump_find_path_errors(errors)
      fatal = false

      errors.each do |error|
        if error.config.optional
          puts "Failed to find optional path for #{error.variable}"
        else
          puts "Failed to find mandatory path for #{error.variable}".colorize.mode(:bold)
          fatal = true # Bail later
        end

        if message = error.config.error_message
          puts "  " + message.split("\n").join("\n  ")
        end
      end

      if fatal
        raise ExitError.new("Didn't find all mandatory paths", 1)
      end
    end

    # Builds the initial graph from *document*.
    private def build_graph(document)
      builder = Graph::Builder.new(@database)
      graph = Graph::Namespace.new(@config.module, nil)

      # Add `lib Binding`
      Graph::Library.new(
        name: Graph::LIB_BINDING,
        parent: graph,
        ld_flags: templated_ld_flags,
      )

      builder.build_document(document, graph)
      graph
    end

    # Generates a `Parser::Document` from the given configuration and C/C++
    # header files.
    private def parse_cpp_sources
      parser = Parser::Runner.new(
        classes: @config.classes.keys,
        enums: @config.enums.keys,
        macros: @config.macros.keys,
        functions: @config.functions.keys,
        config: @config.parser,
        project_root: @root_path,
      )

      parser.run_and_parse
    end

    # Returns the ld_flags for the `lib Binding` block.
    private def templated_ld_flags : String?
      haystack = @config.library
      return if haystack.nil?

      crystal_output = @config.generators["crystal"].output
      depth = File.dirname(crystal_output).count('/') + 1
      project_dir = ([".."] * depth).join("/")

      Util.template(haystack, "\#{__DIR__}/#{project_dir}")
    end
  end
end
