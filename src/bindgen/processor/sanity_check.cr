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
    # * Variadic methods are directly bound
    # * Alias targets are reachable
    # * Class base-classes are reachable
    class SanityCheck < Base
      # Illegal constants in a flag enumeration
      ILLEGAL_FLAG_ENUM = {"All", "None"}

      # Regular expression for a CONSTANT
      CONSTANT_RX = /^[A-Z_][A-Z0-9_]*$/

      # Regular expression for a camel-cased symbol
      CAMEL_CASE_RX = /^[A-Z_][A-Za-z0-9_]*$/

      # Regular expression describing a method name
      METHOD_NAME_RX = /^[a-z_][A-Za-z0-9_]*[?!=]?$/

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
        @errors = [] of Error
        @platform = Graph::Platform::Crystal
      end

      private def add_error(*args)
        @errors << Error.new(*args)
      end

      def process(*_args)
        super

        return if @errors.empty?

        # at = "at".colorize.mode(:bold)
        # @errors.each do |error|
        #   STDERR.puts "#{error.message} #{at} #{error.node.diagnostics_path}"
        # end
        # STDERR.puts "Found #{@errors.size} errors.  Aborting.".colorize.mode(:bold)

        logger.error { "Found #{@errors.size} errors.  Aborting." }

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
        super unless specific.platforms.cpp?
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
          err = "Enum #{e.name} doesn't have any constants"
          logger.error { err }
          add_error(enumeration, err)
        end

        # 2. Check flags-enum
        if e.flags?
          ILLEGAL_FLAG_ENUM.each do |name|
            if e.values.has_key?(name)
              err = "@[Flags] enum can't have a #{name} constant"
              logger.error { err }
              add_error(enumeration, err)
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
            err = "Argument #{idx + 1} has unreachable type #{arg.type_name}"
            logger.error { err }
            add_error(method, err)
          end
        end

        unless type_reachable?(call.result, method)
          err = "Result type #{call.result.type_name} is unreachable"
          logger.error { err }
          add_error(method, err)
        end

        if method.origin.variadic? && method.tag?(Graph::Method::EXPLICIT_BIND_TAG).nil?
          err = "Variadic function must be directly bound"
          logger.error { err }
          add_error(method, err)
        end
      end

      # Checks if the *expr* type can be reached from *base*.
      private def type_reachable?(expr, base)
        if expr.type.builtin? # Built-ins are always reachable
          true
        elsif @db.try_or(expr.type, false, &.builtin)
          true # Crystal built-in
        else   # Do a full look-up otherwise
          Graph::Path.from(expr.type_name).lookup(base) != nil
        end
      end

      # Checks the naming scheme of *node* for errors.
      private def check_node_name!(node)
        if node.is_a?(Graph::Constant)
          check_valid_constant_name!(node)
        elsif node.constant?
          check_valid_camel_case_name!(node)
        else
          check_method_name!(node.as(Graph::Method))
        end
      end

      # Checks if *node* has a valid camel-case name.  If not, adds an error.
      private def check_valid_camel_case_name!(node)
        unless CAMEL_CASE_RX.match(node.name)
          err = "Invalid #{node.kind_name.downcase} camel case name #{node.name.inspect}"
          logger.error { err }
          add_error(node, err)
        end
      end

      # Checks if *node* has a valid constant name.  If not, adds an error.
      private def check_valid_constant_name!(node)
        unless CONSTANT_RX.match(node.name)
          err = "Invalid #{node.kind_name.downcase} constant name #{node.name.inspect}"
          logger.error { err }
          add_error(node, err)
        end
      end

      # Checks if *node* has a valid non-constant name.  If not, adds an error.
      private def check_method_name!(node)
        return if node.name.empty? # Accept initializers

        unless METHOD_NAME_RX.match(node.origin.crystal_name)
          err = "Invalid #{node.kind_name.downcase} method name #{node.name.inspect}"
          logger.error { err }
          add_error(node, err)
        end
      end
    end
  end
end
