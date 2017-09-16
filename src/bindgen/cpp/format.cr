module Bindgen
  module Cpp
    # Formatter for C++ style code.
    struct Format
      # Formats *arg* as `type name`
      def argument(arg : Call::Argument, idx) : String
        typer = Typename.new
        "#{typer.full arg} #{Argument.name(arg, idx)}"
      end

      # Formats *arguments* as `type name, ...`
      def argument_list(arguments : Enumerable(Call::Argument)) : String
        arguments.map_with_index{|arg, idx| argument(arg, idx)}.join(", ")
      end
    end
  end
end
