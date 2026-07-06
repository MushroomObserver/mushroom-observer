# frozen_string_literal: true

# Shared "how does this look to a particular viewer" formatting
# logic, mixed into both ApplicationController (plain Ruby controller
# code - comments_controller.rb's modal_title, etc.) and
# Components::Base (Phlex views and mailers - Views::Mailers::Base
# inherits Components::Base, and mailers have no "current user" at
# all, so they always pass an explicit override).
#
# Each includer supplies its own `default_viewer` (@user for
# controllers, current_user for Phlex) rather than this module
# picking one - the two contexts read "the current viewer" through
# different mechanisms.
module ViewerAwareFormat
  # `obj` is frequently polymorphic (a Comment/Interest/RssLog
  # target, etc.) - only some target types (Name, Observation,
  # Naming) have a viewer-aware user_unique_format_name. Falls back
  # to the plain unique_format_name for the rest.
  def viewer_aware_unique_format_name(obj, user = default_viewer)
    if obj.respond_to?(:user_unique_format_name)
      obj.user_unique_format_name(user)
    else
      obj.unique_format_name
    end
  end

  # Location's display name is postal/scientific-order depending on
  # the viewer's preference. `Location.user_format` already takes an
  # explicit user - this just supplies the default when the caller
  # doesn't have one handy.
  def viewer_aware_location_format(location, user = default_viewer)
    return nil unless location

    Location.user_format(user, location.name)
  end
end
