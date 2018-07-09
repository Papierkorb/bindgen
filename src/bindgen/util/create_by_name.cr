module Bindgen
  module Util
    # Adds a `create_by_name` factory method to the target module.  The `T` type
    # is expected to be the base-class type.  The possible classes are found at
    # compile-time using macro code.
    #
    # Note: `extend` this module!
    module CreateByName(T)
      # Factory method, creating the right sub-class of `T` by *name*.  If no
      # class is found, raises.
      def create_by_name(error_kind, name : String, *arguments) : T
        {% begin %}
          case name.underscore
              {% for klass in T.all_subclasses %}
              # Check for all subclasses of `Base` by the de-modulized, underscored name.
              when {{ klass.name.stringify.gsub(/.*::/, "").underscore }}
                {{ klass }}.new(*arguments)
              {% end %}
          else
            raise "Unknown #{error_kind} #{name.inspect}"
          end
        {% end %}
      end
    end
  end
end
