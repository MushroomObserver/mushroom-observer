# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Phlex views/components must not call the bare `form(...)` tag
      # helper directly -- use `Components::ApplicationForm` (Superform)
      # instead, so CSRF tokens, `_method` overrides, and Turbo wiring
      # all stay centralized in one place instead of drifting per call
      # site (issue #5100).
      #
      # Scoped via this cop's Include/Exclude in .rubocop.yml, not in
      # this file: applies to app/components + app/views, excluding the
      # handful of files whose entire purpose is to legitimately build a
      # raw-form primitive (an `ApplicationForm` subclass's own GET-form
      # `form_tag` override, or a reusable raw-form component like
      # `Components::IndexFilter`). A one-off deviation inside an
      # otherwise-ordinary view (e.g. a cross-origin POST straight to an
      # external payment processor) should disable this cop inline at
      # the call site instead of being added to the file-level Exclude
      # list -- see `app/views/controllers/support/confirm.rb`.
      #
      # @example
      #   # bad
      #   form(action: foo_path, method: :post) { ... }
      #
      #   # good
      #   class Components::FooForm < Components::ApplicationForm
      #     def view_template
      #       super do
      #         # fields...
      #       end
      #     end
      #   end
      class NoHandRolledFormTag < Base
        MSG = "Don't call the bare `form(...)` tag helper directly -- " \
              "use Components::ApplicationForm (Superform) instead, so " \
              "CSRF tokens, _method overrides, and Turbo wiring stay " \
              "centralized in one place."

        RESTRICT_ON_SEND = [:form].freeze

        def on_send(node)
          return unless bare_call?(node)

          add_offense(node)
        end

        private

        # `form(...)` is only the Phlex tag helper when called bare (or
        # on an explicit `self`) -- `some_object.form(...)` is some
        # other API's `#form` method, not the tag helper this cop
        # exists to ban.
        def bare_call?(node)
          node.receiver.nil? || node.receiver.self_type?
        end
      end
    end
  end
end
