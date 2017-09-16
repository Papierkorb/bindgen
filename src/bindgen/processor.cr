require "./crystal"
require "./processor/base"
require "./processor/*"

module Bindgen
  # Contains processor classes.  A processor operates on a `Graph::Node`, and
  # its children, subsequently transforming it as preparation for one or more
  # `Generator`s.
  #
  # To create a custom processor see `Processor::Base`.  See `Processor::Runner`
  # for the pipeline runner itself.
  module Processor
    # Kind to use for errors in `.create_by_name`
    ERROR_KIND = "processor"

    extend CreateByName(Processor::Base)
  end
end
