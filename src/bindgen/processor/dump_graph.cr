module Bindgen
  module Processor
    # Debugging processor dumping the whole graph into `STDERR`.
    class DumpGraph < Base
      def process(graph : Graph::Node, doc : Parser::Document)
        Graph::Dumper.dump(STDERR, graph)
      end
    end
  end
end
