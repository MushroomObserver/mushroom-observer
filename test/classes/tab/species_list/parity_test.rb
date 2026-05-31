# frozen_string_literal: true

require("test_helper")

# Output-parity test: for each converted Tab PORO, assert that
# `pororo.to_a` produces the *same* `[title, url, html_options]`
# array the pre-conversion `Tabs::SpeciesListsHelper` method would
# have returned. The right-hand-side InternalLink constructions
# below are byte-for-byte copies of the original helper-method
# bodies — if a PORO's output drifts from the legacy shape (URL
# encoding, options ordering, model-passed instance vs. class), the
# matching assertion fails.
#
# This test exists for the helper-method → PORO migration window
# and can be deleted once the old helper methods are gone from
# every helper file (i.e. after PR 4 of the Tab POROs migration).
module Tab::SpeciesList
  class ParityTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @list = species_lists(:first_species_list)
      @user = users(:rolf)
    end

    def test_add_new_observations
      expected = ::InternalLink::Model.new(
        :species_list_show_add_new_observations.t,
        @list,
        routes.new_write_in_species_list_path(@list.id),
        html_options: { help: :species_list_show_add_new_observations_help.l }
      ).tab

      actual = Tab::SpeciesList::AddNewObservations.new(list: @list).to_a

      assert_equal(expected, actual)
    end

    def test_manage_projects
      expected = ::InternalLink::Model.new(
        :species_list_show_manage_projects.t,
        @list,
        routes.edit_projects_for_species_list_path(@list.id),
        html_options: { help: :species_list_show_manage_projects_help.l }
      ).tab

      actual = Tab::SpeciesList::ManageProjects.new(list: @list).to_a

      assert_equal(expected, actual)
    end

    def test_edit
      expected = ::InternalLink::Model.new(
        :species_list_show_edit.t, @list,
        routes.edit_species_list_path(@list.id)
      ).tab

      actual = Tab::SpeciesList::Edit.new(list: @list).to_a

      assert_equal(expected, actual)
    end

    def test_download_no_q_param
      expected = ::InternalLink::Model.new(
        :species_list_show_download.t, @list,
        routes.new_download_species_list_path(@list.id)
      ).tab

      actual = Tab::SpeciesList::Download.new(list: @list).to_a

      assert_equal(expected, actual)
    end

    def test_download_with_q_param
      expected = ::InternalLink::Model.new(
        :species_list_show_download.t, @list,
        routes.new_download_species_list_path(@list.id, q: "X")
      ).tab

      actual = Tab::SpeciesList::Download.new(list: @list, q_param: "X").to_a

      assert_equal(expected, actual)
    end

    def test_set_source_no_q_param
      expected = ::InternalLink::Model.new(
        :species_list_show_set_source.t, @list,
        routes.species_list_path(@list.id, set_source: 1),
        html_options: { help: :species_list_show_set_source_help.l }
      ).tab

      actual = Tab::SpeciesList::SetSource.new(list: @list).to_a

      assert_equal(expected, actual)
    end

    def test_cancel_to_show
      expected = ::InternalLink::Model.new(
        :cancel_and_show.t(TYPE: @list.type_tag), @list,
        routes.species_list_path(@list.id)
      ).tab

      actual = Tab::SpeciesList::CancelToShow.new(list: @list).to_a

      assert_equal(expected, actual)
    end

    def test_add_remove_from_another_list_no_q_param
      expected = ::InternalLink::Model.new(
        :species_list_show_add_remove_from_another_list.t, @list,
        routes.species_lists_edit_observations_path(
          species_list: { title: @list.id }
        )
      ).tab

      actual = Tab::SpeciesList::AddRemoveFromAnotherList.new(
        list: @list
      ).to_a

      assert_equal(expected, actual)
    end

    def test_clone
      expected = ::InternalLink::Model.new(
        :species_list_show_clone_list.t, @list,
        routes.new_species_list_path(clone: @list.id)
      ).tab

      actual = Tab::SpeciesList::Clone.new(list: @list).to_a

      assert_equal(expected, actual)
    end

    def test_write_in
      expected = ::InternalLink::Model.new(
        :species_list_show_write_in.t, @list,
        routes.new_write_in_species_list_path(id: @list.id)
      ).tab

      actual = Tab::SpeciesList::WriteIn.new(list: @list).to_a

      assert_equal(expected, actual)
    end

    def test_clear
      expected = ::InternalLink::Model.new(
        :species_list_show_clear_list.t, @list,
        routes.clear_species_list_path(@list.id),
        html_options: { button: :put, class: "text-danger",
                        data: { confirm: :are_you_sure.l } }
      ).tab

      actual = Tab::SpeciesList::Clear.new(list: @list).to_a

      assert_equal(expected, actual)
    end

    def test_destroy
      expected = ::InternalLink::Model.new(
        :species_list_show_destroy.t, @list, @list,
        html_options: { button: :destroy }
      ).tab

      actual = Tab::SpeciesList::Destroy.new(list: @list).to_a

      assert_equal(expected, actual)
    end

    def test_upload
      expected = ::InternalLink::Model.new(
        :species_list_upload_title.t, @list,
        routes.new_upload_species_list_path(@list.id)
      ).tab

      actual = Tab::SpeciesList::Upload.new(list: @list).to_a

      assert_equal(expected, actual)
    end

    def test_observations_index_return_no_q_param
      expected = ::InternalLink.new(
        :species_list_add_remove_cancel.t, routes.observations_path
      ).tab

      actual = Tab::SpeciesList::ObservationsIndexReturn.new.to_a

      assert_equal(expected, actual)
    end

    def test_name_lister
      expected = ::InternalLink.new(
        :name_lister_title.t, routes.species_lists_new_name_lister_path
      ).tab

      actual = Tab::SpeciesList::NameLister.new.to_a

      assert_equal(expected, actual)
    end

    def test_index_no_q_param
      expected = ::InternalLink.new(
        :cancel_to_index.t(type: :SPECIES_LIST),
        routes.species_lists_path
      ).tab

      actual = Tab::SpeciesList::Index.new.to_a

      assert_equal(expected, actual)
    end

    def test_create
      expected = ::InternalLink.new(
        :create_object.t(type: :SPECIES_LIST),
        routes.new_species_list_path
      ).tab

      actual = Tab::SpeciesList::Create.new.to_a

      assert_equal(expected, actual)
    end

    def test_for_user
      expected = ::InternalLink.new(
        :app_your_lists.l, routes.species_lists_path(by_user: @user.id)
      ).tab

      actual = Tab::SpeciesList::ForUser.new(user: @user).to_a

      assert_equal(expected, actual)
    end
  end
end
