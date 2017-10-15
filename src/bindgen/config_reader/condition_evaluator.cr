module Bindgen
  module ConfigReader
    # Helper structure for `ConditionalPullParser`.  Implements the conditionn
    # evaluation logic of `Parser` (Actually of `InnerParser`).
    #
    # See `Parser`s documentation for a description of the syntax.
    struct ConditionEvaluator
      class Error < Exception
        getter condition_text : String

        def initialize(@condition_text, message)
          super(message)
        end
      end

      # Regular expression for conditionals.
      # Matches: `[els]if VARIABLE (is|matches) VALUE`.
      # Instead of a space, an underscore may be used instead.
      RX = /^(?:els)?if(?: +|_)(.+?)(?: +|_)(is|isnt|matches)(?: +|_)(.*)$/

      # Available variables
      getter variables : Hash(String, String)

      def initialize(@variables)
      end

      # Evaluates *condition_text*.  If it's `"else"` returns always `true`.
      def evaluate(condition_text : String)
        if condition_text == "else"
          true
        else
          run_condition(condition_text, *split(condition_text))
        end
      end

      # Runs the actual condition check.
      private def run_condition(text, variable, verb, test)
        value = @variables[variable]?.to_s

        case verb
        when "is" then value == test
        when "isnt" then value != test
        when "matches" then /#{test}/.match(value) != nil
        else
          raise Error.new(text, "Unknown condition verb: #{verb} in #{text.inspect}")
        end
      end

      # Splits `foo_is_bar` into `{ "foo", "is", "bar" }`.  If matching failed,
      # raises.
      private def split(text : String)
        if m = RX.match(text)
          variable = m[1]
          verb = m[2]
          value = m[3]

          { variable, verb, value }
        else
          raise Error.new(text, "Malformed condition key: #{text.inspect}")
        end
      end
    end
  end
end
