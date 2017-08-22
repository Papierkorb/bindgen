module Bindgen
  module CallGenerator
    # Generates a `CrystalProc<...>` type of the call, matching the given *call*.
    class CppProcType
      include CppMethods

      def generate(call : Call) : String
        types = call.arguments.map{|arg| cpp_typename(arg)}
        types.unshift cpp_typename(call.result)
        generate(types)
      end

      def generate(types : Enumerable(Call::Result)) : String
        generate types.map{|x| crystal_typename(x)}
      end

      def generate(types : Enumerable(String)) : String
        "CrystalProc<#{types.join(", ")}>"
      end
    end
  end
end
