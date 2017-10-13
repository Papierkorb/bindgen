module Bindgen
  class FindPath
    # Checker for a `PathCheck`.
    class PathChecker < Checker
      def initialize(@config : PathCheck, @is_file : Bool)
      end

      # Checks *path* for existence.
      def check(path : String) : Bool
        if @is_file # Ignore the sub-path if we're looking for a file.
          full_path = path
        else
          full_path = "#{path}/#{@config.path}"
        end

        return false unless @config.kind.exists?(full_path)

        if @config.kind.file?
          file_check(full_path)
        else
          true
        end
      end

      # Runs `Kind::File` specific checks if configured.
      private def file_check(full_path)
        contains = @config.contains
        return true if contains.nil?

        data = File.read(full_path)
        if @config.regex
          regex = Regex.new(contains, FindPath::MULTILINE_OPTION)
          regex.match(data) != nil
        else
          data.includes?(contains)
        end
      end
    end
  end
end
