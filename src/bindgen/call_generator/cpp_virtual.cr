module Bindgen
  module CallGenerator
    # Generator for a C++ `virtual` method, overloading it.
    # The result is to be used inside a C++ `class` (Or `struct`), inheriting
    # from the type the override should happen on.
    class CppVirtual
      include CppMethods

      # Generates the override method.
      #
      # Assumes `CallAnalyzer::CppToCpp` for *cpp*, and
      # `CallAnalyzer::CppToCrystalProc` for *crystal*.
      #
      # Does a run-time check if the *crystal* override is set.
      # If it is, it's taken, else a fall-back to the C++ implementation of the
      # base-class occurs.
      def generate(crystal : Call, cpp : Call) : String
        method = crystal.origin
        cpp_func_args, cpp_pass_args = cpp_arguments(cpp, false)
        cr_func_args, cr_pass_args = cpp_arguments(crystal, false)
        type = cpp_typename(cpp.result)

        cpp_invoc = invocation(cpp, cpp_pass_args)
        cr_invoc = invocation(crystal, cr_pass_args)
        infix = "const " if method.const? # Support RHS-const

        String.build do |b|
          b << %[  virtual #{type} #{method.name}(#{cpp_func_args.join(", ")}) #{infix}override {\n]

          if method.pure?
            b << %[    return #{cr_invoc};\n]
          else
            b << %[    if (#{crystal.name}.isValid()) {\n]
            b << %[      return #{cr_invoc};\n]
            b << %[    } else {\n]
            b << %[      return #{cpp_invoc};\n]
            b << %[    }\n]
          end

          b << %[  }]
        end
      end
    end
  end
end
