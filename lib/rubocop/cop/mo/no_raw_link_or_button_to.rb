# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Phlex views/components must not call Rails' `link_to`/`button_to`
      # directly -- use `Components::Link`/`Components::Button` (Kit
      # syntax `Link(...)`/`Button(...)`) instead, so styling, Stimulus
      # data attrs, and Turbo wiring all stay centralized in one place
      # instead of drifting per call site.
      #
      # Scoped via this cop's Include/Exclude in .rubocop.yml, not in
      # this file: applies to app/components + app/views, excluding the
      # Button/Link primitive implementations themselves (which
      # legitimately call link_to/button_to to BUILD the component) and
      # app/views/mailers (emails can't use interactive Bootstrap/
      # Stimulus components -- they need plain, inline-styled tags).
      #
      # @example
      #   # bad
      #   link_to("Edit", edit_path)
      #   button_to("Delete", path, method: :delete)
      #
      #   # good
      #   Link(type: :get, name: "Edit", target: edit_path)
      #   Button(type: :delete, target: object)
      class NoRawLinkOrButtonTo < Base
        MSG = "Don't call `%<method>s` directly in a Phlex view/component " \
              "-- use `Link(...)`/`Button(...)` (Components::Link / " \
              "Components::Button) instead, so styling and Turbo/Stimulus " \
              "wiring stay centralized in one place."

        RESTRICT_ON_SEND = [:link_to, :button_to].freeze

        def on_send(node)
          add_offense(node, message: format(MSG, method: node.method_name))
        end
      end
    end
  end
end
