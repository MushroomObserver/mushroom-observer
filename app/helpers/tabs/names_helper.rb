# frozen_string_literal: true

# html used in tabsets
module Tabs
  module NamesHelper
    # assemble HTML for "tabset" for show_name
    def show_name_tabset(name:, user:)
      tabs = [
        basic_name_form_links(name),
        edit_synonym_form_link(name),
        approve_synonym_form_link(name),
        deprecate_synonym_form_link(name),
        name_tracker_form_link(name, user),
        draw_interest_icons(name)
      ].flatten.reject(&:empty?)
      { pager_for: name, right: draw_tab_set(tabs) }
    end

    def basic_name_form_links(name)
      [
        link_with_query(:show_name_edit_name.t, edit_name_path(name.id)),
        link_with_query(:show_name_add_name.t, new_name_path)
      ]
    end

    def edit_synonym_form_link(name)
      return unless in_admin_mode? || !name.locked

      link_with_query(:show_name_change_synonyms.t,
                      edit_name_synonyms_path(name.id))
    end

    def approve_synonym_form_link(name)
      return unless name.deprecated && (in_admin_mode? || !name.locked)

      link_with_query(:APPROVE.t, approve_name_synonym_form_path(name.id))
    end

    def deprecate_synonym_form_link(name)
      return unless !name.deprecated && (in_admin_mode? || !name.locked)

      link_with_query(:DEPRECATE.t, deprecate_name_synonym_form_path(name.id))
    end

    def name_tracker_form_link(name, user)
      existing_name_tracker = NameTracker.find_by(name_id: name.id,
                                                  user_id: user.id)
      if existing_name_tracker
        link_with_query(:show_name_email_tracking.t,
                        edit_name_tracker_path(name.id))
      else
        link_with_query(:show_name_email_tracking.t,
                        new_name_tracker_path(name.id))
      end
    end

    ##########################################################################
    #
    #    Index:

    def index_names_tabset(query:)
      tabs = [
        new_name_link,
        names_with_observations_link(query),
        observations_of_these_names_link(query),
        descriptions_of_these_names_link(query)
      ].flatten.reject(&:empty?)
      { right: draw_tab_set(tabs) }
    end

    def new_name_link
      link_to(:name_index_add_name.t, new_name_path)
    end

    def names_with_observations_link(query)
      return unless query&.flavor == :with_observations

      link_to(:all_objects.t(type: :name), names_path(with_observations: true))
    end

    def observations_of_these_names_link(query)
      return unless query

      coerced_query_link(query, Observation)
    end

    def descriptions_of_these_names_link(query)
      return unless query&.coercable?(:NameDescription)

      link_to(:show_objects.t(type: :description),
              name_descriptions_path(q: get_query_param(query)))
    end
  end
end
