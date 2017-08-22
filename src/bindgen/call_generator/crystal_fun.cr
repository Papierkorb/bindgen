module Bindgen
  module CallGenerator
    # Generates a Crystal `fun` directive.
    class CrystalFun
      include CrystalMethods

      def generate(call : Call) : String
        func_args, _ = crystal_arguments(call)
        type = crystal_typename(call.result)

        %[fun #{call.origin.mangled_name}(#{func_args.join(", ")}) : #{type}]
      end
    end
  end
end
