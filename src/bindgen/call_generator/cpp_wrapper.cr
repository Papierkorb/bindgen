module Bindgen
  module CallGenerator
    # Generates a `extern "C"` function delegating to the `Call` from Crystal to
    # C++.
    class CppWrapper
      include CppMethods

      # Generates a wrapper function to *call*.
      def generate(call : Call) : String
        generate(call) do |pass_args|
          invocation(call, pass_args)
        end
      end

      # Generates a function for *call*, but yields the pass-arguments so an
      # external entity can fill in the method body.
      def generate(call : Call) : String
        func_args, pass_args = cpp_arguments(call, call.origin.needs_instance?)
        type = cpp_typename(call.result)

        String.build do |b|
          b << %[extern "C" #{type} #{call.origin.mangled_name}(#{func_args.join(", ")}) {\n]
          b << %[  return #{yield pass_args};\n]
          b << %[}\n\n]
        end
      end
    end
  end
end
