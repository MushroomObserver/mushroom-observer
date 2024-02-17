# frozen_string_literal: true

# html used in tabsets
module Tabs
  module NamesHelper
    # assemble links for "tabset" for show_name
    def name_show_tabs(name:)
      [
        edit_name_tab(name),
        new_name_tab
        # edit_synonym_form_tab(name),
        # approve_synonym_form_tab(name),
        # deprecate_synonym_form_tab(name),
        # name_tracker_form_tab(name, user)
      ].reject(&:empty?)
    end

    def edit_name_tab(name)
      [:show_name_edit_name.l, add_query_param(edit_name_path(name.id)),
       { class: tab_id(__method__.to_s), icon: :edit }]
    end

    def new_name_tab
      [:show_name_add_name.l, add_query_param(new_name_path),
       { class: tab_id(__method__.to_s), icon: :add }]
    end

    def edit_synonym_form_tab(name)
      return unless in_admin_mode? || !name.locked

      edit_name_synonym_tab(name)
    end

    # Can't approve a misspelling
    def approve_synonym_form_tab(name)
      return unless name.deprecated && name&.correct_spelling_id.nil? &&
                    (in_admin_mode? || !name.locked)

      approve_name_synonym_tab(name)
    end

    def deprecate_synonym_form_tab(name)
      return unless !name.deprecated && (in_admin_mode? || !name.locked)

      deprecate_name_tab(name)
    end

    def edit_name_synonym_tab(name)
      [:show_name_change_synonyms.l,
       add_query_param(edit_name_synonyms_path(name.id)),
       { class: tab_id(__method__.to_s), icon: :synonyms }]
    end

    # Note that the "deprecate" icon appears on approved names, so it's a
    # "check" to indicate at a glance that they're approved.
    def deprecate_name_tab(name)
      [:DEPRECATE.l, add_query_param(deprecate_name_synonym_form_path(name.id)),
       { class: tab_id(__method__.to_s), icon: :deprecate }]
    end

    # Likewise, the "approve" icon appears on deprecated names, so it's a "!"
    def approve_name_synonym_tab(name)
      [:APPROVE.l, add_query_param(approve_name_synonym_form_path(name.id)),
       { class: tab_id(__method__.to_s), icon: :approve }]
    end

    # Show name panels:
    # Nomenclature tabs
    def index_fungorum_record_tab(name)
      ["[##{name.icn_id}]", index_fungorum_record_url(name.icn_id),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def mycobank_record_tab(name)
      ["[##{name.icn_id}]", mycobank_record_url(name.icn_id),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def fungorum_gsd_synonymy_tab(name)
      [:gsd_species_synonymy.l, species_fungorum_gsd_synonymy(name.icn_id),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def fungorum_sf_synonymy_tab(name)
      [:sf_species_synonymy.l, species_fungorum_sf_synonymy(name.icn_id),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def mycobank_name_search_tab(name)
      [:mycobank_search.l, mycobank_name_search_url(name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def mycobank_basic_search_tab
      [:mycobank_search.l, mycobank_basic_search_url,
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    # lifeform tabs:
    def edit_name_lifeform_tab(name)
      [:EDIT.l, add_query_param(edit_name_lifeform_path(name.id)),
       { class: tab_id(__method__.to_s), icon: :edit }]
    end

    # description tabs:
    def name_show_description_tab(name)
      return unless name&.description

      [:show_name_see_more.l,
       add_query_param(name_description_path(name.description.id)),
       { class: tab_id(__method__.to_s), icon: :list }]
    end

    def name_edit_description_tab(name)
      return unless name&.description

      [:EDIT.l, edit_name_description_path(name.description.id),
       { class: tab_id(__method__.to_s), icon: :edit }]
    end

    def name_new_description_tab(name)
      [:show_name_create_description.l,
       new_name_description_path(name.id),
       { class: tab_id(__method__.to_s), icon: :add }]
    end

    # classification tabs:
    def name_edit_classification_tab(name)
      [:EDIT.l, edit_name_classification_path(name.id),
       { class: tab_id(__method__.to_s), icon: :edit }]
    end

    # Show name, obs menu. Also on Obs show, name section
    def mycoportal_name_tab(name)
      ["MyCoPortal", mycoportal_url(name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def eol_name_tab(name)
      ["EOL", name.eol_url,
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def google_images_for_name_tab(name)
      [:google_images.t,
       format("https://images.google.com/images?q=%s", name.real_text_name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def gbif_name_tab(name)
      ["GBIF", gbif_name_search_url(name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def inat_name_tab(name)
      ["iNaturalist", inat_name_search_url(name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def index_fungorum_name_search_tab(name)
      [:index_fungorum_web_search.l, index_fungorum_name_search_url(name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def ncbi_nucleotide_term_tab(name)
      ["NCBI Nucleotide", ncbi_nucleotide_term_search_url(name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def mushroomexpert_name_tab(name)
      ["MushroomExpert", mushroomexpert_name_search_url(name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def mycoguide_name_tab(name)
      ["MycoGuide", mycoguide_name_search_url(name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def wikipedia_term_tab(name)
      ["Wikipedia", wikipedia_term_search_url(name),
       { class: tab_id(__method__.to_s), target: :_blank, rel: :noopener }]
    end

    def occurrence_map_for_name_tab(name)
      [:show_name_distribution_map.t,
       add_query_param(map_name_path(id: name.id)),
       { class: tab_id(__method__.to_s), data: { action: "links#disable" } }]
    end

    # Others
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
       { class: tab_id(__method__.to_s), icon: :tracking }]
    end

    def new_name_tracker_tab(name)
      [:show_name_email_tracking.t,
       add_query_param(new_name_tracker_path(name.id)),
       { class: tab_id(__method__.to_s), icon: :tracking }]
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

    def all_names_index_tabs(query:)
      [
        new_name_tab,
        all_names_tab(query),
        coerced_observation_query_tab(query)
      ].reject(&:empty?)
    end

    def all_names_tab(query)
      return if query&.flavor == :all || query&.flavor&.empty?

      [:all_objects.t(type: :name), names_path,
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
