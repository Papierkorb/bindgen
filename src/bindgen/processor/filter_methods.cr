module Bindgen
  module Processor
    # Processor removing methods that are to be ignored.  Also performs fix-ups
    # on certain methods.
    #
    # Right now, methods can be ignored by any of:
    # 1. Ignoring a type the method uses as argument or result type
    # 2. By adding the name to `type.CLASS.ignore_methods`
    # 3. Methods using anonymous types are always ignored
    #
    # The fix-ups include:
    # 1. Removing the integer arguments of overloaded post-increment and
    #    post-decrement operators.
    class FilterMethods < Base
      include Graph::Visitor::MayDelete

      # Looks up a class by its name.
      private def class_by_name?(name : String) : Parser::Class?
        @db[name]?.try(&.graph_node).as?(Graph::Class).try(&.origin)
      end

      def visit_method(method : Graph::Method)
        m = method.origin
        host = method.parent

        # Rule 1: Ignored types
        remove = m.filtered?(@db)

        # Rule 2: Explicitly ignored method
        if ignored = @db[m.class_name]?.try(&.ignore_methods)
          remove ||= ignored.includes?(m.name)
        end

        # Rule 3: Anonymous types
        remove ||= type_ignored?(m.class_name)
        remove ||= type_ignored?(m.return_type)
        remove ||= m.arguments.any? { |arg| type_ignored?(arg) }

        # Rule 4: Fix-ups
        if !remove
          fixed = m.fix_up?
          remove ||= !fixed.nil?
        end

        # Remove if ignored
        remove_method(method) if remove

        # Insert the new method if fix-up is required
        if fixed
          Graph::Method.new(
            origin: fixed,
            name: method.name,
            parent: host,
          )
        end
      end

      # Removes the *method* from its parent.
      private def remove_method(method)
        parent = method.parent.as(Graph::Container)
        parent.nodes.delete method
      end

      # Checks if *type* is ignored.
      private def type_ignored?(type) : Bool
        @db.try_or(type, false) { |config| config.ignore? || config.anonymous? }
      end
    end
  end
end
