module Bindgen
  module Generator
    # Runner for the generator pipeline.
    #
    # Note: This is *not* a generator by itself!
    class Runner
      @generators : Array(Base)

      def initialize(config : Configuration, db : TypeDatabase)
        @generators = config.generators.map do |name, gen_config|
          Generator.create_by_name(Generator::ERROR_KIND, name, config, gen_config, db).as(Generator::Base)
        end
      end

      # Processes the *graph*.
      def process(graph : Graph::Node)
        stats = Statistics.new

        @generators.each do |instance|
          stat_name = instance.class.name.sub(/.*::/, "").underscore

          stats.measure(stat_name){ instance.write_all(graph) }
          stats.measure("#{stat_name} build") do
            run_build_step(instance.config)
          end
        end

        stats
      end

      # Runs the build-step set in *config*, if any.  If the command fails, the
      # `bindgen` process is exited.
      private def run_build_step(config)
        command = config.build
        return if command.nil?

        command = Util.template(command, replacement: nil)
        Dir.cd(File.dirname config.output) do
          unless system(command)
            STDERR.puts "Build step failed!"
            STDERR.puts "  Directory: #{Dir.current}"
            STDERR.puts "  Command: #{command}"

            raise Tool::ExitError.new
          end
        end
      end
    end
  end
end
