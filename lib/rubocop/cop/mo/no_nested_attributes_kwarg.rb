# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # A `prop :attributes, ..., :**` component (Table, Icon, Button,
      # Alert, some Link(type: ...) targets, etc. -- see KIT_NAMES/
      # LINK_DOUBLE_SPLAT_TYPES/NEW_ONLY_CLASSES) forwards every
      # unrecognized keyword straight through to the element it
      # renders. Passing `attributes: { foo: "bar" }` to one of these
      # doesn't set a nested options bucket -- there is no such prop
      # -- it lands as one more entry *inside* the double-splat, under
      # the literal key `:attributes`, alongside whatever the caller
      # meant to set. Phlex then renders a nested hash value as
      # prefixed sub-attributes (`attributes-foo="bar"`) instead of
      # `foo="bar"` on the element -- confirmed live on
      # `Components::Table` (issue #5702): `Table(@rows, attributes:
      # { align: "center" })` rendered `<table attributes-align=
      # "center">`, not `<table align="center">`.
      #
      # Pass the same keys flat instead -- that's what the
      # double-splat is for.
      #
      # `Link(type: ...)` is heterogeneous: most dispatch targets
      # (`:active`, `:collapse_toggle`, `:get`/`:download`/`:edit`/
      # `:new`, `:modal`, `:user`) use a `:**` prop; `:external`/
      # `:location`/`:object` have no `attributes` prop, so they're
      # left unchecked here (they'd raise loudly instead of
      # misrendering). `Help` also dispatches, but every target uses a
      # plain named prop, so it isn't checked here.
      #
      # @example
      #   # bad
      #   Table(@rows, attributes: { align: "center", cellspacing: "2" })
      #   Icon(type: :edit, attributes: { data: { foo: "bar" } })
      #   Link(type: :get, target: url, attributes: { data: { x: 1 } })
      #
      #   # good
      #   Table(@rows, align: "center", cellspacing: "2")
      #   Icon(type: :edit, data: { foo: "bar" })
      #   Link(type: :get, target: url, data: { x: 1 })
      #   Link(type: :user, user: u, attributes: { class: "x" }) # fine
      class NoNestedAttributesKwarg < Base
        MSG = "Don't pass `attributes:` to `%<name>s` -- it forwards " \
              "unrecognized keywords directly (a `**` prop), so a " \
              "nested `attributes: { ... }` lands as a literal " \
              "`:attributes` entry instead of flat attrs. Pass the " \
              "keys directly instead."

        # Kit-sugar (bare) call names where every dispatch target (if
        # any) uniformly uses a `:**` prop.
        KIT_NAMES = [
          :Table, :Icon, :Button, :Alert, :Column, :Row, :Accordion,
          :NavTabs, :Container, :Collapsible, :CountBadge,
          :LanguageSwitchButton, :Navbar, :ButtonGroup, :ContentPadded,
          :InputGroup, :ListGroup, :Panel
        ].freeze

        # `Link(type: ...)` targets confirmed to use a `:**` prop
        # (directly or by inheriting from one that does).
        LINK_DOUBLE_SPLAT_TYPES = [
          :active, :collapse_toggle, :download, :edit, :get, :modal, :new,
          :user
        ].freeze

        # Full constant paths only reachable via `.new` (nested classes
        # with no Kit sugar).
        NEW_ONLY_CLASSES = %w[
          Components::Navbar::Text
          Components::Form::CheckboxCollapse
          Components::Link::Active
          Components::Link::Get
          Components::Link::CollapseToggle
          Components::Link::Modal
          Components::Link::User
          Components::InputGroup::Addon
          Components::Modal::CloseButton
          Components::ListGroup::Item
          Components::ListGroup::LinkItem
        ].freeze

        RESTRICT_ON_SEND = (KIT_NAMES + [:Link, :new]).freeze

        def on_send(node)
          name = offending_name(node)
          return unless name

          pair = attributes_pair(node)
          return unless pair

          add_offense(pair, message: format(MSG, name: name))
        end

        private

        def offending_name(node)
          return node.method_name.to_s if KIT_NAMES.include?(node.method_name)
          return "Link" if node.method_name == :Link && link_double_splat?(node)
          return nil unless node.method_name == :new && node.receiver

          receiver_source = node.receiver.source
          NEW_ONLY_CLASSES.find { |klass| receiver_source == klass }
        end

        def link_double_splat?(node)
          type_value = find_pair_value(node, :type)
          return false unless type_value&.sym_type?

          LINK_DOUBLE_SPLAT_TYPES.include?(type_value.value)
        end

        def attributes_pair(node)
          hash_arg = node.arguments.find(&:hash_type?)
          return nil unless hash_arg

          hash_arg.pairs.find { |pair| pair_key?(pair, :attributes) }
        end

        def find_pair_value(node, key)
          hash_arg = node.arguments.find(&:hash_type?)
          return nil unless hash_arg

          hash_arg.pairs.find { |pair| pair_key?(pair, key) }&.value
        end

        def pair_key?(pair, key)
          pair.key.sym_type? && pair.key.value == key
        end
      end
    end
  end
end
