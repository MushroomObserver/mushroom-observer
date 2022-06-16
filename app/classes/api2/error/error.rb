# frozen_string_literal: true

class API2
  # API exception base class.
  class Error < ::StandardError
    attr_accessor :tag, :args, :fatal, :trace

    def initialize
      super
      self.tag = self.class.name.underscore.tr("/", "_").
                 sub(/^api\d+/, "api").to_sym
      self.args = {}
      self.fatal = false
      self.trace = caller
    end

    def inspect
      "#{self.class.name}(:#{tag}#{args.inspect})"
    end

    def to_s
      tag.l(args)
    end

    def t
      tag.t(args)
    end
  end
end
