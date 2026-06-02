# frozen_string_literal: true

module Tabs
  module NamesHelper
    # The action tabs + 3 observation-needed external links migrated
    # to PORO classes under `app/classes/tab/name/*.rb`. The
    # remaining external link tabs (eol, gbif, ncbi, ascomycete.org,
    # mushroomexpert, wikipedia, index_fungorum, etc.) stay as
    # helper methods using the `external_name_tab` utility below
    # — they migrate in a follow-up PR or together with
    # `app/helpers/object_link_helper.rb`'s URL builders.

    # -------- action tabs ----------------------------------------

    def edit_name_tab(name)
      ::Tab::Name::Edit.new(name: name).to_a
    end

    def edit_synonym_form_tab(name)
      return unless in_admin_mode? || !name.locked

      edit_name_synonym_tab(name)
    end

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
      ::Tab::Name::EditSynonym.new(name: name).to_a
    end

    def deprecate_name_tab(name)
      ::Tab::Name::Deprecate.new(name: name).to_a
    end

    def approve_name_synonym_tab(name)
      ::Tab::Name::Approve.new(name: name).to_a
    end

    def edit_name_lifeform_tab(name)
      ::Tab::Name::EditLifeform.new(name: name).to_a
    end

    def name_show_description_tab(name)
      return unless name&.description

      ::Tab::Name::ShowDescription.new(name: name).to_a
    end

    def name_edit_description_tab(name)
      description = name&.description
      return unless description && permission?(description)

      ::Tab::Name::EditDescription.new(name: name).to_a
    end

    def name_new_description_tab(name)
      ::Tab::Name::NewDescription.new(name: name).to_a
    end

    def name_edit_classification_tab(name)
      ::Tab::Name::EditClassification.new(name: name).to_a
    end

    def occurrence_map_for_name_tab(name)
      ::Tab::Name::OccurrenceMap.new(name: name).to_a
    end

    def name_tracker_form_tab(name, user)
      existing = NameTracker.find_by(name_id: name.id, user_id: user.id)
      existing ? edit_name_tracker_tab(name) : new_name_tracker_tab(name)
    end

    def edit_name_tracker_tab(name)
      ::Tab::Name::EditTracker.new(name: name).to_a
    end

    def new_name_tracker_tab(name)
      ::Tab::Name::NewTracker.new(name: name).to_a
    end

    def names_index_tab
      ::Tab::Name::Index.new.to_a
    end

    # -------- 3 external tabs that observations composers use ----

    def mycoportal_name_tab(name)
      ::Tab::Name::Mycoportal.new(name: name).to_a
    end

    def mycobank_name_search_tab(name)
      ::Tab::Name::MycobankSearch.new(name: name).to_a
    end

    def user_google_images_for_name_tab(user, name)
      ::Tab::Name::UserGoogleImages.new(name: name, user: user).to_a
    end

    # -------- collections ----------------------------------------

    def name_map_tabs(name:, query:)
      ::Tab::Name::MapActions.new(name: name, query: query,
                                  controller: controller).map(&:to_a)
    end

    def all_names_index_tabs(query:)
      ::Tab::Name::IndexActions.new(query: query,
                                    controller: controller).map(&:to_a)
    end

    def name_form_new_tabs
      ::Tab::Name::FormNew.new.map(&:to_a)
    end

    def name_form_edit_tabs(name:)
      ::Tab::Name::FormEdit.new(name: name,
                                q_param: q_param).map(&:to_a)
    end

    def name_version_tabs(name:)
      ::Tab::Name::VersionActions.new(name: name).map(&:to_a)
    end

    def name_forms_return_tabs(name:)
      ::Tab::Name::FormsReturn.new(name: name).map(&:to_a)
    end

    # -------- unconverted external link tabs ---------------------
    # These stay as helper methods until a follow-up PR migrates
    # them alongside `object_link_helper.rb`'s URL builders.
    # Used from the name show page's name-links panel, not from
    # cross-domain composers.

    def external_name_tab(title, name, url, alt_title: nil)
      InternalLink::Model.new(
        title, name, url,
        html_options: { target: :_blank, rel: :noopener },
        alt_title:
      ).tab
    end

    def index_fungorum_search_page_tab
      InternalLink.new(
        :index_fungorum_search.l, index_fungorum_search_page_url,
        html_options: { target: :_blank, rel: :noopener }
      ).tab
    end

    def index_fungorum_record_tab(name)
      external_name_tab("[##{name.icn_id}]", name,
                        index_fungorum_record_url(name.icn_id),
                        alt_title: "index_fungorum_record")
    end

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

    def mycobank_basic_search_tab
      InternalLink.new(
        :mycobank_search.l, mycobank_basic_search_url,
        html_options: { target: :_blank, rel: :noopener }
      ).tab
    end

    def eol_name_tab(name)
      external_name_tab("EOL", name, name.eol_url)
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

    def wikipedia_term_tab(name)
      external_name_tab("Wikipedia", name, wikipedia_term_search_url(name))
    end

    # -------- non-tab utility ------------------------------------

    def names_index_sorts(query: nil)
      rss_log = query&.params&.dig(:order_by) == :rss_log
      [
        ["name", :sort_by_name.t],
        ["created_at", :sort_by_created_at.t],
        [(rss_log ? "rss_log" : "updated_at"), :sort_by_updated_at.t],
        ["num_views", :sort_by_num_views.t]
      ]
    end
  end
end
