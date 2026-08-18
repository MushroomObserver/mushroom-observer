# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags a Superform (`Components::ApplicationForm`) subclass that
      # overrides `form_tag`. A hand-rolled `form_tag` bypasses
      # Superform's own HTTP-method handling: the default `form_tag`
      # already emits `method: "get"` when the form was constructed
      # with `method: :get`, `method: "post"` otherwise, and spoofs
      # PATCH/PUT/DELETE via a hidden `_method` field driven by the
      # model's `persisted?` -- never a literal non-GET/POST value on
      # the `<form method="...">` attribute itself, which HTML5 doesn't
      # support (an unrecognized method value silently submits as GET).
      #
      # Found live: `FormObject::FieldSlipAttach`'s form hardcoded
      # `method: :put` on the `<form>` tag directly -- a real browser
      # submitted it as GET to a PUT/PATCH-only route, working only in
      # controller tests (which call the action directly, bypassing
      # HTML method semantics entirely).
      #
      # @example
      #   # bad
      #   class Views::Controllers::Foo::Form < Components::ApplicationForm
      #     def form_tag(&block)
      #       form(action: form_action, method: :put, **form_attributes, &block)
      #     end
      #   end
      #
      #   # good -- force PATCH/PUT via persisted?, matching
      #   # FormObject::AdminSession
      #   class FormObject::Foo < FormObject::Base
      #     def persisted?
      #       true
      #     end
      #   end
      #
      #   # good -- force GET via the constructor, matching Superform's
      #   # own `form_method` handling, no form_tag override needed
      #   class Views::Controllers::Foo::Form < Components::ApplicationForm
      #     def initialize(model, **)
      #       super(model, method: :get, **)
      #     end
      #   end
      class NoHandRolledFormTag < Base
        MSG = "Don't override `form_tag` -- Superform's default already " \
              "handles GET (pass `method: :get` to `super`) and spoofs " \
              "PATCH/PUT via a `persisted?` override (see " \
              "FormObject::AdminSession). A literal non-GET/POST " \
              "`method:` on a hand-rolled `<form>` tag isn't valid " \
              "HTML5 and silently submits as GET."

        def on_def(node)
          return unless node.method?(:form_tag)

          add_offense(node)
        end
      end
    end
  end
end
