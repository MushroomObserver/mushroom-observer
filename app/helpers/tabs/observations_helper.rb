# frozen_string_literal: true

module Tabs
  module ObservationsHelper
    # The single Tab + Collection definitions migrated to PORO
    # classes under `app/classes/tab/observation/*.rb` (15 single
    # Tabs + 12 Collections). The methods below remain as thin
    # legacy-shape adapters so existing helper-chain callers
    # (mostly ERB views + the `*_helper.rb` modules that compose
    # this one) keep working unchanged.
    #
    # Two HTML composers (`name_links_on_mo`, `user_name_links_web`)
    # remain at the helper layer because they pre-render their
    # constituent tabs to HTML strings via `context_nav_links`. They
    # call the new PORO Collections internally. Same for
    # `obs_name_description_tabs` which composes
    # `app/helpers/descriptions_helper.rb#list_descriptions`
    # (returns pre-rendered HTML strings) and stays as helper until
    # descriptions_helper itself migrates.

    # -------- single tabs ----------------------------------------

    def send_observer_question_tab(obs)
      ::Tab::Observation::SendQuestion.new(observation: obs).to_a
    end

    def observation_manage_lists_tab(obs, user)
      return unless user&.species_list_ids&.any?

      ::Tab::Observation::ManageLists.new(observation: obs,
                                          q_param: q_param).to_a
    end

    def observation_hide_thumbnail_map_tab(obs)
      ::Tab::Observation::HideThumbnailMap.new(observation: obs).to_a
    end

    def reuse_images_for_observation_tab(obs)
      ::Tab::Observation::ReuseImages.new(observation: obs).to_a
    end

    # -------- collections ----------------------------------------

    def obs_related_name_tabs(user, name)
      ::Tab::Observation::RelatedNameTabs.new(user: user,
                                              name: name).map(&:to_a)
    end

    def user_observation_web_name_tabs(user, name)
      ::Tab::Observation::WebNameTabs.new(user: user,
                                          name: name).map(&:to_a)
    end

    def observations_index_tabs(query:)
      ::Tab::Observation::IndexActions.new(
        query: query, where: params[:where],
        q_param: q_param(query), controller: controller
      ).map(&:to_a)
    end

    def observations_related_query_tabs(query)
      ::Tab::Observation::RelatedQueryActions.new(
        query: query, controller: controller
      ).map(&:to_a)
    end

    def observation_form_new_tabs
      ::Tab::Observation::FormNew.new(q_param: q_param).map(&:to_a)
    end

    def observation_form_edit_tabs(obs:)
      ::Tab::Observation::FormEdit.new(observation: obs).map(&:to_a)
    end

    def observation_maps_tabs(query:)
      ::Tab::Observation::MapsActions.new(
        query: query, controller: controller
      ).map(&:to_a)
    end

    def naming_form_new_tabs(obs:)
      ::Tab::Observation::NamingForm.new(observation: obs).map(&:to_a)
    end

    def naming_form_edit_tabs(obs:)
      ::Tab::Observation::NamingForm.new(observation: obs).map(&:to_a)
    end

    def naming_suggestion_tabs(obs:)
      ::Tab::Observation::NamingForm.new(observation: obs).map(&:to_a)
    end

    def observation_list_tabs(obs:)
      ::Tab::Observation::ListActions.new(observation: obs).map(&:to_a)
    end

    def observation_images_edit_tabs(image:)
      ::Tab::Observation::ImagesEdit.new(image: image).map(&:to_a)
    end

    def observation_images_reuse_tabs(obs:)
      ::Tab::Observation::ImagesReuse.new(observation: obs).map(&:to_a)
    end

    # -------- HTML composers (stay at helper layer) --------------

    def name_links_on_mo(user:, name:)
      tabs = context_nav_links(obs_related_name_tabs(user, name),
                               { class: "d-block" })
      tabs += obs_name_description_tabs(user, name)
      tabs += context_nav_links([occurrence_map_for_name_tab(name)],
                                { class: "d-block" })
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
      tabs = context_nav_links(user_observation_web_name_tabs(user, name),
                               { class: "d-block" })
      tabs.reject(&:empty?)
    end

    # -------- non-tab title + utility (stay at helper layer) -----

    def naming_form_new_title(obs:)
      :create_naming_title.t(id: obs.id)
    end

    def naming_form_edit_title(obs:)
      :edit_naming_title.t(id: obs.id)
    end

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
