# frozen_string_literal: true

# Wraps an index result-set block in the `<div id="results">` shell with
# the pre-rendered pagination strips from `content_for(:index_pagination_*)`
# woven around it.
#
# The matching setter (`add_pagination`) lives on
# `Views::FullPageBase::IndexNav` — only action views set chrome;
# any view can read it via this component.
class Components::PaginatedResults < Components::Base
  prop :html_id, String, default: "results"

  def view_template(&block)
    encoded_q = URI.parse(observations_path(q: q_param)).query

    div(id: @html_id, data: { q: encoded_q }) do
      trusted_html(content_for(:index_pagination_top)) if
        content_for?(:index_pagination_top)
      yield
      trusted_html(content_for(:index_pagination_bottom)) if
        content_for?(:index_pagination_bottom)
    end
  end
end
