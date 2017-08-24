module Bindgen
  module CallGenerator
    # Generator for a Crystal wrapper method, calling out to the binding.
    class CrystalWrapper
      include CrystalMethods

      def initialize(@db : TypeDatabase)
      end

      # Generates a method calling from *wrapper* to the *binding*.
      def generate(wrapper : Call, binding : Call, ctor_body : String?) : String
        if wrapper.origin.any_constructor?
          generate_constructor(wrapper, binding, ctor_body)
        else
          generate_method(wrapper, binding)
        end
      end

      # Generates a method (Which is not a constructor)
      def generate_method(wrapper : Call, binding : Call) : String
        generate(wrapper, binding) do |pass_args|
          invocation({ binding, wrapper }, pass_args)
        end
      end

      # Generates a constructor, embedding the *ctor_body* in the `#initialize`
      # method.
      def generate_constructor(wrapper : Call, binding : Call, ctor_body : String?) : String
        generate(wrapper, binding) do |pass_args|
          String.build do |b|
            b << "unwrap = " << invocation({ binding, wrapper }, pass_args) << "\n"
            b << "@unwrap = unwrap\n"
            b << ctor_body if ctor_body
          end
        end
      end

      # Yielding version:  Generates the wrapper for *wrapper* to *binding*,
      # but yields the `pass_args` (The argument-list to pass on).  The block
      # is expected to return the methods body.
      def generate(wrapper : Call, binding : Call) : String
        method_args, _ = crystal_arguments(wrapper, with_defaults: true)
        _, pass_args = crystal_arguments(binding)
        result_type = crystal_typename(wrapper.result)

        String.build do |b|
          b << method_type(wrapper.origin, is_abstract: false) << " "
          b << wrapper.name << "(#{method_args.join(", ")})"
          b << " : #{result_type}" unless wrapper.origin.any_constructor?
          b << "\n"
          b << "  #{yield pass_args}\n"
          b << "end"
        end
      end
    end
  end
end
