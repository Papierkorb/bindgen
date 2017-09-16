module Bindgen
  module Processor
    # Processor removing methods that are to be ignored.
    #
    # Right now, methods can be ignored by any of:
    # 1. Ignoring a type the method uses as argument or result type
    # 2. By adding the name to `type.CLASS.ignore_methods`
    class FilterMethods < Base
      def visit_method(method : Graph::Method)
        m = method.origin

        # Rule 1: Ignored types
        remove = m.filtered?(@db)

        # Rule 2: Explicitly ignored method
        if ignored = @db[m.class_name]?.try(&.ignore_methods)
          remove ||= ignored.includes?(method.name)
        end

        # Remove if ignored
        remove_method(method) if remove
      end

      # Removes the *method* from its parent.
      private def remove_method(method)
        parent = method.parent.as(Graph::Container)
        parent.nodes.delete method
      end

      # Checks if *type* is ignored.
      private def type_ignored?(type) : Bool
        @db.get_or(type, false, &.ignore?)
      end
    end
  end
end
