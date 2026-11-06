# frozen_string_literal: true

# Action template for `Observations::DownloadsController#new` — the
# "download observations" page. Shows the project banner when the
# query is scoped to a single project, sets the page title, and
# renders `Downloads::Form` (the format / encoding / submit form).
module Views::Controllers::Observations::Downloads
  class New < Views::FullPageBase
    prop :query, ::Query
    prop :project, _Nilable(::Project), default: nil

    def view_template
      add_project_banner(@project) if @project
      add_page_title(:download_observations_title.t)
      add_query_filters(@query)
      render(Form.new(query: @query))
    end
  end
end
