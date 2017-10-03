module Bindgen
  module Parser
    # Document as returned by the clang tool.
    class Document
      JSON.mapping(
        enums: Enum::Collection,
        classes: Class::Collection,
        macros: Macro::Collection,
        functions: {
          type: Method::Collection,
          default: Method::Collection.new,
        },
      )
    end
  end
end
