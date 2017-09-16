require "./bindgen_lib"

if ARGV.empty? || { "-h", "--help", "help" }.includes?(ARGV.first)
  puts "bindgen - Wrapper generator for C++ to Crystal."
  puts "  Usage: #{$0} [configuration yaml]"
  puts "See https://github.com/Papierkorb/bindgen for further information."
  exit 1
end

config_path = ARGV.first
config = Bindgen::ConfigReader.from_file(
  klass: Bindgen::Configuration,
  path: config_path,
)
tool = Bindgen::Tool.new(File.dirname(config_path), config)
