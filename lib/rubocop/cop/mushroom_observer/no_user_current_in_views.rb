# frozen_string_literal: true

module RuboCop
  module Cop
    module MushroomObserver
      # Flags reads of `User.current` in controllers, views, and
      # components — including the `::User.current` cbase-qualified
      # form. No exemptions: controllers should use `@user` (set by
      # ApplicationController); views/components should receive
      # `user:` as a prop instead of reaching for the global.
      #
      # Authentication code that *sets* `User.current` (the mechanism
      # models rely on outside request context) isn't flagged, because
      # the pattern only matches no-arg reads - an assignment send
      # carries the RHS as a 3rd child and never matches.
      #
      # @example
      #   # bad (in controller)
      #   User.current
      #   User.current_id
      #
      #   # good (in controller)
      #   @user
      #   @user.id
      #
      #   # bad (in component/view)
      #   User.current_location_format
      #   ::User.current_location_format
      #
      #   # good (in component/view - add user prop)
      #   @user.location_format
      #
      class NoUserCurrentInViews < Base
        MSG = "Avoid `User.current`. In controllers, use `@user` " \
              "(set by ApplicationController). In components, pass " \
              "`user:` as a prop."

        # Match calls like User.current, User.current_id,
        # User.current_location_format, ::User.current (cbase-qualified).
        # The fixed 2-child shape (receiver + selector, no args) already
        # excludes `User.current = ...` on its own: an assignment send
        # carries the RHS as a 3rd child, so it never matches here -
        # no separate "is this an assignment" guard needed (a previous
        # version tried to guard via `parent.method_name.end_with?("=")`,
        # which also misfired on `==`/`>=`/`<=`/`!=` comparisons).
        def_node_matcher :user_current_read?, <<~PATTERN
          (send (const {nil? (cbase)} :User) /^current/)
        PATTERN

        def on_send(node)
          return unless user_current_read?(node)

          add_offense(node)
        end
      end
    end
  end
end
