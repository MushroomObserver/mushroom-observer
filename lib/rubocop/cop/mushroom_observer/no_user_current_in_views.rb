# frozen_string_literal: true

module RuboCop
  module Cop
    module MushroomObserver
      # Flags use of `User.current` in controllers and components.
      #
      # Controllers should use `@user` instead, which is set by
      # ApplicationController. Components should receive `user` as a prop.
      #
      # The only exceptions are in authentication-related code where
      # `User.current` is being *set* (not read).
      #
      # NOTE: This cop only runs on .rb files. For ERB views, manually
      # ensure `@user` is used instead of `User.current`.
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
      #   # bad (in component)
      #   User.current_location_format
      #
      #   # good (in component - add user prop)
      #   @user.location_format
      #
      class NoUserCurrentInViews < Base
        MSG = "Avoid `User.current`. In controllers, use `@user` " \
              "(set by ApplicationController). In components, pass " \
              "`user:` as a prop."

        # Match calls like User.current, User.current_id,
        # User.current_location_format
        # but NOT User.current = ... (assignment)
        def_node_matcher :user_current_read?, <<~PATTERN
          (send (const nil? :User) /^current/)
        PATTERN

        def on_send(node)
          return unless user_current_read?(node)
          # Don't flag if this is an assignment (User.current = ...)
          return if node.parent&.type == :send &&
                    node.parent.method_name.to_s.end_with?("=")

          add_offense(node)
        end
      end
    end
  end
end
