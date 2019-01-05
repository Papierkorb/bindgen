module Bindgen
  module Graph
    # Target platforms.  Used by `Method#calls` and `PlatformSpecific`.
    enum Platform
      # Only for the Crystal processor
      Crystal

      # Only for the CrystalBinding processor
      CrystalBinding

      # Only for the C++ processor
      Cpp

      # Returns this platform as flags type.
      def as_flag : Platforms
        case self
        when Crystal        then Platforms::Crystal
        when CrystalBinding then Platforms::CrystalBinding
        when Cpp            then Platforms::Cpp
        else
          raise "Unreachable"
        end
      end
    end

    # Flag version of `Platform`.
    @[Flags]
    enum Platforms
      Crystal
      CrystalBinding
      Cpp

      # Returns itself.
      def as_flag : self
        self
      end

      # Checks if the bit for *platform* is set.
      def includes?(platform : Platform) : Bool
        includes?(platform.as_flag)
      end
    end
  end
end
