module Bindgen
  module CallGenerator
    # Generates a Proc type of the call, matching the given *call*.
    class CrystalProcType
      include CrystalMethods

      def generate(call : Call) : String
        types = call.arguments.map{|arg| crystal_typename(arg)}
        types << crystal_typename(call.result)
        generate(types)
      end

      def generate(types : Enumerable(Call::Result)) : String
        generate types.map{|x| crystal_typename(x)}
      end

      def generate(types : Enumerable(String)) : String
        "Proc(#{types.join(", ")})"
      end
    end
  end
end
