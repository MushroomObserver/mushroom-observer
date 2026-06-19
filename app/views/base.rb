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
  # `paginated_results { render_results }` — wraps the supplied result-set
  # block in the `<div id="results" data-q="...">` shell with the
  # pre-rendered `:index_pagination_top` / `:index_pagination_bottom`
  # strips woven around it. Action templates and sub-partials that own
  # the results body (e.g. `Shared::ImagesToReuseForm`,
  # `VisualGroups::ImageMatrix`) both call it. The matching
  # `add_pagination` SETTER (which fills the content_for slots this
  # method reads) lives on `Views::FullPageBase::IndexNav` because only
  # action views set chrome.
  def paginated_results(args = {})
    html_id = args[:html_id] || "results"
    encoded_q = URI.parse(observations_path(q: q_param)).query

    div(id: html_id, data: { q: encoded_q }) do
      if content_for?(:index_pagination_top)
        trusted_html(content_for(:index_pagination_top))
      end
      yield
      if content_for?(:index_pagination_bottom)
        trusted_html(content_for(:index_pagination_bottom))
      end
    end
  end

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
