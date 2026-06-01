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

      assert_equal(:DEPRECATE.l, tab.title)
      assert_equal(routes.form_to_deprecate_synonym_of_name_path(@name.id),
                   tab.path)
    end

    def test_approve
      tab = Tab::Name::Approve.new(name: @name)

      assert_equal(:APPROVE.l, tab.title)
      assert_equal(routes.form_to_approve_synonym_of_name_path(@name.id),
                   tab.path)
    end

    def test_edit_lifeform
      tab = Tab::Name::EditLifeform.new(name: @name)

      assert_equal(:EDIT.l, tab.title)
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

      assert_equal(:EDIT.l, tab.title)
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
      assert_equal(:_blank, tab.html_options[:target])
      assert_equal(:noopener, tab.html_options[:rel])
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
  end
end
