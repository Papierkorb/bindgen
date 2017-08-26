module Bindgen
  module CallAnalyzer
    # Analyzer for calls made from C++ to Crystal.  Used to create a Proc which
    # can be passed to C++, and later called from there.  The generated lambda
    # most likely calls further into Crystal-land.
    class CrystalReverseBinding
      include CrystalMethods

      def initialize(@db : TypeDatabase)
      end

      def analyze(method : Parser::Method, klass_type : Parser::Type?) : Call
        arguments = method.arguments.map_with_index do |arg, idx|
          caller = pass_from_binding(arg, false)
          callee = pass_from_wrapper(arg)
          result = combine_result(caller, callee)
          result.to_argument(argument_name(arg, idx))
        end

        # Add `_self_` argument if required
        if klass_type && method.needs_instance?
          arguments.unshift self_argument(klass_type)
        end

        callee = pass_to_wrapper(method.return_type)
        caller = pass_to_binding(method.return_type, to_unsafe: true)
        result = combine_result(callee, caller)

        Call.new(
          origin: method,
          name: "Binding.#{method.mangled_name}",
          result: result,
          arguments: arguments,
        )
      end

      private def combine_result(outer, inner)
        conv_out = outer.conversion
        conv_in = inner.conversion

        if conv_out && conv_in
          conversion = Util.template(conv_out, conv_in)
        else
          conversion = conv_out || conv_in
        end

        Call::Result.new(
          type: outer.type,
          type_name: outer.type_name,
          pointer: outer.pointer,
          reference: outer.reference,
          conversion: conversion,
        )
      end
    end
  end
end
