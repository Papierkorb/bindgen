# This is the main file running the `bindgen` program.
# If you want use bindgen as library, require "bindgen/library" instead.
require "./bindgen/library"

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

    chdir: { # Hack to make Crystal find paths by itself.
      type: String?,
      description: "Change into the directory before proceeding",
      short: false,
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

if working_directory = opts.chdir
  Dir.cd(working_directory)
end

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
