# frozen_string_literal: true

module Tabs
  module ChecklistsHelper
    def checklist_show_tabs(user:, list:)
      if user
        checklist_for_user_tabs(user)
      elsif list
        checklist_for_species_list_tabs(list)
      else
        checklist_for_site_tabs
      end
    end

    def checklist_for_user_tabs(user)
      [
        user_profile_tab(user),
        user_observations_tab(user),
        email_user_question_tab(user)
      ]
    end

    def checklist_for_species_list_tabs(list)
      links = [
        show_object_tab(list)
      ]
      if permission?(list)
        links += [
          edit_species_list_tab(list)
        ]
      end
      links
    end

    def checklist_for_site_tabs
      [
        site_contributors_tab,
        info_site_stats_tab
      ]
    end

    def site_checklist_tab
      InternalLink.new(
        :site_stats_observed_taxa.t, checklist_path
      ).tab
    end
  end
end
