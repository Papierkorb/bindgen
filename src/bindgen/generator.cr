require "./graph"
require "./generator/base"
require "./util/*"

module Bindgen
  # Contains generator classes.  A generator takes a fully proccessed
  # `Graph::Node` and generates code out of it into one or more outout files.
  #
  # To create a custom generator see `Generator::Base`.  See `Generator::Runner`
  # for the pipeline runner itself.
  module Generator
    # Kind to use for errors in `.create_by_name`
    ERROR_KIND = "generator"

    extend Util::CreateByName(Generator::Base)
  end
end
