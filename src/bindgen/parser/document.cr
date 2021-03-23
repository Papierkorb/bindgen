require "./enum"

module Bindgen
  module Parser
    # Document as returned by the clang tool.
    class Document
      include JSON::Serializable

      getter enums : Enum::Collection
      getter classes : Class::Collection
      getter macros : Macro::Collection
      getter functions : Method::Collection = Method::Collection.new

      # For testing purposes.
      def initialize(
        @enums = Enum::Collection.new,
        @classes = Class::Collection.new,
        @macros = Macro::Collection.new,
        @functions = Method::Collection.new
      )
      end
    end
  end
end
