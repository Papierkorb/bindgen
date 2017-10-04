module Bindgen
  module Parser
    # Parser YML configuration.  See `Bindgen::Configuration#parser`.
    class Configuration
      YAML.mapping(
        # Force path to the bindgen clang tool
        binary: {
          type: String,
          nilable: true,
        },

        # Flags to pass to the compiler verbatim
        flags: {
          type: Array(String),
          default: %w[ -x c++ -std=c++11 ],
        },

        # List of input files.  Only required option.
        files: Array(String),

        # List of include paths
        includes: {
          type: Array(String),
          default: [ ] of String,
        },

        # List of defines
        defines: {
          type: Array(String),
          default: [ # Default to allow C99 stuff in C++
            "__STDC_CONSTANT_MACROS",
            "__STDC_LIMIT_MACROS",
          ],
        },
      )
    end
  end
end
