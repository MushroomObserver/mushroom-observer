# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # `errors.add`'s type argument must be a bare tag symbol, not an
      # eagerly-resolved translation call -- resolution happens lazily
      # at display time via the `ActiveModel::Error#message` override
      # (config/initializers/active_model_error_tag_resolution.rb).
      # Passing a pre-resolved string bakes English into the error at
      # validation time again, defeating the two things deferred
      # resolution buys: locale correctness across async boundaries (a
      # job/mailer resolving in a different `I18n.locale` than was
      # active when the error was added) and translatability into
      # MO's other locales.
      #
      # @example
      #   # bad
      #   errors.add(:name, :some_tag.t(count: 3))
      #   errors.add(:name, :some_tag.l)
      #
      #   # good
      #   errors.add(:name, :some_tag, count: 3)
      class NoResolvedErrorsAddType < Base
        MSG = "Pass a bare tag symbol to `errors.add`, not `%<call>s` -- " \
              "resolution happens lazily at display time. Use " \
              "`errors.add(:field, :tag, **args)`, not " \
              "`errors.add(:field, :tag.t(**args))`."

        RESTRICT_ON_SEND = [:add].freeze
        RESOLVING_METHODS = [:t, :l, :tl, :tp, :tpl].freeze

        def on_send(node)
          return unless errors_add?(node)

          type_arg = node.arguments[1]
          return unless resolved_tag_call?(type_arg)

          add_offense(type_arg, message: format(MSG, call: type_arg.source))
        end

        private

        def errors_add?(node)
          node.receiver&.send_type? && node.receiver.method?(:errors)
        end

        def resolved_tag_call?(arg)
          arg&.send_type? && RESOLVING_METHODS.include?(arg.method_name) &&
            arg.receiver&.sym_type?
        end
      end
    end
  end
end
