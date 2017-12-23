module Bindgen
  module ConfigReader
    # States a `Frame` can be in.  Part of the condition "state-machine".
    enum ConditionState
      # We're waiting for an `if` to occur.
      AwaitingIf

      # Seen the `if`, but it didn't match.
      Unmet

      # A condition was met.
      Met
    end
  end
end
