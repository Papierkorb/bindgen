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
      elsif simple
        Simple.new(pattern)
      else
        Full.new(pattern)
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

      def hash(hasher)
        hasher
      end
    end

    # A simple template implementing a subset of `Util.template`.  Only
    # supports `%`, which can be escaped by using `%%` instead.
    class Simple < Base
      def initialize(@pattern : String)
      end

      def template(code) : String
        @pattern.gsub(/%+/) do |m|
          literals = "%" * (m.size // 2)
          out_code = code if m.size % 2 == 1
          "#{literals}#{out_code}"
        end
      end

      def_equals_and_hash @pattern
    end

    # The default template.  Uses `Util.template` to substitute *code* into the
    # given *pattern*.
    class Full < Base
      def initialize(@pattern : String)
      end

      def template(code) : String
        Util.template(@pattern, code)
      end

      def_equals_and_hash @pattern
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

      def_equals_and_hash @first, @second
    end
  end
end
