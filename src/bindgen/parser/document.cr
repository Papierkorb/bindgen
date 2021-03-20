require "./enum"

module Bindgen
  module Parser
    # Document as returned by the clang tool.
    class Document
      include JSON::Serializable

      property enums : Enum::Collection
      property classes : Class::Collection
      property macros : Macro::Collection
      property functions : Method::Collection = Method::Collection.new
      
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
