module Bindgen
  module CallGenerator
    # Generator for an abstract Crystal wrapper method, there to tell the user
    # about it and make the compiler enforce abstract-safety.
    class CrystalAbstractWrapper
      include CrystalMethods

      def initialize(@db : TypeDatabase)
      end

      # Method is API compatible to `CrystalWrapper#generate`.
      def generate(wrapper : Call, _binding = nil, _body = nil) : String
        method_args, _ = crystal_arguments(wrapper)
        result_type = crystal_typename(wrapper.result)

        String.build do |b|
          b << method_type(wrapper.origin, is_abstract: true) << " "
          b << wrapper.name << "(#{method_args.join(", ")})"
          b << " : #{result_type}"
        end
      end
    end
  end
end
