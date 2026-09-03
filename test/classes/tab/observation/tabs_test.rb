# frozen_string_literal: true

require("test_helper")

module Tab::Observation
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @obs = observations(:minimal_unknown_obs)
      @name = names(:agaricus_campestris)
      @user = users(:rolf)
    end

    def test_send_question
      tab = Tab::Observation::SendQuestion.new(observation: @obs)

      assert_equal(:show_observation_send_question.l, tab.title)
      assert_equal(routes.new_question_for_observation_path(@obs.id),
                   tab.path)
      assert_equal(:email, tab.html_options[:icon])
    end

    def test_manage_lists
      tab = Tab::Observation::ManageLists.new(observation: @obs)

      assert_equal(:show_observation_manage_species_lists.l, tab.title)
      assert_equal(routes.edit_observation_species_lists_path(@obs.id),
                   tab.path)
    end

    def test_add_to_species_list
      tab = Tab::Observation::AddToSpeciesList.new(observation: @obs)

      assert_equal(:show_observation_add_to_species_list.l, tab.title)
      assert_equal(routes.edit_observation_species_lists_path(@obs.id),
                   tab.path)
      assert_equal(:add, tab.html_options[:icon])
    end

    def test_attach_field_slip
      tab = Tab::Observation::AttachFieldSlip.new(observation: @obs)

      assert_equal(:field_slip_attach_tooltip.l, tab.title)
      assert_equal(routes.edit_observation_field_slip_path(@obs.id), tab.path)
      assert_equal(:add, tab.html_options[:icon])
      assert_equal("attach_observation_to_field_slip", tab.alt_title)
    end

    def test_field_slip_scan
      tab = Tab::Observation::FieldSlipScan.new(observation: @obs)

      assert_equal(:field_slip_scan_tooltip.l, tab.title)
      assert_equal(routes.field_slip_scan_observation_path(@obs.id), tab.path)
      assert_equal(:qrcode, tab.html_options[:icon])
      assert_equal("scan_observation_field_slip", tab.alt_title)
    end

    def test_manage_projects
      tab = Tab::Observation::ManageProjects.new(observation: @obs)

      assert_equal(:show_observation_manage_projects.l, tab.title)
      assert_equal(routes.edit_observation_projects_path(@obs.id), tab.path)
      assert_equal(:manage_lists, tab.html_options[:icon])
    end

    def test_add_to_project
      tab = Tab::Observation::AddToProject.new(observation: @obs)

      assert_equal(:show_observation_add_to_project.l, tab.title)
      assert_equal(routes.edit_observation_projects_path(@obs.id), tab.path)
      assert_equal(:add, tab.html_options[:icon])
    end

    def test_matching_observations
      occurrence = occurrences(:occ_field_slip_one)
      tab = Tab::Observation::MatchingObservations.new(occurrence: occurrence)

      assert_equal(:show_observation_matching_observations.l, tab.title)
      assert_equal(routes.occurrence_path(occurrence.id), tab.path)
      assert_equal(:matrix, tab.html_options[:icon])
    end

    def test_add_matching_observations
      tab = Tab::Observation::AddMatchingObservations.new(obs: @obs)

      assert_equal(:show_observation_add_matching_observations.l, tab.title)
      assert_equal(routes.new_occurrence_path(observation_id: @obs.id),
                   tab.path)
      assert_equal(:matrix, tab.html_options[:icon])
    end

    def test_of_name
      tab = Tab::Observation::OfName.new(name: @name)

      assert_equal(:show_observation_more_like_this.l, tab.title)
      assert_equal(routes.observations_path(name: @name.id), tab.path)
    end

    def test_of_look_alikes
      tab = Tab::Observation::OfLookAlikes.new(name: @name)

      assert_equal(routes.observations_path(look_alikes: @name.id),
                   tab.path)
    end

    def test_of_related_taxa
      tab = Tab::Observation::OfRelatedTaxa.new(name: @name)

      assert_equal(routes.observations_path(related_taxa: @name.id),
                   tab.path)
    end

    def test_reuse_images
      tab = Tab::Observation::ReuseImages.new(observation: @obs)

      assert_equal(:show_observation_reuse_image.l, tab.title)
      assert_equal(routes.reuse_images_for_observation_path(@obs.id),
                   tab.path)
    end

    def test_define_location
      tab = Tab::Observation::DefineLocation.new(where: "Foo")

      assert_equal(:list_observations_location_define.l, tab.title)
      assert_equal(routes.new_location_path(where: "Foo"), tab.path)
    end

    def test_assign_undefined_location
      tab = Tab::Observation::AssignUndefinedLocation.new(where: "Bar")

      assert_equal(:list_observations_location_merge.l, tab.title)
      assert_includes(tab.path, "Bar")
    end

    def test_map
      tab = Tab::Observation::Map.new(q_param: "abc")

      assert_equal(:show_object.t(type: :map), tab.title)
      assert_equal(routes.map_observations_path(q: "abc"), tab.path)
      assert_equal("links#disable", tab.html_options[:data][:action])
    end

    def test_add_to_list
      tab = Tab::Observation::AddToList.new

      assert_equal(:list_observations_add_to_list.l, tab.title)
      assert_equal(routes.species_lists_edit_observations_path, tab.path)
    end

    def test_download_csv
      tab = Tab::Observation::DownloadCSV.new

      assert_equal(:list_observations_download_as_csv.l, tab.title)
      assert_equal(routes.new_observations_download_path, tab.path)
    end

    def test_index
      tab = Tab::Observation::Index.new
      with_filter = Tab::Observation::Index.new(
        index_filter: { by_user: 1 }
      )
      # Array-valued filters go through Query.merge_index_filters_into_url
      # (via with_index_filter), a different code path than the plain
      # Hash#merge the other migrated Tab classes use -- confirm it
      # round-trips correctly too.
      with_array_filter = Tab::Observation::Index.new(
        index_filter: { by_users: [1, 2] }
      )

      assert_equal(:cancel_to_index.t(type: :observation), tab.title)
      assert_equal(routes.observations_path, tab.path)
      assert_equal(routes.observations_path(by_user: 1), with_filter.path)
      assert_equal(
        routes.observations_path(by_users: [1, 2]), with_array_filter.path
      )
    end

    def test_edit
      tab = Tab::Observation::Edit.new(observation: @obs)

      assert_equal(:edit_object.t(type: Observation), tab.title)
      assert_equal(routes.edit_observation_path(@obs.id), tab.path)
    end

    def test_inat_import
      tab = Tab::Observation::InatImport.new

      assert_equal(:create_observation_inat_import_link.l, tab.title)
      assert_equal(routes.new_inat_import_path, tab.path)
    end
  end
end
