# frozen_string_literal: true

# Abstract base class for all `Views::Controllers::*` Phlex view
# classes (and other classes under `Views::*` that render content).
#
# Inherits from `Components::Base` so view classes get the same
# Phlex/Rails wiring as ordinary components. Pre-registers the
# page-chrome helpers every action view uses — title, context nav,
# container class, project banner — so subclasses don't have to
# repeat `register_value_helper` calls for each one.
class Views::Base < Components::Base
  # All MO page-chrome helpers are side-effect-only (they call
  # `content_for(...)`), so they're value helpers — their return
  # value isn't inserted into rendered output.
  register_value_helper :add_page_title
  register_value_helper :add_new_title
  register_value_helper :add_edit_title
  register_value_helper :add_show_title
  register_value_helper :add_owner_naming
  register_value_helper :add_index_title
  register_value_helper :add_context_nav
  register_value_helper :add_project_banner
  register_value_helper :add_edit_icons
  register_value_helper :add_interest_icons
  register_value_helper :add_pager_for
  register_value_helper :add_pagination
  register_value_helper :add_sorter
  register_value_helper :container_class
  register_value_helper :column_classes
  # `Phlex::Rails::Helpers::ContentFor` exposes both `content_for(...)`
  # (read/write the buffer) and `content_for?(...)` (presence check)
  # in Phlex views. Page-chrome views (`Header`, `PageTitle`) need
  # `content_for?` for conditional rendering.
  include Phlex::Rails::Helpers::ContentFor

  register_value_helper :flash_error
  # `paginated_results` takes a block and emits the surrounding
  # pagination HTML around it — output helper, mark_safe so Phlex
  # trusts the returned SafeBuffer.
  register_output_helper :paginated_results, mark_safe: true
  # `controller` (the ActionController instance) is referenced from
  # Phlex views that build `Tab::RelatedQuery.new(...)` to compute
  # cross-model "related index" URLs (e.g. species-list show →
  # Locations / Images links). ERB views have it for free; Phlex
  # views need it registered.
  register_value_helper :controller

  # Stable request-context predicate exposed to all Phlex views.
  # Reads `session[:admin]` via `ApplicationController::Authentication`
  # (`base.helper_method(:permission?, :reviewer?, :in_admin_mode?)`),
  # so ERB views see it for free. Phlex needs the explicit register.
  # Matches `register_value_helper :permission?` in `Components::Base`.
  register_value_helper :in_admin_mode?
end
