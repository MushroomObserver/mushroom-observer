# frozen_string_literal: true

# Action template for `Observations::DownloadsController#new` — the
# "download observations" page. Sets the page title and renders
# `Downloads::Form` (the format / encoding / submit form).
module Views::Controllers::Observations::Downloads
  class New < Views::Base
    prop :query_param, _Nilable(Hash), default: nil

    def view_template
      add_page_title(:download_observations_title.t)
      render(Form.new(query_param: @query_param))
    end
  end
end
