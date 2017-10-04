require "./crystal"
require "./processor/base"
require "./util/*"
require "./parser/*"
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

    # Default processor pipeline.  Used by `Configuration#processors`.
    DEFAULT_CHAIN = [
      # Graph-refining processors:
      "default_constructor",
      "function_class",
      "inheritance",
      "copy_structs",
      "macros",
      "functions",
      "filter_methods",
      # "auto_container_instantiation", # Not stable yet
      "instantiate_containers",
      # Preliminary generation processors:
      "crystal_wrapper",
      "virtual_override",
      "cpp_wrapper",
      "crystal_binding",
      "sanity_check",
    ]

    extend CreateByName(Processor::Base)
  end
end
