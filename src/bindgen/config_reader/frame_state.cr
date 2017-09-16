module Bindgen
  module ConfigReader
    # States a `Frame` can be in.
    enum FrameState
      # The frame is not active.
      Inactive

      # Frame is active and waiting for an `if`
      AwaitingIf

      # Seen the `if` (But it didn't match)
      InCondition

      # A condition was met
      ConditionMet
    end
  end
end
