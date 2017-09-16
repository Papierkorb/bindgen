module Bindgen
  module Graph
    # Target platform of a `Node`
    enum Platform
      # Only for the Crystal processor
      Crystal

      # Only for the CrystalBinding processor
      CrystalBinding

      # Only for the C++ processor
      Cpp
    end
  end
end
