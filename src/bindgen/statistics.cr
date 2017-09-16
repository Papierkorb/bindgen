module Bindgen
  # Simple collector of run-time statistics.
  class Statistics
    # Stores timing data of a measured stage.
    struct Timing
      # The duration of this statistic
      getter duration : Time::Span

      # If the executed block returned a `Statistics`, it'll be recorded here.
      getter child : Statistics?

      def initialize(@duration, @child = nil)
      end
    end

    DEPTH_MULTIPLIER = 2

    # Collected stages
    getter stages = { } of String => Timing

    # Measures execution of the given block.  Returns the result of the block.
    # The measured data is put into `#stages`.
    def measure(stage_name : String)
      before = Time.now
      result = yield
      after = Time.now

      duration = after - before
      child = result if result.is_a?(Statistics)
      @stages[stage_name] = Timing.new(duration, child)
      result
    end

    # Returns the total duration of all measured steps.  The timings between the
    # stages is *not* recorded, and is thus excluded from the total duration.
    def total_duration : Time::Span
      @stages.values.sum(Time::Span.new(0), &.duration)
    end

    # Returns a formatted human-readable string.
    def to_s(depth : Int32) : String
      String.build do |b|
        to_s(b, depth)
      end
    end

    # Writes formatted human-readable data into *io*.
    def to_s(io, depth = 0)
      indent = " " * (depth * DEPTH_MULTIPLIER)
      total = total_duration.ticks.to_f

      @stages.each do |name, timing|
        duration = timing.duration.ticks.to_f
        percent = ((duration / total) * 100).to_i

        io << indent << name << ": [" << percent << "%] "
        timing.duration.inspect(io)
        io << "\n"

        if child = timing.child
          child.to_s(io, depth + 1)
        end
      end

      io
    end
  end
end
