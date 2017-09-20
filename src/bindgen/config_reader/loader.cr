module Bindgen
  module ConfigReader
    # Loader for named files.  Used by `Parser` to get referenced external
    # dependencies.  See `Parser.loader` to install a custom loader.
    class Loader
      class Error < Exception
        # Path to the base file causing the error
        getter base_file : String

        # The dependency name
        getter dependency : String

        def initialize(@base_file, @dependency, message)
          super("In source #{@base_file.inspect}: Dependency #{@dependency.inspect} #{message}")
        end
      end

      # Regular expression matching the start of an absolute path
      ABSOLUTE_RX = /^(?:[\\\/]|[a-z0-9]+:)/i

      # Loads the *dependency* required by *base_file*.  Returns the read data,
      # and the full path to the loaded file.
      def load(base_file : String, dependency : String)
        has_extension = dependency.ends_with?(".yml") || dependency.ends_with?(".yaml")
        dep = dependency.sub(/\.ya?ml$/, "")

        dependency = "#{dependency}.yml" unless has_extension
        sanity_check!(base_file, dep, dependency)

        base_path = File.dirname(base_file)
        target_path = "#{base_path}/#{dependency}"

        { File.read(target_path), target_path }
      end

      # Does a sanity check on the depdency path.  Absolute paths and paths
      # containing dots are disallowed.  Disallowing ".." is deliberate.
      protected def sanity_check!(source, wanted, written)
        if wanted.includes?('.') # Disallow `../foo.yml` paths
          raise Error.new(source, written, "includes dots, but no dots are allowed")
        end

        is_absolute = ABSOLUTE_RX.match(wanted)
        if is_absolute # Disallow absolute paths
          raise Error.new(source, written, "uses absolute path, but only relative is allowed")
        end
      end
    end
  end
end
