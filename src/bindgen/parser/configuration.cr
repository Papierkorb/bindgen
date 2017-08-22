module Bindgen
  module Parser
    # Parser YML configuration.  See `Bindgen::Configuration#parser`.
    class Configuration
      YAML.mapping(
        # Force path to the bindgen clang tool
        binary: String?,

        # Flags to pass to the compiler verbatim
        flags: Array(String),

        # List of input files
        files: Array(String),

        # List of include paths
        includes: Array(String),

        # List of defines
        defines: Array(String),
      )
    end
  end
end
