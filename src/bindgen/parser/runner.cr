module Bindgen
  module Parser
    # Runner for the Clang part.  The path can also be configured through the
    # `BINDGEN_BIN` environment variable.
    class Runner
      # Default path to the binary
      BINARY_PATH = "#{File.dirname(__FILE__)}/../../../clang/bindgen"

      @binary_path : String

      # *project_root* must be a path to the directory the configuration YAML
      # resides.
      def initialize(@classes : Array(String), @enums : Array(String), @config : Configuration, @project_root : String)
        @binary_path = ENV["BINDGEN_BIN"]? || @config.binary || BINARY_PATH
      end

      # Arguments for the tool binary
      def arguments(input_file)
        classes = @classes.flat_map{|x| [ "-c", "#{x}" ] }
        enums = @enums.flat_map{|x| [ "-e", "#{x}" ] }
        flags = @config.flags
        defines = @config.defines.map{|x| "-D#{x}"}
        includes = template_include_paths.map{|x| "-I#{x}"}

        [ input_file ] + classes + enums + [ "--" ] + flags + defines + includes
      end

      # Calls the clang tool and returns its output as string.
      def run : String
        generate_source_file do |file|
          binary_path = Util.template(@binary_path, replacement: nil)
          command = "#{binary_path} #{arguments(file).join(" ")}"
          puts "Runner command: #{command}" if ENV["VERBOSE"]?

          result = `#{command}`
          raise "clang/bindgen failed to execute." unless $?.success?
          result
        end
      end

      # Calls the clang tool and directly parses its output
      def run_and_parse : Document
        Document.from_json(run)
      end

      # Generates a dummy C++ header file, which `#include`s all given files
      private def generate_source_file
        result = nil

        Tempfile.open("bindgen") do |file|
          @config.files.each do |path|
            path = Util.template(path, replacement: nil)
            file.puts %{#include #{path.inspect}}
          end

          file.flush
          result = yield file.path
        end

        result.not_nil!
      end

      # Returns the `-I` paths with template expansion to the project root.
      private def template_include_paths
        @config.includes.map do |path|
          Util.template(path, @project_root)
        end
      end
    end
  end
end
