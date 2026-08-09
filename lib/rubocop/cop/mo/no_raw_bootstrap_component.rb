# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Phlex views/components must not hand-roll the markup for a
      # top-level Bootstrap UI component MO already has a
      # `Components::*` wrapper for -- e.g. `div(class: "alert
      # alert-info")` instead of `Alert(level: :info)`. Detects a
      # `div`/`ul`/`nav` tag call whose `class:` value is a string
      # literal containing one of the known Bootstrap root classes
      # below, and suggests the corresponding component.
      #
      # Scoped via this cop's Include/Exclude in .rubocop.yml -- the
      # Exclude list covers each mapped component's own implementation
      # file(s), which legitimately emit the raw markup to BUILD the
      # abstraction every other Phlex file is required to use instead
      # (same shape as MO/NoRawLinkOrButtonTo's exclusion of
      # button.rb/link.rb).
      #
      # @example
      #   # bad
      #   div(class: "alert alert-info") { ... }
      #   div(class: "modal fade", id: "x") { ... }
      #
      #   # good
      #   Alert(level: :info) { ... }
      #   Modal(id: "x") { ... }
      class NoRawBootstrapComponent < Base
        MSG = "Don't hand-roll `.%<css_class>s` markup -- use " \
              "`%<component>s(...)` (Components::%<component>s) instead."

        RESTRICT_ON_SEND = [:div, :ul, :nav].freeze

        ROOT_CLASS_TO_COMPONENT = {
          "alert" => "Alert",
          "modal" => "Modal",
          "dropdown" => "Dropdown",
          "dropdown-menu" => "Dropdown",
          "list-group" => "ListGroup",
          "navbar" => "Navbar",
          "nav-tabs" => "NavTabs",
          "panel" => "Panel",
          "carousel" => "Carousel",
          "input-group" => "InputGroup",
          "btn-group" => "ButtonGroup"
        }.freeze

        def on_send(node)
          return unless bare_call?(node)

          class_arg = class_keyword_value(node)
          return unless class_arg&.str_type?

          root = matching_root_class(class_arg.value)
          return unless root
          return if application_form_subclass?(node)

          component = ROOT_CLASS_TO_COMPONENT[root]
          add_offense(node,
                      message: format(MSG, css_class: root,
                                           component: component))
        end

        private

        def bare_call?(node)
          node.receiver.nil? || node.receiver.self_type?
        end

        # `Components::ApplicationForm` is a class, not a module, so
        # Phlex::Kit's `const_added` hook never fires for its
        # subclasses -- see phlex_reference.md's "Kit sugar doesn't
        # reach app/components/application_form/*". Any raw Bootstrap
        # markup here (e.g. a Stimulus-driven autocomplete pulldown
        # reusing `.dropdown-menu` for styling only, not Bootstrap's
        # actual toggle-button JS behavior) can't be swapped for a
        # bare Kit-syntax call regardless of which root class matched.
        def application_form_subclass?(node)
          class_node = node.each_ancestor(:class).first
          return false unless class_node

          superclass = class_node.children[1]
          return false unless superclass

          superclass.source.delete_prefix("::").end_with?("ApplicationForm")
        end

        def class_keyword_value(node)
          hash = node.arguments.find(&:hash_type?)
          return nil unless hash

          pair = hash.pairs.find do |p|
            p.key.sym_type? && p.key.value == :class
          end
          pair&.value
        end

        def matching_root_class(class_string)
          tokens = class_string.to_s.split(/\s+/)
          ROOT_CLASS_TO_COMPONENT.keys.find { |root| tokens.include?(root) }
        end
      end
    end
  end
end
