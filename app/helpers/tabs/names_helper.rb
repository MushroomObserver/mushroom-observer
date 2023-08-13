# frozen_string_literal: true

# html used in tabsets
module Tabs
  module NamesHelper
    # assemble links for "tabset" for show_name
    def name_show_links(name:, user:)
      [
        edit_name_link(name),
        new_name_link,
        edit_synonym_form_link(name),
        approve_synonym_form_link(name),
        deprecate_synonym_form_link(name),
        name_tracker_form_link(name, user)
      ].reject(&:empty?)
    end

    def edit_name_link(name)
      [:show_name_edit_name.t, add_query_param(edit_name_path(name.id)),
       { class: __method__.to_s }]
    end

    def new_name_link
      [:show_name_add_name.t, add_query_param(new_name_path),
       { class: __method__.to_s }]
    end

    def edit_synonym_form_link(name)
      return unless in_admin_mode? || !name.locked

      edit_name_synonym_link(name)
    end

    def approve_synonym_form_link(name)
      return unless name.deprecated && (in_admin_mode? || !name.locked)

      approve_name_synonym_link(name)
    end

    def deprecate_synonym_form_link(name)
      return unless !name.deprecated && (in_admin_mode? || !name.locked)

      deprecate_name_link(name)
    end

    def edit_name_synonym_link(name)
      [:show_name_change_synonyms.t,
       add_query_param(edit_name_synonyms_path(name.id)),
       { class: __method__.to_s }]
    end

    def deprecate_name_link(name)
      [:DEPRECATE.t, add_query_param(deprecate_name_synonym_form_path(name.id)),
       { class: __method__.to_s }]
    end

    def approve_name_synonym_link(name)
      [:APPROVE.t, add_query_param(approve_name_synonym_form_path(name.id)),
       { class: __method__.to_s }]
    end

    def name_tracker_form_link(name, user)
      existing_name_tracker = NameTracker.find_by(name_id: name.id,
                                                  user_id: user.id)
      if existing_name_tracker
        edit_name_tracker_link(name)
      else
        new_name_tracker_link(name)
      end
    end

    def name_map_show_links(name:, query:)
      [
        show_object_link(name, :name_map_about.t(name: name.display_name)),
        coerced_location_query_link(query),
        coerced_observation_query_link(query)
      ]
    end

    def edit_name_tracker_link(name)
      [:show_name_email_tracking.t,
       add_query_param(edit_name_tracker_path(name.id)),
       { class: __method__.to_s }]
    end

    def new_name_tracker_link(name)
      [:show_name_email_tracking.t,
       add_query_param(new_name_tracker_path(name.id)),
       { class: __method__.to_s }]
    end

    ##########################################################################
    #
    #    Index:

    def names_index_links(query:)
      [
        new_name_link,
        names_with_observations_link(query),
        coerced_observation_query_link(query),
        descriptions_of_these_names_link(query)
      ].reject(&:empty?)
    end

    def names_with_observations_link(query)
      return unless query&.flavor == :with_observations

      [:all_objects.t(type: :name), names_path(with_observations: true),
       { class: __method__.to_s }]
    end

    def descriptions_of_these_names_link(query)
      return unless query&.coercable?(:NameDescription)

      [:show_objects.t(type: :description),
       add_query_param(name_descriptions_path),
       { class: __method__.to_s }]
    end

    ### Forms
    def name_form_new_links
      [object_index_link(name)]
    end

    def name_form_edit_links(name:)
      [
        object_return_link(name),
        object_index_link(name)
      ]
    end

    def name_versions_links(name:)
      [show_object_link(name, :show_name.t(name: name.display_name))]
    end
  end
end
