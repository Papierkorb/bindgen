module Bindgen
  module Processor
    # Does sanity-checks on the graph.  If any check fails, a message written to
    # `STDERR` and the process is exited.
    #
    # Checks are as follows:
    # * Name of enums, libs, structures, classes, modules and aliases are valid
    # * Name of methods are valid
    # * Enumerations have at least one constant
    # * Enumeration constants are correctly named
    # * Flag-enumerations don't have `All` nor `None` constants
    # * Method arguments and result types are reachable
    # * Alias targets are reachable
    # * Class base-classes are reachable
    class SanityCheck < Base
      # Illegal constants in a flag enumeration
      ILLEGAL_FLAG_ENUM = { "All", "None" }

      # Regular expression describing a constant name
      CONSTANT_RX = /^[A-Z_][A-Za-z0-9_]*$/

      # Regular expression describing a non-constant name
      NON_CONSTANT_RX = /^[a-z_][A-Za-z0-9_]*$/

      # A binding error
      struct Error
        # The node this error occured at
        getter node : Graph::Node

        # Error message
        getter message : String

        def initialize(@node, @message)
        end
      end

      def initialize(*_args)
        super
        @errors = [ ] of Error
        @platform = Graph::Platform::Crystal
      end

      private def add_error(*args)
        @errors << Error.new(*args)
      end

      def process(*_args)
        super

        return if @errors.empty?
        at = "at".colorize.mode(:bold)

        @errors.each do |error|
          STDERR.puts "#{error.message} #{at} #{error.node.diagnostics_path}"
        end

        STDERR.puts "Found #{@errors.size} errors.  Aborting.".colorize.mode(:bold)
        raise Tool::ExitError.new
      end

      # Check for correct naming of nodes.
      def visit_node(node)
        unless node.is_a?(Graph::PlatformSpecific)
          check_node_name!(node)
        end

        super
      end

      # Only visit non-C++ specifics
      def visit_platform_specific(specific)
        super unless specific.platform.cpp?
      end

      # Temporarily switch the platform.
      def visit_library(library)
        old = @platform
        @platform = Graph::Platform::CrystalBinding
        super
      ensure
        @platform = old.not_nil!
      end

      # Check enumeration constants
      def visit_enum(enumeration)
        e = enumeration.origin

        # 1. Check for existence of any constant
        if e.values.empty?
          add_error(enumeration, "Enum doesn't have any constants")
        end

        # 2. Check constant naming
        e.values.each do |name, _|
          unless CONSTANT_RX.match(name)
            add_error(enumeration, "Invalid enum constant name #{name.inspect}")
          end
        end

        # 3. Check flags-enum
        if e.flags?
          ILLEGAL_FLAG_ENUM.each do |name|
            if e.values.has_key?(name)
              add_error(enumeration, "@[Flags] enum can't have a #{name} constant")
            end
          end
        end
      end

      # Check reachability of all types
      private def visit_method(method)
        call = method.calls[@platform]?
        return if call.nil?

        call.arguments.each_with_index do |arg, idx|
          unless type_reachable?(arg, method)
            add_error(method, "Argument #{idx + 1} has unreachable type #{arg.type_name}")
          end
        end

        unless type_reachable?(call.result, method)
          add_error(method, "Result type #{call.result.type_name} is unreachable")
        end
      end

      # Checks if the *expr* type can be reached from *base*.
      private def type_reachable?(expr, base)
        if expr.type.builtin? # Built-ins are always reachable
          true
        elsif Crystal::BUILTIN_TYPES.includes?(expr.type_name.sub(/\(.*/, ""))
          true # Crystal built-in
        else # Do a full look-up otherwise
          Graph::Path.from(expr.type_name).lookup(base) != nil
        end
      end

      # Checks the naming scheme of *node* for errors.
      private def check_node_name!(node)
        if node.constant?
          check_valid_constant_name!(node)
        else
          check_valid_non_constant_name!(node)
        end
      end

      # Checks if *node* has a valid constant name.  If not, adds an error.
      private def check_valid_constant_name!(node)
        unless CONSTANT_RX.match(node.name)
          add_error(node, "Invalid #{node.kind_name.downcase} name #{node.name.inspect}")
        end
      end

      # Checks if *node* has a valid non-constant name.  If not, adds an error.
      private def check_valid_non_constant_name!(node)
        return if node.name.empty? # Accept initializers

        unless NON_CONSTANT_RX.match(node.name)
          add_error(node, "Invalid #{node.kind_name.downcase} name #{node.name.inspect}")
        end
      end
    end
  end
end
