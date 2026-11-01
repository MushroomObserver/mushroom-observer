# frozen_string_literal: true

module RuboCop
  module Cop
    module MO
      # Flags a controller passing a raw, unwrapped `params[...]` /
      # `params.dig(...)` read straight into a `Components::`/
      # `Views::` constructor's keyword argument -- either directly,
      # or via an ivar whose only assignment(s) in the class are
      # themselves unwrapped params reads.
      #
      # Rails parses a scalar param sent as a nested hash
      # (`?back[x]=1`) into an `ActionController::Parameters` object,
      # not a String. If that reaches a scalar-typed Literal `prop`
      # (String/Integer/etc.) on the constructed class, it raises
      # `Literal::TypeError` at construction instead of degrading
      # gracefully -- see .claude/rules/params_to_literal_props.md for
      # the full rule and why this isn't a blanket params.permit sweep.
      #
      # This cop can't see the target class's `prop` types (RuboCop
      # has no cross-file type table), so it's a conservative,
      # source-shape heuristic: ANY method call wrapping the params
      # read (`.to_s`, `.permit(...)`, `Integer(...)`, `string_param`,
      # `safe_integer`, `&TO_ID`, etc.) is treated as "already
      # guarded" and not flagged, even where the target prop actually
      # tolerates any shape (e.g. `_Any`, `Hash`). False positives are
      # possible; false negatives are not the concern this cop
      # optimizes for.
      #
      # @example
      #   # bad
      #   Views::Controllers::Foo::Bar.new(context: params[:context])
      #
      #   def set_ivars
      #     @back = params[:back]
      #   end
      #
      #   def render_it
      #     Views::Controllers::Foo::Bar.new(back: @back)
      #   end
      #
      #   # good
      #   Views::Controllers::Foo::Bar.new(
      #     context: params.permit(:context)[:context]
      #   )
      #
      #   def set_ivars
      #     @back = params.permit(:back)[:back]
      #   end
      class UnguardedParamsToProp < Base
        MSG = "Unguarded params read passed into a Components::/" \
              "Views:: constructor kwarg -- a nested-hash param " \
              "(?key[x]=1) raises Literal::TypeError instead of " \
              "degrading gracefully. Guard with " \
              "`params.permit(:key)[:key]` (see " \
              ".claude/rules/params_to_literal_props.md)."

        PHLEX_PREFIXES = ["Components::", "Views::"].freeze

        RESTRICT_ON_SEND = [:new].freeze

        def on_send(node)
          return unless component_or_view_constructor?(node)

          kwargs_node(node)&.pairs&.each do |pair|
            check_pair(pair, node)
          end
        end

        private

        def check_pair(pair, call_node)
          value = pair.value

          if raw_params_read?(value)
            add_offense(pair)
          elsif value.ivar_type?
            offending_ivasgn(value, call_node) { add_offense(pair) }
          end
        end

        def component_or_view_constructor?(node)
          receiver = node.receiver
          return false unless receiver&.const_type?

          name = receiver.source.delete_prefix("::")
          PHLEX_PREFIXES.any? { |prefix| name.start_with?(prefix) }
        end

        # Trailing keyword args land as a `hash` node under RuboCop's
        # builder (verified: RuboCop::AST::ProcessedSource never
        # produces a `:kwargs` node for `Foo.new(bar: baz)`) -- no
        # `kwargs_type?` branch needed.
        def kwargs_node(node)
          node.arguments.find(&:hash_type?)
        end

        # An ivar's constructor-kwarg use is offending only if EVERY
        # assignment to it in the same class is itself an unguarded
        # params read -- one guarded assignment (or one assignment
        # from something else entirely) means the ivar isn't reliably
        # a raw params value, so don't flag it.
        def offending_ivasgn(ivar_node, call_node)
          assignments = same_class_ivasgns(ivar_node, call_node)
          return if assignments.empty?

          yield if assignments.all? { |n| raw_params_read?(n.children[1]) }
        end

        def same_class_ivasgns(ivar_node, call_node)
          class_node = call_node.each_ancestor(:class, :sclass).first
          return [] unless class_node

          class_node.each_descendant(:ivasgn).select do |n|
            n.children.first == ivar_node.children.first &&
              owned_by?(n, class_node)
          end
        end

        # A node belongs to `class_node` only if `class_node` is its
        # nearest enclosing class/sclass -- excludes a nested class's
        # own same-named ivar from being attributed to the outer one.
        def owned_by?(node, class_node)
          node.each_ancestor(:class, :sclass).first.equal?(class_node)
        end

        def raw_params_read?(node)
          return false unless node

          node = node.children.first if node.or_type?
          bare_params_index?(node) || bare_params_dig?(node)
        end

        def bare_params_index?(node)
          (node.index_type? || (node.send_type? && node.method?(:[]))) &&
            bare_params_call?(node.receiver)
        end

        def bare_params_dig?(node)
          node.send_type? && node.method?(:dig) &&
            bare_params_call?(node.receiver)
        end

        def bare_params_call?(node)
          node&.send_type? && node.method?(:params) && node.receiver.nil?
        end
      end
    end
  end
end
