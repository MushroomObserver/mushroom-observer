# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Phlex views/components must not call Rails' `link_to`/`button_to`,
      # NOR Phlex's own native `button(...)` tag helper, directly -- use
      # `Components::Link`/`Components::Button` (Kit syntax
      # `Link(...)`/`Button(...)`) instead, so styling, Stimulus data
      # attrs, and Turbo wiring all stay centralized in one place instead
      # of drifting per call site. `button(...)` is banned alongside
      # `button_to` specifically because it's the easy way to bypass
      # `Button` entirely while still LOOKING like a normal Phlex tag
      # call -- hand-rolling `button(class: "btn btn-default") { ... }`
      # produces the exact un-centralized styling this cop exists to stop,
      # without ever calling `button_to`.
      #
      # Scoped via this cop's Include/Exclude in .rubocop.yml, not in
      # this file: applies to app/components + app/views, excluding the
      # Button/Link primitive implementations themselves (which
      # legitimately call link_to/button_to/button to BUILD the
      # component) and app/views/mailers (emails can't use interactive
      # Bootstrap/Stimulus components -- they need plain, inline-styled
      # tags).
      #
      # @example
      #   # bad
      #   link_to("Edit", edit_path)
      #   button_to("Delete", path, method: :delete)
      #   button(type: "button", class: "btn btn-default") { "OK" }
      #
      #   # good
      #   Link(type: :get, name: "Edit", target: edit_path)
      #   Button(type: :delete, target: object)
      #   Button(name: "OK")
      class NoRawLinkOrButtonTo < Base
        MSG = "Don't call `%<method>s` directly in a Phlex view/component " \
              "-- use `Link(...)`/`Button(...)` (Components::Link / " \
              "Components::Button) instead, so styling and Turbo/Stimulus " \
              "wiring stay centralized in one place."

        RESTRICT_ON_SEND = [:link_to, :button_to, :button].freeze

        def on_send(node)
          return if node.method?(:button) && !bare_call?(node)

          add_offense(node, message: format(MSG, method: node.method_name))
        end

        private

        # `:button` is only Phlex's native tag helper when called bare
        # (or on an explicit `self`) -- `form.button(...)`/`obj.button(...)`
        # is some other API's `#button` method, not the tag helper this
        # cop exists to ban. `link_to`/`button_to` stay banned regardless
        # of receiver (e.g. `view_context.link_to(...)` is still Rails'
        # helper, still bypassing `Link`/`Button`).
        def bare_call?(node)
          node.receiver.nil? || node.receiver.self_type?
        end
      end
    end
  end
end
