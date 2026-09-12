# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags a Superform (`Components::ApplicationForm`) subclass that
      # hand-rolls its own `_method` hidden field via
      # `hidden_field("_method", ...)`. Superform emits a `_method`
      # hidden automatically (`_method_field`, driven by the model's
      # `persisted?` or an explicit `method:` on the constructor) --
      # adding a second one produces two `_method` hiddens in the
      # rendered form.
      #
      # Found live (#5088): the field-slip review form hand-rolled its
      # own `_method=patch` hidden ALONGSIDE Superform's own
      # unconditional `_method=post` (emitted for any non-persisted
      # model). turbo-rails' `encodeMethodIntoRequestBody` resolves the
      # request method from the FIRST `_method` value in the form data,
      # then strips every `_method` entry from the body before
      # submitting -- so it read "post", then stripped the override
      # entirely, turning a Turbo PATCH submission into a bare POST
      # with no override at all. A plain (non-Turbo) browser POST
      # masked this: Rack keeps the LAST value of a duplicated form
      # field, so `local: true` submissions happened to route
      # correctly regardless of the duplicate -- only Turbo's
      # first-value-then-strip logic actually breaks.
      #
      # The fix is never a second hidden field -- force the method
      # Superform itself emits instead: pass `method: :patch` (or
      # `:put`) to the constructor, or override `persisted?` (see
      # `FormObject::AdminSession`) so Superform's own `_method_field`
      # picks the right value on its own.
      #
      # @example
      #   # bad
      #   hidden_field("_method", value: "patch")
      #
      #   # good -- let Superform's own _method_field emit it
      #   def initialize(model, **)
      #     super(model, method: :patch, **)
      #   end
      class NoHandRolledMethodField < Base
        MSG = "Don't hand-roll a `_method` hidden field via " \
              "`hidden_field(\"_method\", ...)` -- Superform already " \
              "emits one (driven by the model's `persisted?` or an " \
              "explicit `method:` on the constructor). A second one " \
              "produces two `_method` hiddens, and turbo-rails silently " \
              "strips the override entirely rather than picking either " \
              "(#5088)."

        RESTRICT_ON_SEND = [:hidden_field].freeze

        def on_send(node)
          return unless bare_call?(node)

          first_arg = node.first_argument
          return unless method_field_name?(first_arg)

          add_offense(node)
        end

        private

        def bare_call?(node)
          node.receiver.nil? || node.receiver.self_type?
        end

        def method_field_name?(arg)
          arg && (arg.str_type? || arg.sym_type?) &&
            arg.value.to_s == "_method"
        end
      end
    end
  end
end
