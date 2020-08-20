module Bindgen
  # Conversion templates for `Call::Result`.  They govern how a call result's
  # code should be transformed to become usable under a certain platform.
  module Template
    # Constructs a template from the string *pattern*.  No-op if the *pattern*
    # is `nil`.  If *simple* is true, the resulting template does not support
    # environment variables.
    def self.from_string(pattern : String?, *, simple = false) : Base
      if pattern.nil?
        None.new
      else
        Basic.new(pattern, simple: simple)
      end
    end

    # Base class of the templates.
    abstract class Base
      # Performs a template substitution.
      abstract def template(code : String) : String

      # Is this a no-operation template?
      def no_op?
        {{ @type == Bindgen::Template::None }}
      end

      # Combines two templates into one.  The *other* template is run after the
      # current template.
      def followed_by(other : Base) : Base
        return other if no_op?
        return self if other.no_op?
        Seq.new(first: self, second: other)
      end
    end

    # The no-op template that returns *code* unmodified.
    class None < Base
      def template(code) : String
        code
      end

      def ==(_other : self)
        true
      end
    end

    # The default template.  Uses `Util.template` to substitute *code* into the
    # given *pattern*.
    #
    # If *simple* is given, the template will only use a subset of the features;
    # `%` performs substitution, whereas the escape sequence `%%` outputs a
    # literal percent sign.
    class Basic < Base
      def initialize(@pattern : String, @simple = false)
      end

      def template(code) : String
        if @simple
          @pattern.gsub(/%+/) do |m|
            literals = "%" * (m.size // 2)
            out_code = code if m.size % 2 == 1
            "#{literals}#{out_code}"
          end
        else
          Util.template(@pattern, code)
        end
      end

      def_equals @pattern, @simple
    end

    # Compound template which runs *code* through two child templaters.
    class Seq < Base
      @first : Base
      @second : Base

      def initialize(@first, @second)
      end

      def template(code) : String
        @second.template(@first.template(code))
      end

      def_equals @first, @second
    end

    # Template to transform `Proc`s for Crystal wrapper types into `Proc`
    # expressions for binding types.
    class ProcFromWrapper < Base
      def initialize(@proc_type : Parser::Type, @db : TypeDatabase)
      end

      def template(code) : String
        args = @proc_type.template.not_nil!.arguments
        func_args = args[1..-1].map_with_index do |type, i|
          Parser::Argument.new("arg#{i}", type)
        end
        proc_call = Parser::Method.build(
          name: "call",
          return_type: args.first,
          arguments: func_args,
          class_name: "Proc",
        )

        # The templated code shouldn't contain braces, since an outer template
        # that comes from a config file might treat the code block as an
        # environment variable.
        builder = CallBuilder::CrystalFromCpp.new(@db)
        call = builder.build(proc_call, receiver: "_proc_", do_block: true)
        call.body.to_code(call, Graph::Platform::Crystal)
      end

      def_equals @proc_type, @db
    end
  end
end
