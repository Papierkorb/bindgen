module Bindgen
  module Processor
    # Processor to wrap C++ as C `"extern"` functions.
    #
    # **Important**: This should be one of the last processors in the pipeline!
    class CppWrapper < Base
      PLATFORM = Graph::Platform::Cpp

      def visit_platform_specific(specific)
        super if specific.platform == PLATFORM
      end

      def visit_method(method)
        return if method.calls[PLATFORM]?

        klass = method.parent_class # Skip constructors on abstract class without shadow-subclass.
        return if klass.try(&.origin.abstract?) && method.origin.any_constructor? && !klass.try(&.cpp_sub_class)

        call = CallBuilder::CppCall.new(@db)
        wrapper = CallBuilder::CppWrapper.new(@db)
        target = call.build(method.origin)

        method.calls[PLATFORM] = wrapper.build(
          method: method.origin,
          class_name: method.origin.class_name,
          target: target,
        )
      end
    end
  end
end
