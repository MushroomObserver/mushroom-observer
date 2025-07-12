# frozen_string_literal: true

# html used in tabsets
module Tabs
  module InatImportsHelper
    def inat_import_form_new_tabs
      [cancel_to_observation_create_tab]
    end

    def cancel_to_observation_create_tab
      InternalLink.new(:cancel_and_create.t(type: :OBSERVATION),
                       new_observation_path).tab
    end
  end
end
