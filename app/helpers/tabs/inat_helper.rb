# frozen_string_literal: true

module Tabs
  module InatHelper
    def new_inat_import_tab
      [:import_observation_from_inat.t,
       add_query_param(new_observations_inat_import_path),
       { class: tab_id(__method__.to_s) }]
    end
  end
end
