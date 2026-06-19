# frozen_string_literal: true

# Base class for `Views::Controllers::*` Phlex view classes and
# other view-layer classes under `Views::*` that render content
# (layouts' sub-pieces, sidebar items, etc.). Inherits from
# `Components::Base` so view classes get the same Phlex/Rails wiring
# as generic UI components.
#
# Things that belong here, not on `Components::Base`: view-layer
# state assumptions — `paginated_results` reads
# `content_for(:index_pagination_*)` slots only set on index pages;
# `reload_with_args` reads `request.url` and is meaningful only
# inside a request lifecycle. Pure UI components (modals, dropdowns,
# buttons) don't need either.
#
# Per-concern setters that pair with these readers (e.g.
# `add_pagination` for `paginated_results`) live on
# `Views::FullPageBase::*` modules — action views set; sub-partials
# read.
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

  # Rebuilds the current request URL with the given args merged /
  # cleared (e.g. `reload_with_args(merge: nil)` strips the `?merge=`
  # param). Used by the herbaria index merge-mode Alert + language
  # picker.
  def reload_with_args(new_args)
    uri = request.url.sub(%r{^\w+:/+[^/]+}, "")
    add_args_to_url(uri, new_args)
  end
end
