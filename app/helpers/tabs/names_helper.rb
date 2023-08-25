# frozen_string_literal: true

# html used in tabsets
module Tabs
  module NamesHelper
    # assemble links for "tabset" for show_name
    def name_show_tabs(name:, user:)
      [
        edit_name_tab(name),
        new_name_tab,
        edit_synonym_form_tab(name),
        approve_synonym_form_tab(name),
        deprecate_synonym_form_tab(name),
        name_tracker_form_tab(name, user)
      ].reject(&:empty?)
    end

    def edit_name_tab(name)
      [:show_name_edit_name.t, add_query_param(edit_name_path(name.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def new_name_tab
      [:show_name_add_name.t, add_query_param(new_name_path),
       { class: tab_id(__method__.to_s) }]
    end

    def edit_synonym_form_tab(name)
      return unless in_admin_mode? || !name.locked

      edit_name_synonym_tab(name)
    end

    def approve_synonym_form_tab(name)
      return unless name.deprecated && (in_admin_mode? || !name.locked)

      approve_name_synonym_tab(name)
    end

    def deprecate_synonym_form_tab(name)
      return unless !name.deprecated && (in_admin_mode? || !name.locked)

      deprecate_name_tab(name)
    end

    def edit_name_synonym_tab(name)
      [:show_name_change_synonyms.t,
       add_query_param(edit_name_synonyms_path(name.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def deprecate_name_tab(name)
      [:DEPRECATE.t, add_query_param(deprecate_name_synonym_form_path(name.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def approve_name_synonym_tab(name)
      [:APPROVE.t, add_query_param(approve_name_synonym_form_path(name.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def name_tracker_form_tab(name, user)
      existing_name_tracker = NameTracker.find_by(name_id: name.id,
                                                  user_id: user.id)
      if existing_name_tracker
        edit_name_tracker_tab(name)
      else
        new_name_tracker_tab(name)
      end
    end

    def name_map_tabs(name:, query:)
      [
        show_object_tab(name, :name_map_about.t(name: name.display_name)),
        coerced_location_query_tab(query),
        coerced_observation_query_tab(query)
      ]
    end

    def edit_name_tracker_tab(name)
      [:show_name_email_tracking.t,
       add_query_param(edit_name_tracker_path(name.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def new_name_tracker_tab(name)
      [:show_name_email_tracking.t,
       add_query_param(new_name_tracker_path(name.id)),
       { class: tab_id(__method__.to_s) }]
    end

    ##########################################################################
    #
    #    Index:

    def names_index_tabs(query:)
      [
        new_name_tab,
        names_with_observations_tab(query),
        coerced_observation_query_tab(query),
        descriptions_of_these_names_tab(query)
      ].reject(&:empty?)
    end

    def names_with_observations_tab(query)
      return unless query&.flavor == :with_observations

      [:all_objects.t(type: :name), names_path(with_observations: true),
       { class: tab_id(__method__.to_s) }]
    end

    def descriptions_of_these_names_tab(query)
      return unless query&.coercable?(:NameDescription)

      [:show_objects.t(type: :description),
       add_query_param(name_descriptions_path),
       { class: tab_id(__method__.to_s) }]
    end

    def names_index_sorts(query:)
      [
        ["name", :sort_by_name.t],
        ["created_at", :sort_by_created_at.t],
        [(query&.flavor == :by_rss_log ? "rss_log" : "updated_at"),
         :sort_by_updated_at.t],
        ["num_views", :sort_by_num_views.t]
      ]
    end

    ### Forms
    def name_form_new_tabs
      [names_index_tab]
    end

    def names_index_tab
      [:all_objects.t(type: :name), names_path,
       { class: tab_id(__method__.to_s) }]
    end

    def name_form_edit_tabs(name:)
      [object_return_tab(name),
       object_index_tab(name)]
    end

    def name_version_tabs(name:)
      [show_object_tab(name, :show_name.t(name: name.display_name))]
    end

    def name_forms_return_tabs(name:)
      [object_return_tab(name)]
    end
  end
end
