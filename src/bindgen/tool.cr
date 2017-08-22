module Bindgen
  # Front-end tool class
  class Tool
    getter database : TypeDatabase

    def initialize(@config : Configuration)
      @database = TypeDatabase.new(@config.types)

      # Add enum types to the db
      @config.enums.each do |cpp_name, crystal_name|
        @database.add_sparse_type cpp_name, crystal_name, Parser::Type::Kind::Enum
      end

      # Add classes too
      @config.classes.each do |cpp_name, crystal_name|
        @database.add_sparse_type cpp_name, crystal_name, Parser::Type::Kind::Class
      end
    end

    # Runs the tool.
    def run!
      # 1. Run the parser
      document = parse_cpp_sources
      @database.enums.merge!(document.enums)

      # 2. Generate CPP code
      generate_cpp_wrapper(document.classes)

      # 3. Generate Crystal code
      generate_crystal_wrapper(document)

      # 4. Build C++ code
      run_cpp_build_step
    end

    # Runs the build step defined in `Configuration::Output#cpp_build` to build
    # the generated C++ code project.
    private def run_cpp_build_step
      command = @config.output.cpp_build
      return if command.nil?

      Dir.cd(File.dirname @config.output.cpp) do
        unless system(command)
          STDERR.puts "CPP build step failed!"
          STDERR.puts "  Directory: #{Dir.current}"
          STDERR.puts "  Command: #{command}"
          exit 2
        end
      end
    end

    # Generates a `Parser::Document` from the given configuration and C/C++
    # header files.
    private def parse_cpp_sources
      parser = Parser::Runner.new(@config.classes.keys, @config.enums.keys, @config.parser)
      parser.run_and_parse
    end

    # Generates the C++ wrapper file.
    private def generate_cpp_wrapper(classes)
      File.open(@config.output.cpp, "w") do |handle|
        gen = CppGenerator.new(@database, handle)
        gen.print_header

        @config.parser.files.each do |path|
          gen.add_include path
        end

        gen.print @config.output.cpp_preamble
        classes.each do |_, klass|
          gen.add_class klass
        end

        @config.containers.each do |container|
          gen.add_container container
        end

        gen.emit_all_methods
      end
    end

    # Generates the Crystal wrapper file.
    private def generate_crystal_wrapper(document)
      File.open(@config.output.crystal, "w") do |handle|
        gen = CrystalGenerator.new(@database, handle)

        gen.block "module", @config.module do
          gen.print GlueReader.read

          @config.containers.each do |container|
            gen.add_container container
          end

          document.enums.each do |_, enumeration|
            gen.add_enumeration enumeration
          end

          document.classes.each do |_, klass|
            gen.add_class klass
          end

          gen.lib_block "Binding", ld_flags do
            gen.emit_bindings
          end

          gen.emit_wrappers
        end
      end
    end

    # Returns the ld_flags for the `lib Binding` block.
    private def ld_flags : String?
      haystack = @config.library
      return if haystack.nil?

      depth = File.dirname(@config.output.crystal).count('/') + 1
      project_dir = ([ ".." ] * depth).join("/")

      Util.template(haystack, "\#{__DIR__}/#{project_dir}")
    end
  end
end
