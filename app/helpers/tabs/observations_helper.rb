# frozen_string_literal: true

module Tabs
  module ObservationsHelper
    # All tab definitions have migrated to PORO classes under
    # `app/classes/tab/observation/*.rb` and callers sweep them
    # directly. The HTML composers that lived here previously
    # (`name_links_on_mo` / `user_name_links_web` /
    # `obs_name_description_tabs` / `observation_show_image_links`
    # / `obs_details_links` / `print_labels_button`) have been
    # inlined into `Views::Controllers::Observations::Show::*` —
    # each panel owns its own helper logic now.

    # -------- non-tab utility ------------------------------------

    def observations_index_sorts
      [["rss_log", :sort_by_activity.l],
       ["date", :sort_by_date.l],
       ["created_at", :sort_by_posted.l],
       ["name", :sort_by_name.l],
       ["user", :sort_by_user.l],
       ["confidence", :sort_by_confidence.l],
       ["thumbnail_quality", :sort_by_thumbnail_quality.l],
       ["num_views", :sort_by_num_views.l]].freeze
    end
  end
end
