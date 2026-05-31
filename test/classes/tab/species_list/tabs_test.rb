# frozen_string_literal: true

require("test_helper")

# Covers all 17 Tab::SpeciesList::* singular Tab POROs. Each test
# asserts title + path (via route helpers, not literal URLs) and
# any non-default attribute (alt_title, html_options, model).
module Tab::SpeciesList
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @list = species_lists(:first_species_list)
      @user = users(:rolf)
    end

    def test_add_new_observations
      tab = Tab::SpeciesList::AddNewObservations.new(list: @list)

      assert_equal(:species_list_show_add_new_observations.t, tab.title)
      assert_equal(routes.new_write_in_species_list_path(@list.id), tab.path)
      assert_equal(@list, tab.model)
      assert_includes(tab.html_options.keys, :help)
    end

    def test_manage_projects
      tab = Tab::SpeciesList::ManageProjects.new(list: @list)

      assert_equal(:species_list_show_manage_projects.t, tab.title)
      assert_equal(routes.edit_projects_for_species_list_path(@list.id),
                   tab.path)
      assert_equal(@list, tab.model)
    end

    def test_edit
      tab = Tab::SpeciesList::Edit.new(list: @list)

      assert_equal(:species_list_show_edit.t, tab.title)
      assert_equal(routes.edit_species_list_path(@list.id), tab.path)
      assert_equal(@list, tab.model)
    end

    def test_download_with_and_without_q_param
      bare = Tab::SpeciesList::Download.new(list: @list).path
      with_q = Tab::SpeciesList::Download.new(list: @list, q_param: "X").path

      assert_equal(routes.new_download_species_list_path(@list.id), bare)
      assert_equal(
        routes.new_download_species_list_path(@list.id, q: "X"), with_q
      )
    end

    def test_set_source
      tab = Tab::SpeciesList::SetSource.new(list: @list)

      assert_equal(:species_list_show_set_source.t, tab.title)
      assert_equal(routes.species_list_path(@list.id, set_source: 1), tab.path)
      assert_includes(tab.html_options.keys, :help)
    end

    def test_cancel_to_show
      tab = Tab::SpeciesList::CancelToShow.new(list: @list)

      assert_equal(:cancel_and_show.t(TYPE: @list.type_tag), tab.title)
      assert_equal(routes.species_list_path(@list.id), tab.path)
    end

    def test_add_remove_from_another_list
      tab = Tab::SpeciesList::AddRemoveFromAnotherList.new(list: @list)

      assert_equal(:species_list_show_add_remove_from_another_list.t,
                   tab.title)
      assert_equal(
        routes.species_lists_edit_observations_path(
          species_list: { title: @list.id }
        ),
        tab.path
      )
      assert_equal(@list, tab.model)
    end

    def test_clone
      tab = Tab::SpeciesList::Clone.new(list: @list)

      assert_equal(:species_list_show_clone_list.t, tab.title)
      assert_equal(routes.new_species_list_path(clone: @list.id), tab.path)
    end

    def test_write_in
      tab = Tab::SpeciesList::WriteIn.new(list: @list)

      assert_equal(:species_list_show_write_in.t, tab.title)
      assert_equal(routes.new_write_in_species_list_path(id: @list.id),
                   tab.path)
    end

    def test_clear_button_options
      tab = Tab::SpeciesList::Clear.new(list: @list)

      assert_equal(:species_list_show_clear_list.t, tab.title)
      assert_equal(routes.clear_species_list_path(@list.id), tab.path)
      assert_equal(:put, tab.html_options[:button])
      assert_includes(tab.html_options[:class], "text-danger")
    end

    def test_destroy_button_target_is_list
      tab = Tab::SpeciesList::Destroy.new(list: @list)

      assert_equal(:species_list_show_destroy.t, tab.title)
      # `path` returns the list itself; `crud_button_or_link`
      # routes the destroy_button via `target:` (model resolves URL).
      assert_equal(@list, tab.path)
      assert_equal(:destroy, tab.html_options[:button])
    end

    def test_upload
      tab = Tab::SpeciesList::Upload.new(list: @list)

      assert_equal(:species_list_upload_title.t, tab.title)
      assert_equal(routes.new_upload_species_list_path(@list.id), tab.path)
    end

    def test_observations_index_return
      bare = Tab::SpeciesList::ObservationsIndexReturn.new.path
      with_q = Tab::SpeciesList::ObservationsIndexReturn.new(
        q_param: "Z"
      ).path

      assert_equal(routes.observations_path, bare)
      assert_equal(routes.observations_path(q: "Z"), with_q)
    end

    def test_name_lister
      tab = Tab::SpeciesList::NameLister.new

      assert_equal(:name_lister_title.t, tab.title)
      assert_equal(routes.species_lists_new_name_lister_path, tab.path)
    end

    def test_index
      bare = Tab::SpeciesList::Index.new
      with_q = Tab::SpeciesList::Index.new(q_param: "Y")

      assert_equal(:cancel_to_index.t(type: :SPECIES_LIST), bare.title)
      assert_equal(routes.species_lists_path, bare.path)
      assert_includes(with_q.path, "q=Y")
    end

    def test_create
      tab = Tab::SpeciesList::Create.new

      assert_equal(:create_object.t(type: :SPECIES_LIST), tab.title)
      assert_equal(routes.new_species_list_path, tab.path)
    end

    def test_for_user
      tab = Tab::SpeciesList::ForUser.new(user: @user)

      assert_equal(:app_your_lists.l, tab.title)
      assert_equal(routes.species_lists_path(by_user: @user.id), tab.path)
    end
  end
end
