module Bindgen
  module Processor
    # Runner for the processor pipeline.
    #
    # Note: This is *not* a processor by itself!
    class Runner
      @processors : Array(Base)

      def initialize(config : Configuration, db : TypeDatabase)
        @processors = config.processors.map do |name|
          Processor.create_by_name(Processor::ERROR_KIND, name, config, db).as(Processor::Base)
        end
      end

      # Processes the *graph*.
      def process(graph : Graph::Node, doc : Parser::Document)
        stats = Statistics.new

        @processors.each do |instance|
          stat_name = instance.class.name.sub(/.*::/, "").underscore
          stats.measure(stat_name){ instance.process(graph, doc) }
        end

        stats
      end
    end
  end
end
