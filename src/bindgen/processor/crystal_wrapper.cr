module Bindgen
  module Processor
    # Processor to generate a Crystal wrapper for a crystal binding.
    # `CrystalBinding` must be run beforehand.
    #
    # **Important**: This should be one of the last processors in the pipeline!
    class CrystalWrapper < Base
      PLATFORM = Graph::Platform::Crystal

      def visit_platform_specific(specific)
        super if specific.platform == PLATFORM
      end

      def visit_class(klass)
        if klass.base_class.nil? # The parent class already has the `@unwrap`
          unwrap = add_unwrap_variable(klass)
          add_to_unsafe_method(klass, unwrap)
        end

        super
      end

      private def add_unwrap_variable(klass) : Call::Result
        pass = Crystal::Pass.new(@db)
        typer = Crystal::Typename.new(@db)

        ptr = klass.structure ? 0 : 1 # Store as value if structure is copied.
        type = klass.origin.as_type(pointer: ptr)

        klass.instance_variables["unwrap"] ||= Call::Result.new(
          type: type,
          type_name: typer.qualified(*typer.binding(type)),
          pointer: ptr,
          reference: false,
          conversion: nil,
        )
      end

      private def add_to_unsafe_method(klass, unwrap)
        to_unsafe = CallBuilder::CrystalToUnsafe.new(@db)
        call = to_unsafe.build(klass.origin, unwrap.pointer < 1)

        host = Graph::PlatformSpecific.new(platform: PLATFORM, parent: klass)
        graph = Graph::Method.new(origin: call.origin, name: call.name, parent: host)
        graph.calls[PLATFORM] = call
      end

      def visit_method(method)
        return if method.calls[PLATFORM]?

        klass_type = nil
        if (klass = method.parent).is_a?(Graph::Class)
          klass_type = klass.origin.as_type
        end

        call = CallBuilder::CrystalBinding.new(@db)
        wrapper = CallBuilder::CrystalWrapper.new(@db)
        target = call.build(method.origin, klass_type, CallBuilder::CrystalBinding::InvokeBody)
        method.calls[PLATFORM] = wrapper.build(method.origin, target)
      end
    end
  end
end
