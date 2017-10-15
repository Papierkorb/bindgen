require "./bindgen_lib"
require "toka"

class CliOptions
  Toka.mapping({
    stats: { # --stats, -s
      type: Bool,
      default: false,
      description: "Show runtime statistics",
    },

    var: { # --var, -v
      type: Hash(String, String),
      value_name: "NAME=VALUE",
      description: "Add variable.  Overrides builtins.",
    },
  }, {
    banner: "bindgen [options] <configuration.yml>",
    footer: "See https://github.com/Papierkorb/bindgen for further information.",
  })
end

opts = CliOptions.new

if opts.positional_options.size < 1
  puts Toka::HelpPageRenderer.new(CliOptions)
  exit 1
elsif opts.positional_options.size > 1
  puts "Exactly one configuration file must be supplied.  See --help."
  exit 1
end

# Merge additional --var's
Bindgen::Variables.builtin.merge!(opts.var)

# Parse the configuration
config_path = opts.positional_options.first
config = Bindgen::ConfigReader.from_file(
  klass: Bindgen::Configuration,
  path: config_path,
)

# And off we go!
tool = Bindgen::Tool.new(File.dirname(config_path), config, opts.stats)
exit_code = tool.run!
exit exit_code
