# frozen_string_literal: true

module Tabs
  module ObservationsHelper
    # All tab definitions have migrated to PORO classes under
    # `app/classes/tab/observation/*.rb` and callers sweep them
    # directly. The HTML composers + non-tab utilities below
    # remain here pending relocation to
    # `app/helpers/observations_helper.rb` (and, in the case of
    # `obs_name_description_tabs`, the migration of
    # `descriptions_helper#list_descriptions`).

    # -------- HTML composers -------------------------------------

    def name_links_on_mo(user:, name:)
      related = Tab::Observation::RelatedNameTabs.new(
        user: user, name: name
      ).map(&:to_a)
      occ_map = Tab::Name::OccurrenceMap.new(name: name).to_a
      tabs = context_nav_links(related, { class: "d-block" })
      tabs += obs_name_description_tabs(user, name)
      tabs += context_nav_links([occ_map], { class: "d-block" })
      tabs.reject(&:empty?)
    end

    # composes `list_descriptions` from descriptions_helper.rb (HTML).
    # Migrates when descriptions_helper itself migrates.
    def obs_name_description_tabs(user, name)
      list_descriptions(user: user, object: name, type: :name)&.map do |link|
        tag.div(link)
      end
    end

    def user_name_links_web(user, name:)
      web = Tab::Observation::WebNameTabs.new(
        user: user, name: name
      ).map(&:to_a)
      context_nav_links(web, { class: "d-block" }).reject(&:empty?)
    end

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

    def obs_details_links(obs)
      print_labels_button(obs)
    end

    def print_labels_button(obs)
      name = :download_observations_print_labels.l
      query = Query.lookup(Observation, id_in_set: [obs.id])
      path = add_q_param(observations_downloads_path(commit: name), query)

      post_button(name: name, path: path, icon: :print,
                  class: "print_label_observation_#{obs.id}",
                  form: { data: { turbo: false } })
    end
  end
end
