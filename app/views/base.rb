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
  register_value_helper :add_context_nav
  # `context_nav_links([tuples])` — array-version of `context_nav_link`,
  # used where a view wraps each link manually. Composes the underlying
  # link-building chain in Header::ContextNavHelper.
  register_value_helper :context_nav_links
  register_value_helper :container_class
  register_value_helper :column_classes
  # `content_padding` is the MO-specific layout-class setter
  # (`:panels` / `:no_panels` / etc.) that the application layout
  # reads. Not part of `Phlex::Rails::Helpers::ContentFor`.
  # (`Phlex::Rails::Helpers::ContentFor` itself is on Components::Base
  # — `content_for` and `content_for?` are available everywhere.)
  register_value_helper :content_padding
  register_value_helper :flash_error
  # Rebuilds the current request URL with the given args merged /
  # cleared (e.g. `reload_with_args(merge: nil)` strips the `?merge=`
  # param). Used by the herbaria index merge-mode Alert.
  register_value_helper :reload_with_args
  # Stable request-context predicate exposed to all Phlex views.
  # Reads `session[:admin]` via `ApplicationController::Authentication`
  # (`base.helper_method(:permission?, :reviewer?, :in_admin_mode?)`),
  # so ERB views see it for free. Phlex needs the explicit register.
  # Matches `register_value_helper :permission?` in `Components::Base`.
  register_value_helper :in_admin_mode?
end
