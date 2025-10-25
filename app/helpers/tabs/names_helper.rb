# frozen_string_literal: true

# html used in tabsets
module Tabs
  module NamesHelper
    def edit_name_tab(name)
      InternalLink::Model.new(
        :show_name_edit_name.l, name,
        edit_name_path(name.id),
        html_options: { icon: :edit }
      ).tab
    end

    def new_name_tab
      InternalLink::Model.new(
        :show_name_add_name.l, Name,
        new_name_path,
        html_options: { icon: :add }
      ).tab
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
      InternalLink::Model.new(
        :show_name_change_synonyms.l, name,
        edit_synonyms_of_name_path(name.id),
        html_options: { icon: :synonyms }
      ).tab
    end

    # Note that the "deprecate" icon appears on approved names, so it's a
    # "check" to indicate at a glance that they're approved.
    def deprecate_name_tab(name)
      InternalLink::Model.new(
        :DEPRECATE.l, name,
        form_to_deprecate_synonym_of_name_path(name.id),
        html_options: { icon: :deprecate }
      ).tab
    end

    # Likewise, the "approve" icon appears on deprecated names, so it's a "!"
    def approve_name_synonym_tab(name)
      InternalLink::Model.new(
        :APPROVE.l, name,
        form_to_approve_synonym_of_name_path(name.id),
        html_options: { icon: :approve }
      ).tab
    end

    # Show name panels:
    # Nomenclature tabs
    def index_fungorum_search_page_tab
      InternalLink.new(
        :index_fungorum_search.l,
        index_fungorum_search_page_url,
        html_options: { target: :_blank, rel: :noopener }
      ).tab
    end

    def index_fungorum_record_tab(name)
      external_name_tab("[##{name.icn_id}]", name,
                        index_fungorum_record_url(name.icn_id),
                        alt_title: "index_fungorum_record")
    end

    def external_name_tab(title, name, url, alt_title: nil)
      InternalLink::Model.new(
        title, name, url,
        html_options: { target: :_blank, rel: :noopener },
        alt_title:
      ).tab
    end

    ## In Progress

    def mycobank_record_tab(name)
      external_name_tab("[##{name.icn_id}]", name,
                        mycobank_record_url(name.icn_id),
                        alt_title: :mycobank.t)
    end

    def fungorum_gsd_synonymy_tab(name)
      external_name_tab(:gsd_species_synonymy.l, name,
                        species_fungorum_gsd_synonymy(name.icn_id))
    end

    def fungorum_sf_synonymy_tab(name)
      external_name_tab(:sf_species_synonymy.l, name,
                        species_fungorum_sf_synonymy(name.icn_id))
    end

    def mycobank_name_search_tab(name)
      external_name_tab(:mycobank_search.l, name,
                        mycobank_name_search_url(name))
    end

    def mycobank_basic_search_tab
      InternalLink.new(
        :mycobank_search.l,
        mycobank_basic_search_url,
        html_options: { target: :_blank, rel: :noopener }
      ).tab
    end

    # lifeform tabs:
    def edit_name_lifeform_tab(name)
      InternalLink::Model.new(
        :EDIT.l, name,
        edit_lifeform_of_name_path(name.id),
        html_options: { icon: :edit }
      ).tab
    end

    # description tabs:
    def name_show_description_tab(name)
      return unless name&.description

      InternalLink::Model.new(
        :show_name_see_more.l, name,
        name_description_path(name.description.id),
        html_options: { icon: :list }
      ).tab
    end

    def name_edit_description_tab(name)
      description = name&.description
      return unless description && permission?(description)

      InternalLink::Model.new(
        :EDIT.l, name,
        edit_name_description_path(description.id),
        html_options: { icon: :edit }
      ).tab
    end

    def name_new_description_tab(name)
      InternalLink::Model.new(
        :show_name_create_description.l, name,
        new_name_description_path(name.id),
        html_options: { icon: :add }
      ).tab
    end

    # classification tabs:
    def name_edit_classification_tab(name)
      InternalLink::Model.new(
        :EDIT.l, name,
        edit_classification_of_name_path(name.id),
        html_options: { icon: :edit }
      ).tab
    end

    def eol_name_tab(name)
      external_name_tab("EOL", name, name.eol_url)
    end

    # def google_images_for_name_tab(name)
    #   url = format("https://images.google.com/images?q=%s",
    #                name.real_text_name)
    #   external_name_tab(:google_images.t, name, url)
    # end

    def user_google_images_for_name_tab(user, name)
      url = format("https://images.google.com/images?q=%s",
                   name.user_real_text_name(user))
      external_name_tab(:google_images.t, name, url)
    end

    def ascomycete_org_name_tab(name)
      external_name_tab("Ascomycete.org", name, ascomycete_org_name_url(name))
    end

    def gbif_name_tab(name)
      external_name_tab("GBIF", name, gbif_name_search_url(name))
    end

    def google_name_tab(name)
      external_name_tab(:google_name_search.l, name,
                        google_name_search_url(name))
    end

    def inat_name_tab(name)
      external_name_tab("iNaturalist", name, inat_name_search_url(name))
    end

    def index_fungorum_name_search_tab(name)
      external_name_tab(:index_fungorum_web_search.l, name,
                        index_fungorum_name_web_search_url(name))
    end

    def ncbi_nucleotide_term_tab(name)
      external_name_tab("NCBI Nucleotide", name,
                        ncbi_nucleotide_term_search_url(name))
    end

    def mushroomexpert_name_tab(name)
      external_name_tab("MushroomExpert", name,
                        mushroomexpert_name_web_search_url(name))
    end

    def mycoportal_name_tab(name)
      external_name_tab("MyCoPortal", name, mycoportal_url(name))
    end

    def wikipedia_term_tab(name)
      external_name_tab("Wikipedia", name, wikipedia_term_search_url(name))
    end

    def occurrence_map_for_name_tab(name)
      InternalLink::Model.new(
        :show_name_distribution_map.t, name,
        add_q_param(map_name_path(id: name.id)),
        html_options: { data: { action: "links#disable" } }
      ).tab
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

    # Note that a name map query is an observations (of name) query.
    # "Related records" are going to be related to the observations.
    def name_map_tabs(name:, query:)
      [
        show_object_tab(name, :name_map_about.t(name: name.display_name)),
        related_locations_tab(:Observation, query),
        related_observations_tab(:Observation, query)
      ]
    end

    def edit_name_tracker_tab(name)
      InternalLink::Model.new(
        :show_name_email_tracking.t, name,
        edit_tracker_of_name_path(name.id),
        html_options: { icon: :tracking }
      ).tab
    end

    def new_name_tracker_tab(name)
      InternalLink::Model.new(
        :show_name_email_tracking.t, name,
        new_tracker_of_name_path(name.id),
        html_options: { icon: :tracking }
      ).tab
    end

    ##########################################################################
    #
    #    Index:

    # Dead code?
    # def names_index_tabs(query:)
    #   [
    #     new_name_tab,
    #     names_with_observations_tab(query),
    #     related_observations_tab(:Name, query),
    #     related_descriptions_tab(query)
    #   ].reject(&:empty?)
    # end

    # def names_with_observations_tab(query)
    #   return unless query&.params&.dig(:has_observations)

    #   InternalLink.new(
    #     :all_objects.t(type: :name), names_path(has_observations: true)
    #   ).tab
    # end

    # def related_descriptions_tab(names_query)
    #   # return unless query&.coercable?(:NameDescription)

    #   desc_query = Query.lookup(:NameDescription, name_query: names_query)
    #   [:show_objects.t(type: :description),
    #    add_q_param(name_descriptions_index_path, desc_query),
    #    { class: tab_id(__method__.to_s) }]
    # end

    def all_names_index_tabs(query:)
      [
        new_name_tab,
        all_names_tab(query),
        related_observations_tab(:Name, query)
      ].reject(&:empty?)
    end

    def all_names_tab(query)
      return unless query&.params&.dig(:has_observations)

      InternalLink.new(
        :all_objects.t(type: :name), names_path
      ).tab
    end

    def names_index_sorts(query: nil)
      rss_log = query&.params&.dig(:order_by) == :rss_log
      [
        ["name", :sort_by_name.t],
        ["created_at", :sort_by_created_at.t],
        [(rss_log ? "rss_log" : "updated_at"), :sort_by_updated_at.t],
        ["num_views", :sort_by_num_views.t]
      ]
    end

    ### Forms
    def name_form_new_tabs
      [names_index_tab]
    end

    def names_index_tab
      InternalLink.new(
        :all_objects.t(type: :name), names_path
      ).tab
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
