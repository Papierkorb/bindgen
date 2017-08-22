module Bindgen
  module CallGenerator
    # Shared helper functionality for call generators.
    module Helper
      # Generates an invocation of *call* using *pass_args*, using a converter
      # if set.  Applies to Crystal and C++.
      def invocation(call, pass_args : Enumerable(String))
        call = { call } unless call.is_a?(Enumerable)
        invocation(call, "#{call.first.name}(#{pass_args.join(", ")})")
      end

      # Generates an invocation of *call* using *code*, applying a converter
      # if set.  Applies to Crystal and C++.
      def invocation(calls, code : String)
        calls = { calls } unless calls.is_a?(Enumerable)
        calls.reduce(code) do |body, call|
          if templ = call.result.conversion
            Util.template(templ, body)
          else
            body
          end
        end
      end
    end
  end
end
