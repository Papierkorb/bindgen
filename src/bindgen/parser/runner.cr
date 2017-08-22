module Bindgen
  module Parser
    # Runner for the Clang part.  The path can also be configured through the
    # `BINDGEN_BIN` environment variable.
    class Runner
      # Default path to the binary
      BINARY_PATH = "#{File.dirname(__FILE__)}/../../../clang/bindgen"

      def initialize(@classes : Array(String), @enums : Array(String), @config : Configuration)
        @binary_path = ENV["BINDGEN_BIN"]? || @config.binary || BINARY_PATH
      end

      # Arguments for the tool binary
      def arguments(input_file)
        classes = @classes.flat_map{|x| [ "-c", "#{x}" ] }
        enums = @enums.flat_map{|x| [ "-e", "#{x}" ] }
        flags = @config.flags
        defines = @config.defines.map{|x| "-D#{x}"}
        includes = @config.includes.map{|x| "-I#{x}"}

        [ input_file ] + classes + enums + [ "--" ] + flags + defines + includes
      end

      # Calls the clang tool and returns its output as string
      def run : String
        generate_source_file do |file|
          command = "#{@binary_path} #{arguments(file).join(" ")}"
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
            file.puts %{#include #{path.inspect}}
          end

          file.flush
          result = yield file.path
        end

        result.not_nil!
      end
    end
  end
end
