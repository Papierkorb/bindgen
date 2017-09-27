module Bindgen
  module Processor
    # Processor for `C++/Qt` specific behaviour.  This includes:
    # * Wrapping Qt signals
    # * Handle `Q_GADGET` types
    class Qt < Base
      # Type of the result of a Qt-sinal connect call.
      CONNECTION_HANDLE_TYPE = Parser::Type.parse("QMetaObject::Connection")

      # We'll remove all member methods of this name.
      QGADGET_CHECKER = "qt_check_for_QGADGET_macro"

      def visit_class(klass)
        gadget = klass.nodes.index do |node|
          node.is_a?(Graph::Method) && \
          node.origin.member_method? && \
          node.origin.name == QGADGET_CHECKER
        end

        if gadget # Get rid of this fake method!
          klass.nodes.delete_at(gadget)
        end

        super # Proceed.
      end

      def visit_method(method)
        return unless method.origin.signal?

        connector = add_connect_method(method)
        add_cpp_call(connector, method.origin)
      end

      private def add_cpp_call(connector, method)
        to_proc = CallBuilder::CppToCrystalProc.new(@db)
        call = CallBuilder::CppQobjectConnect.new(@db)
        wrapper = CallBuilder::CppWrapper.new(@db)

        proc = to_proc.build(method)
        connector.calls[Graph::Platform::Cpp] = wrapper.build(
          method: connector.origin,
          target: call.build(method, proc),
        )
      end

      private def add_connect_method(signal)
        conn_method = signal_connect_binding_method(signal.origin)

        Graph::Method.new(
          origin: conn_method,
          name: conn_method.name,
          parent: signal.parent_class,
        )
      end

      # Builds the method(s) used to generate the binding to a Qt signals connect
      # method.
      private def signal_connect_binding_method(signal : Parser::Method)
        proc_type = Parser::Type.proc(Parser::Type::VOID, signal.arguments)
        proc_arg = Parser::Argument.new("_proc_", proc_type)

        Parser::Method.build(
          name: "CONNECT_#{signal.name}",
          class_name: signal.class_name,
          return_type: CONNECTION_HANDLE_TYPE,
          arguments: [ proc_arg ],
          crystal_name: "on_#{signal.crystal_name}"
        )
      end
    end
  end
end
