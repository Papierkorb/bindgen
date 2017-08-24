require "./bindgen_lib"

if ARGV.empty? || { "-h", "--help", "help" }.includes?(ARGV.first)
  puts "bindgen - Wrapper generator for C++ to Crystal."
  puts "  Usage: #{$0} [configuration yaml]"
  puts "See https://github.com/Papierkorb/bindgen for further information."
  exit 1
end

config = Bindgen::Configuration.from_yaml File.read(ARGV.first)
tool = Bindgen::Tool.new(config)
tool.run!
