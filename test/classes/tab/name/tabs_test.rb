# frozen_string_literal: true

require("test_helper")

module Tab::Name
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @name = names(:agaricus_campestris)
      @user = users(:rolf)
    end

    def test_edit
      tab = Tab::Name::Edit.new(name: @name)

      assert_equal(:show_name_edit_name.l, tab.title)
      assert_equal(routes.edit_name_path(@name.id), tab.path)
      assert_equal(:edit, tab.html_options[:icon])
      assert_equal(@name, tab.model)
    end

    def test_new
      tab = Tab::Name::New.new

      assert_equal(:show_name_add_name.l, tab.title)
      assert_equal(routes.new_name_path, tab.path)
      assert_equal(:add, tab.html_options[:icon])
      assert_equal(Name, tab.model)
    end

    def test_edit_synonym
      tab = Tab::Name::EditSynonym.new(name: @name)

      assert_equal(:show_name_change_synonyms.l, tab.title)
      assert_equal(routes.edit_synonyms_of_name_path(@name.id), tab.path)
      assert_equal(:synonyms, tab.html_options[:icon])
    end

    def test_deprecate
      tab = Tab::Name::Deprecate.new(name: @name)

      assert_equal(:deprecate.ti, tab.title)
      assert_equal(routes.form_to_deprecate_synonym_of_name_path(@name.id),
                   tab.path)
    end

    def test_approve
      tab = Tab::Name::Approve.new(name: @name)

      assert_equal(:approve.ti, tab.title)
      assert_equal(routes.form_to_approve_synonym_of_name_path(@name.id),
                   tab.path)
    end

    def test_edit_lifeform
      tab = Tab::Name::EditLifeform.new(name: @name)

      assert_equal(:edit.ti, tab.title)
      assert_equal(routes.edit_lifeform_of_name_path(@name.id), tab.path)
    end

    def test_new_description
      tab = Tab::Name::NewDescription.new(name: @name)

      assert_equal(:show_name_create_description.l, tab.title)
      assert_equal(routes.new_name_description_path(@name.id), tab.path)
      assert_equal(:add, tab.html_options[:icon])
    end

    def test_edit_classification
      tab = Tab::Name::EditClassification.new(name: @name)

      assert_equal(:edit.ti, tab.title)
      assert_equal(routes.edit_classification_of_name_path(@name.id),
                   tab.path)
    end

    def test_occurrence_map_no_q_param
      tab = Tab::Name::OccurrenceMap.new(name: @name)

      assert_equal(:show_name_distribution_map.t, tab.title)
      assert_equal(routes.map_name_path(id: @name.id), tab.path)
      assert_equal("links#disable", tab.html_options[:data][:action])
    end

    def test_edit_tracker
      tab = Tab::Name::EditTracker.new(name: @name)

      assert_equal(:show_name_email_tracking.t, tab.title)
      assert_equal(routes.edit_tracker_of_name_path(@name.id), tab.path)
    end

    def test_new_tracker
      tab = Tab::Name::NewTracker.new(name: @name)

      assert_equal(:show_name_email_tracking.t, tab.title)
      assert_equal(routes.new_tracker_of_name_path(@name.id), tab.path)
    end

    def test_index
      tab = Tab::Name::Index.new

      assert_equal(:all_objects.t(type: :name), tab.title)
      assert_equal(routes.names_path, tab.path)
    end

    def test_all
      tab = Tab::Name::All.new

      assert_equal(:all_objects.t(type: :name), tab.title)
      assert_equal(routes.names_path, tab.path)
    end

    def test_mycoportal_external_link
      tab = Tab::Name::Mycoportal.new(name: @name)

      assert_equal("MyCoPortal", tab.title)
      assert_includes(tab.path, "mycoportal.org")
      assert(tab.html_options[:external])
      assert_equal(@name, tab.model)
    end

    def test_mycobank_search_external_link
      tab = Tab::Name::MycobankSearch.new(name: @name)

      assert_equal(:mycobank_search.l, tab.title)
      assert_includes(tab.path, "mycobank.org")
    end

    def test_user_google_images_external_link
      tab = Tab::Name::UserGoogleImages.new(name: @name, user: @user)

      assert_equal(:google_images.t, tab.title)
      assert_includes(tab.path, "images.google.com")
    end

    def test_eol_external_link
      eol_url = "https://eol.org/pages/67890"
      Triple.create!(subject: @name.show_url,
                     predicate: @name.eol_predicate,
                     object: eol_url)
      tab = Tab::Name::Eol.new(name: @name)

      assert_equal("EOL", tab.title, "EOL tab title")
      assert_equal(eol_url, tab.path, "EOL tab path delegates to eol_url")
      assert(tab.html_options[:external], "EOL tab opens in new tab")
    end

    def test_gbif_external_link
      tab = Tab::Name::Gbif.new(name: @name)

      assert_equal("GBIF", tab.title)
      assert_includes(tab.path, "gbif.org")
      assert_includes(tab.path, @name.sensu_stricto)
    end

    def test_google_search_external_link_non_group_rank
      tab = Tab::Name::GoogleSearch.new(name: @name)

      assert_equal(:google_name_search.l, tab.title)
      assert_includes(tab.path, "google.com/search")
      assert_not_includes(tab.path, "Clade")
    end

    def test_google_search_external_link_group_rank
      group = names(:boletus_edulis_group)
      tab = Tab::Name::GoogleSearch.new(name: group)

      assert_includes(tab.path, "Clade")
    end

    def test_inat_external_link
      tab = Tab::Name::Inat.new(name: @name)

      assert_equal("iNaturalist", tab.title)
      assert_includes(tab.path, "inaturalist.org")
    end

    def test_ascomycete_org_external_link
      tab = Tab::Name::AscomyceteOrg.new(name: @name)

      assert_equal("Ascomycete.org", tab.title)
      assert_includes(tab.path, "ascomycete.org")
    end

    def test_mushroom_expert_external_link
      tab = Tab::Name::MushroomExpert.new(name: @name)

      assert_equal("MushroomExpert", tab.title)
      assert_includes(tab.path, "mushroomexpert.com")
    end

    def test_ncbi_nucleotide_external_link
      tab = Tab::Name::NcbiNucleotide.new(name: @name)

      assert_equal("NCBI Nucleotide", tab.title)
      assert_includes(tab.path, "ncbi.nlm.nih.gov")
    end

    def test_wikipedia_external_link
      tab = Tab::Name::Wikipedia.new(name: @name)

      assert_equal("Wikipedia", tab.title)
      assert_includes(tab.path, "wikipedia.org")
    end

    def test_index_fungorum_record_external_link
      name = names(:coprinus_comatus)
      tab = Tab::Name::IndexFungorumRecord.new(name: name)

      assert_equal("[##{name.icn_id}]", tab.title)
      assert_equal("index_fungorum_record", tab.alt_title)
      assert_includes(tab.path, "indexfungorum.org")
      assert_includes(tab.path, name.icn_id.to_s)
    end

    def test_index_fungorum_name_search_external_link
      tab = Tab::Name::IndexFungorumNameSearch.new(name: @name)

      assert_equal(:index_fungorum_web_search.l, tab.title)
      assert_includes(tab.path, "duckduckgo.com")
      assert_includes(tab.path, "indexfungorum.org")
    end

    def test_index_fungorum_search_page_external_link
      tab = Tab::Name::IndexFungorumSearchPage.new

      assert_equal(:index_fungorum_search.l, tab.title)
      assert_includes(tab.path, "indexfungorum.org/Names/Names.asp")
      # No name → no model → plain title-derived selector class
      # (not the model-aware flavour).
      assert_nil(tab.model)
    end

    def test_mycobank_record_external_link
      name = names(:coprinus_comatus)
      tab = Tab::Name::MycobankRecord.new(name: name)

      assert_equal("[##{name.icn_id}]", tab.title)
      assert_equal(:mycobank.t, tab.alt_title)
      assert_includes(tab.path, "mycobank.org/MB/#{name.icn_id}")
    end

    def test_mycobank_basic_search_external_link
      tab = Tab::Name::MycobankBasicSearch.new

      assert_equal(:mycobank_search.l, tab.title)
      assert_includes(tab.path, "mycobank.org")
      assert_nil(tab.model)
    end

    def test_fungorum_gsd_synonymy_external_link
      name = names(:coprinus_comatus)
      tab = Tab::Name::FungorumGsdSynonymy.new(name: name)

      assert_equal(:gsd_species_synonymy.l, tab.title)
      assert_includes(tab.path, "speciesfungorum.org")
      assert_includes(tab.path, "GSDspecies.asp")
      assert_includes(tab.path, name.icn_id.to_s)
    end

    def test_fungorum_sf_synonymy_external_link
      name = names(:tubaria)
      tab = Tab::Name::FungorumSfSynonymy.new(name: name)

      assert_equal(:sf_species_synonymy.l, tab.title)
      assert_includes(tab.path, "speciesfungorum.org")
      assert_includes(tab.path, "SynSpecies.asp")
      assert_includes(tab.path, name.icn_id.to_s)
    end
  end
end
