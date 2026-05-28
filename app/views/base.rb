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
  register_value_helper :add_index_title
  register_value_helper :add_context_nav
  register_value_helper :add_project_banner
  register_value_helper :add_edit_icons
  register_value_helper :add_interest_icons
  register_value_helper :add_pager_for
  register_value_helper :add_pagination
  register_value_helper :add_sorter
  register_value_helper :container_class
  register_value_helper :content_for
end
