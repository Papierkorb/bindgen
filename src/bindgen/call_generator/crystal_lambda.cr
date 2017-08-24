module Bindgen
  module CallGenerator
    # Generates a Crystal stabby-lambda, calling the *wrapper* from *binding*.
    # The call is expected to go from C++-land to Crystal-land.
    class CrystalLambda
      include CrystalMethods

      def initialize(@db : TypeDatabase)
      end

      # Generates the lambda, calling from *binding* to *wrapper*.  If *wrap* is
      # `true`, the whole lambda will be encapsulated by a helper turning the
      # proc into a `CrystalProc`, ready to be passed on to *binding*.
      def generate(binding : Call, wrapper : Call, wrap = false) : String
        cpp_func_args, cpp_pass_args = crystal_arguments(binding)
        cr_func_args, cr_pass_args = crystal_arguments(wrapper)

        body = invocation({ wrapper, binding }, cpp_pass_args)
        code = "->(#{cpp_func_args.join(", ")}){ #{body} }"
        code = "BindgenHelper.wrap_proc(#{code})" if wrap
        code
      end
    end
  end
end
