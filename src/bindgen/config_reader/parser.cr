module Bindgen
  module ConfigReader
    # Pull parser for YAML configuration files, offering conditional branches
    # and access to external dependencies.
    #
    # **If you want to read a configuration** see `ConfigReader.from_yaml`.
    #
    # This is done by hooking into the pull parser, manually checking for the
    # conditional fields, and applying them accordingly.
    #
    # Apart from this logic, the configuration file is still valid YAML.
    #
    # **Note**: Conditionals and dependencies are *only* supported in
    # *mappings* (`Hash` in Crystal).  Any such syntax encountered in something
    # other than a *mapping* will not trigger any special behaviour.
    #
    # ## Condition syntax
    #
    # YAML documents can define conditional parts in *mappings* by having a
    # conditional key, with *mapping* value.  If the condition matches, the
    # *mapping* value will be transparently embedded.  If it does not match, the
    # value will be transparently skipped.
    #
    # Condition keys look like `if_X` or `elsif_X` or `else`.  `X` is the
    # condition, and it looks like `Y_is_Z` or `Y_match_Z`.  You can also use
    # (one or more) spaces (` `) instead of exactly one underscore (`_`) to
    # separate the words.
    #
    # * `Y_is_Z` is true if the variable Y equals Z case-sensitively.
    # * `Y_isnt_Z` is true if the variable Y doesn't equal Z case-sensitively.
    # * `Y_match_Z` is true if the variable Y is matched by the regular expression
    #   in `Z`.  The regular expression is created case-sensitively.
    #
    # A condition block is opened by the first `if`.  Later condition keys can
    # use `elsif` or `else` (or `if` to open a *new* condition block).
    #
    # **Note**: `elsif` or `else` without an `if` will raise an exception.
    #
    # Their behaviour is like in Crystal: `if` starts a condition block, `elsif`
    # starts an alternative condition block, and `else` is used if none of `if` or
    # `elsif` matched.  It's possible to mix condition key-values with normal
    # key-values.
    #
    # **Note**: Conditions can be used in every *mapping*, even in *mappings* of
    # a conditional.  Each *mapping* acts as its own scope.
    #
    # ### Variables
    #
    # Variables are set by the user of the class (Probably through
    # `ConfigReader.from_yaml`).  All variable values are strings.
    #
    # Variable names are **case-sensitive**.  A missing variable will be treated
    # as having an empty value (`""`).
    #
    # ### Examples
    #
    # ```yaml
    # foo: # A normal mapping
    #   bar: 1
    #
    # # A condition: Matches if `platform` equals "arm".
    # if_platform_is_arm: # In Crystal: `if platform == "arm"`
    #   company: ARM et al
    #
    # # You can mix in values between conditionals.  It won't "break" following
    # # elsif or else blocks.
    # not_a_condition: Hello
    #
    # # An elsif: Matches if 1) the previous conditions didn't match
    # # 2) its own condition matches.
    # elsif_platform_match_x86: # In Crystal: `elsif platform =~ /x86/`
    #   company: Many different
    #
    # # An else: Matches if all previous conditions didn't match.
    # else:
    #   company: No idea
    #
    # # At any time, you can start a new if sequence.
    # "if today is friday": # You can use spaces instead of underscores too
    #   hooray: true
    # ```
    #
    # ## Dependencies
    #
    # To modularize the configuration, you can require ("merge") external yaml
    # files from within your configuration.
    #
    # This is triggered by using a key named `<<`, and writing the file name as
    # value: `<<: my_dependency.yml`.  The file-extension can also be omitted:
    # `<<: my_dependency` in which case an `.yml` extension is assumed.
    #
    # The dependency path is relative to the currently processed YAML file.
    #
    # You can also require multiple dependencies into the same *mapping*:
    #
    # ```yaml
    # types:
    #   Something: true # You can mix dependencies with normal fields.
    #   <<: simple_types.yml
    #   <<: complex_types.yml
    #   <<: ignores.yml
    # ```
    #
    # The dependency will be embedded into the open *mapping*: It's transparent
    # to the client code.
    #
    # It's perfectly possible to mix conditionals with dependencies:
    #
    # ```yaml
    # if_os_is_windows:
    #   <<: windows-specific.yml
    # ```
    #
    # ### Errors
    #
    # An exception will be raised if any of the following occur:
    #
    # * The maximum dependency depth of `10` (`MAX_DEPTH`) is exceeded.
    # * The dependency name contains a dot: `../foo.yml` won't work.
    # * The dependency name is absolute: `/foo/bar.yml` won't work.
    class Parser < YAML::PullParser
      class Error < Exception
        # The row this error occured
        getter row : Int32

        # The column this error occured
        getter column : Int32

        # The file the error occured in
        getter file : String

        def initialize(message, @row, @column, @file)
          super("#{message} at #{@row}:#{@column} in #{@file} ")
        end
      end

      # Maximum dependency load depth.
      MAX_DEPTH = 10

      # Global loader for dependencies.
      class_property loader : Loader = Loader.new

      # Variables for use in conditions.
      getter variables : VariableHash

      # Instance local loader
      getter loader : Loader

      # Path to the root YAML file.
      getter path : String

      # Parser stack
      getter parsers = [ ] of InnerParser

      def initialize(@variables, @content, @path, @loader = @@loader)
        # `YAML::PullParser` variables.  Is this a good idea..?
        # We'll never use these in reality.  And I don't know what's worse:
        # Hard-to-trace bugs because of a non-forwarded method, or a NULL
        # pointer dereference ("Crashing the application").
        @parser = Pointer(LibYAML::Parser).null
        @event = LibYAML::Event.new
        @closed = false

        # Build the real parser.
        @parsers << InnerParser.new(@variables, @content, @path, self)
      end

      # Closes all parsers.
      def close
        @parsers.each(&.close) unless @closed
        @closed = true
      end

      # Tries to deserialize a *klass* from the *content* of this instance.
      # Mimics `Object.from_yaml` in behaviour otherwise:
      #
      # ```
      # MyThing.from_yaml(code) # What you're used to
      # ConfigReader::Parser.new(variables, code).construct(MyThing) # What you want
      # ```
      #
      # See `ConfigReader.from_yaml` for a higher-level method.
      def construct(klass)
        read_stream do
          read_document do
            klass.new(self)
          end
        end
      end

      # Forward `YAML::PullParser` methods to the currently active parser.

      {% for fwd in %w[
        kind tag value
        anchor scalar_anchor sequence_anchor mapping_anchor alias_anchor
        skip
        line_number column_number
        problem? problem_mark? problem_line_number problem_column_number
        context? context_mark? context_line_number context_column_number
      ].map(&.id) %}
        # Forwards `#{{ fwd }}` to the currently active parser.
        def {{ fwd }}
          @parsers.last.{{ fwd }}
        end
      {% end %}

      # Reads the next token from the currently active parser.  If the parser
      # hits its end, and is not the main inner parser (The one of the root
      # YAML file), it is transparently removed.  In this case, the parser that
      # originally pulled the dependency in is resumed.
      def read_next
        kind = @parsers.last.read_next

        # Have we reached the end of an inner parser?
        if @parsers.size > 1 && kind.document_end?
          @parsers.pop # Eat the document end.
          return read_next # Recurse, do the same checks again.
        end

        kind
      end

      # Enters a dependency, which is effectively an external file.
      # **Do not call this by yourself.**
      #
      # Called by `InnerParser#read_next`.
      def enter_dependency!(path : String) : LibYAML::EventType
        if @parsers.size > MAX_DEPTH
          @parsers.last.raise "Max dependency depth of #{MAX_DEPTH} exceeded"
        end

        base_path = @parsers.last.path
        content, full_path = @loader.load(base_path, path)
        child = InnerParser.new(@variables, content, full_path, self)

        @parsers << child # Set the new parser as active
        child.read_prelude
        child.kind
      end

      # Does nothing.
      def finalize
        # We never initialized the YAML parser for this, so do nothing.
      end
    end
  end
end
