# frozen_string_literal: true

# html used in tabsets
module Tabs
  module NamesHelper
    # assemble HTML for "tabset" for show_name
    # NOTE: "interest_icons" are part of this tabset, it still works as links
    def show_name_tabset(name:, user:)
      links = [
        [:show_name_edit_name.t, add_query_param(edit_name_path(name.id)),
         { class: "edit_name_link" }],
        [:show_name_add_name.t, add_query_param(new_name_path),
         { class: "new_name_link" }],
        edit_synonym_form_link(name),
        approve_synonym_form_link(name),
        deprecate_synonym_form_link(name),
        name_tracker_form_link(name, user),
        draw_interest_icons(name)
      ].reject(&:empty?)
      tabs = create_links(links)
      { pager_for: name, right: draw_tab_set(tabs) }
    end

    def basic_name_form_links(_name)
      []
    end

    def edit_synonym_form_link(name)
      return unless in_admin_mode? || !name.locked

      [:show_name_change_synonyms.t,
       add_query_param(edit_name_synonyms_path(name.id)),
       { class: "edit_name_synonym_link" }]
    end

    def approve_synonym_form_link(name)
      return unless name.deprecated && (in_admin_mode? || !name.locked)

      [:APPROVE.t, add_query_param(approve_name_synonym_form_path(name.id)),
       { class: "approve_name_synonym_link" }]
    end

    def deprecate_synonym_form_link(name)
      return unless !name.deprecated && (in_admin_mode? || !name.locked)

      [:DEPRECATE.t, add_query_param(deprecate_name_synonym_form_path(name.id)),
       { class: "deprecate_name_link" }]
    end

    def name_tracker_form_link(name, user)
      existing_name_tracker = NameTracker.find_by(name_id: name.id,
                                                  user_id: user.id)
      if existing_name_tracker
        [:show_name_email_tracking.t,
         add_query_param(edit_name_tracker_path(name.id)),
         { class: "edit_name_tracker_link" }]
      else
        [:show_name_email_tracking.t,
         add_query_param(new_name_tracker_path(name.id)),
         { class: "new_name_tracker_link" }]
      end
    end

    ##########################################################################
    #
    #    Index:

    def index_names_tabset(query:)
      links = [
        new_name_link,
        names_with_observations_link(query),
        observations_of_these_names_link(query),
        descriptions_of_these_names_link(query)
      ].reject(&:empty?)
      tabs = create_links(links)
      { right: draw_tab_set(tabs) }
    end

    def new_name_link
      [:name_index_add_name.t, new_name_path, { class: "new_name_link" }]
    end

    def names_with_observations_link(query)
      return unless query&.flavor == :with_observations

      [:all_objects.t(type: :name), names_path(with_observations: true),
       { class: "names_with_observations_link" }]
    end

    def observations_of_these_names_link(query)
      return unless query

      [*coerced_query_link(query, Observation),
       { class: "observations_of_these_names_link" }]
    end

    def descriptions_of_these_names_link(query)
      return unless query&.coercable?(:NameDescription)

      [:show_objects.t(type: :description),
       add_query_param(name_descriptions_path),
       { class: "descriptions_of_these_names_link" }]
    end

    ### Forms
    def name_form_new_links
      [
        [:all_objects.t(type: :name), names_path, { class: "names_link" }]
      ]
    end

    def name_form_edit_links(name)
      [
        [:cancel_and_show.t(type: :name),
         add_query_param(name_path(name.id)), { class: "name_link" }],
        [:all_objects.t(type: :name), names_path, { class: "names_link" }]
      ]
    end
  end
end
