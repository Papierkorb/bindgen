require "./bindgen_lib"

show_stats = !!ARGV.delete("--stats")
show_help = ARGV.any?{|arg| { "-h", "--help", "help" }.includes?(arg)}

if ARGV.empty? || show_help
  puts "bindgen - Wrapper generator for C++ to Crystal."
  puts "  Usage: #{$0} [configuration yaml] [--stats]"
  puts "See https://github.com/Papierkorb/bindgen for further information."
  exit 1
end

config_path = ARGV.first
config = Bindgen::ConfigReader.from_file(
  klass: Bindgen::Configuration,
  path: config_path,
)
tool = Bindgen::Tool.new(File.dirname(config_path), config, show_stats)

exit_code = tool.run!
exit exit_code
