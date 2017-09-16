module Bindgen
  module ConfigReader
    # Parser for a single document.  Implements the conditional logic.
    # You don't use this class directly, see `Parser` instead.
    class InnerParser < YAML::PullParser
      # As defined in the YAML spec.
      MERGE_KEY = "<<"

      # Variables for use in conditions.
      getter variables : VariableHash

      # Path to the currently processed YAML file.
      getter path : String

      # Frame stack
      @stack : Array(Frame)

      # Current active frame
      @frame : Frame

      # Are we skipping over data?  See `#skip`.
      @skipping = false

      # Root parser, stored as weak reference.  This allows boehm GC to finalize
      # the `InnerParser` and `Parser` in any order.  Fixes a GC warning.
      @parent : WeakRef(Parser)

      def initialize(@variables, content, @path, parent : Parser)
        @parent = WeakRef.new(parent)
        @frame = Frame.new(FrameState::Inactive)
        @stack = [ @frame ]

        super(content)
      end

      # Skips the first few tokens of the prelude created by `libyaml`.
      # Used by `Parser#enter_dependency!`
      def read_prelude
        @skipping = true # Disable our `#read_next` for this
        read_stream_start
        read_document_start
        @skipping = false

        expect_kind LibYAML::EventType::MAPPING_START
        read_next(true) # Add a frame
        @frame.embedded = true
        read_next # Hide mapping frame from the client
      end

      # Reads the next token, returning its kind.
      def read_next(reprocess = false) : LibYAML::EventType
        kind = reprocess ? self.kind : super()
        return kind if @skipping

        @frame.key = !@frame.key? # Toggle `key: value` flip flop
        can_handle = kind.scalar? && !@frame.state.inactive? && @frame.key?

        value = self.value if can_handle

        # Note: This code is not outsourced as it requires access to `super`
        if can_handle && value == MERGE_KEY # Dependency?
          super() # Consume `<<`
          expect_kind(YAML::EventKind::SCALAR)
          dependency_name = self.value.not_nil!
          @frame.key = false # Next time we're here, it's a key again
          return @parent.value.not_nil!.enter_dependency!(dependency_name)
        elsif can_handle
          result = check_conditional(value.not_nil!)
          return kind if result.nil? # Bail if not a conditional

          super() # Consume the condition key
          if result == true # Success, embed the value mapping
            expect_kind(YAML::EventKind::MAPPING_START)

            push_stack(FrameState::AwaitingIf) # We're in a new frame!
            @frame.embedded = true # And we need to hide this from the client.
            return read_next
          elsif result == false # Fail, skip value.
            skip
            @frame.key = false # Adjust key
            return read_next(reprocess: true)
          end

          raise "BUG: This should never be reached!"
        end

        handle_kind(kind)
      end

      # Handles *kind*, which is mostly managing stack frames for starting and
      # ending sequences.
      private def handle_kind(kind)
        case kind
        when .stream_start? then push_stack(FrameState::Inactive)
        when .document_start? then push_stack(FrameState::Inactive)
        when .sequence_start? then push_stack(FrameState::Inactive)
        when .mapping_start? then push_stack(FrameState::AwaitingIf) # Only active frame!
        when .mapping_end?
          # Consume this token this frame is embedded into the parent frame.
          embedded = @frame.embedded?
          pop_stack
          return read_next if embedded
        when .sequence_end? then pop_stack
        when .document_end? then pop_stack
        when .stream_end? then pop_stack
        end

        kind
      end

      # Skip over the next complete token(s).  Temporarily disables condition
      # processing.
      def skip
        # Don't do conditional checks while skipping.
        old = @skipping
        @skipping = true
        super
        @skipping = old
      end

      # Checks the current values condition, if it is a conditional SCALAR.
      # Returns `true` if the condition was met, `false` if not, and `nil` if it's
      # not a conditional at all.
      private def check_conditional(name : String) : Bool?
        if name.starts_with?("if_") || name.starts_with?("if ")
          run_condition(name)
        elsif name.starts_with?("elsif_") || name.starts_with?("elsif ")
          return false if @frame.state.condition_met?
          raise "elsif without preceding if" unless @frame.state.in_condition?

          run_condition(name)
        elsif name == "else"
          return false if @frame.state.condition_met?
          raise "else without preceding if" unless @frame.state.in_condition?

          @frame.state = FrameState::ConditionMet
          true # Always meets the condition
        else # Not a conditional key
          nil # Take no action, go on as usual.
        end
      end

      # Runs the condition in *text*.  Also updates `@frame` accordingly.
      private def run_condition(text) : Bool
        eval = ConditionEvaluator.new(@variables)

        if eval.evaluate(text)
          @frame.state = FrameState::ConditionMet
          true
        else
          @frame.state = FrameState::InCondition
          false
        end
      end

      # Pushes a new frame onto the stack, and makes it the current one.
      private def push_stack(active)
        @frame = Frame.new(active) # Push conditional frame
        @stack << @frame
      end

      # Removes the top-most element from the stack, and makes the new top element
      # as current frame.
      private def pop_stack
        if @stack.size == 1
          raise "Called too often: Out of stack frames."
        end

        @stack.pop
        @frame = @stack.last
        @frame.key = false
      end

      # Raises an `Parser::Error` with *message*.
      def raise(message)
        ::raise Parser::Error.new(
          message: message,
          row: line_number.to_i32,
          column: column_number.to_i32,
          file: @path,
        )
      end
    end
  end
end
