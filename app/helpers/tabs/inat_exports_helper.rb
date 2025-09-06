# frozen_string_literal: true

# html used in tabsets
module Tabs
  module InatExportsHelper
    def inat_export_form_new_tabs(source, requested_ids)
      if source == :observation
        [cancel_to_observation_tab(requested_ids.first)]
      else
        [cancel_to_observations_index_tab]
      end
    end

    def cancel_to_observation_tab(obs_id)
      InternalLink.new(:CANCEL.t, observation_path(obs_id)).tab
    end

    def cancel_to_observations_index_tab
      InternalLink.new(:CANCEL.t, observations_path).tab
    end
  end
end
