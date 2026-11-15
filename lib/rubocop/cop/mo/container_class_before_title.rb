# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags `container_class` called after `add_title_with_name`/
      # `render_title_with_name` in the same method. Those two (and
      # only those two, among the page-title methods) read
      # `content_for(:container_class)` via `Views::FullPageBase::
      # Title#text_container?` to decide how a title with a name
      # renders. Calling `container_class` afterward means they saw
      # "unset" (defaulting to :text) even on a page that ends up a
      # different width.
      #
      # @example
      #   # bad
      #   def view_template
      #     add_title_with_name(:key, name: @name)
      #     container_class(:wide)
      #   end
      #
      #   # good
      #   def view_template
      #     container_class(:wide)
      #     add_title_with_name(:key, name: @name)
      #   end
      class ContainerClassBeforeTitle < Base
        MSG = "`container_class` is called after `%<name>s` here -- " \
              "move it before `%<name>s`, so that call sees the " \
              "page's container width instead of the :text default."

        TITLE_METHODS = [:add_title_with_name, :render_title_with_name].freeze

        RESTRICT_ON_SEND = [:container_class].freeze

        def on_send(node)
          enclosing = node.each_ancestor(:def, :defs).first
          return unless enclosing

          earlier = earlier_title_call(enclosing, node)
          return unless earlier

          add_offense(node, message: format(MSG, name: earlier.method_name))
        end

        private

        def earlier_title_call(enclosing, container_class_node)
          start = container_class_node.source_range.begin_pos
          enclosing.each_descendant(:send).find do |send_node|
            TITLE_METHODS.include?(send_node.method_name) &&
              send_node.source_range.begin_pos < start
          end
        end
      end
    end
  end
end
