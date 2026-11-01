# frozen_string_literal: true

# Action template for `Observations::DownloadsController#new` — the
# "download observations" page. Sets the page title and renders
# `Downloads::Form` (the format / encoding / submit form).
module Views::Controllers::Observations::Downloads
  class New < Views::FullPageBase
    prop :query, ::Query

    def view_template
      add_page_title(:download_observations_title.t)
      render(Form.new(query: @query))
    end
  end
end
