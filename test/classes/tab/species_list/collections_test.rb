# frozen_string_literal: true

require("test_helper")

# Tests for Tab::SpeciesList::* Collections. Order matters — these
# are the right-side context-nav menu of the species_list pages
# (and small action-nav strips on the form pages).
module Tab::SpeciesList
  class CollectionsTest < UnitTestCase
    def setup
      @list = species_lists(:first_species_list)
    end

    # Show: 5 "logged_in" tabs always; 5 "user" tabs appended when
    # the viewing user can manage (owner / admin).
    def test_show_logged_in_only
      tabs = Tab::SpeciesList::Show.new(list: @list,
                                        can_manage: false).to_a

      assert_equal(
        [Tab::SpeciesList::Download,
         Tab::SpeciesList::SetSource,
         Tab::SpeciesList::Clone,
         Tab::SpeciesList::WriteIn,
         Tab::SpeciesList::AddRemoveFromAnotherList],
        tabs.map(&:class)
      )
    end

    def test_show_with_management
      tabs = Tab::SpeciesList::Show.new(list: @list,
                                        can_manage: true).to_a

      assert_equal(
        [Tab::SpeciesList::Download,
         Tab::SpeciesList::SetSource,
         Tab::SpeciesList::Clone,
         Tab::SpeciesList::WriteIn,
         Tab::SpeciesList::AddRemoveFromAnotherList,
         Tab::SpeciesList::AddNewObservations,
         Tab::SpeciesList::ManageProjects,
         Tab::SpeciesList::Edit,
         Tab::SpeciesList::Clear,
         Tab::SpeciesList::Destroy],
        tabs.map(&:class)
      )
    end

    def test_show_threads_q_param_to_children
      tabs = Tab::SpeciesList::Show.new(list: @list, can_manage: false,
                                        q_param: "Q").to_a
      # Download / SetSource / AddRemoveFromAnotherList take q_param;
      # check at least one ends up in the URL.
      paths = tabs.map(&:path)
      assert(paths.any? { |p| p.include?("q=Q") })
    end

    def test_form_new
      tabs = Tab::SpeciesList::FormNew.new.to_a

      assert_equal([Tab::SpeciesList::NameLister, Tab::SpeciesList::Index],
                   tabs.map(&:class))
    end

    def test_form_write_in
      tabs = Tab::SpeciesList::FormWriteIn.new(list: @list).to_a

      assert_equal([Tab::SpeciesList::CancelToShow], tabs.map(&:class))
    end

    def test_form_observations
      tabs = Tab::SpeciesList::FormObservations.new.to_a

      assert_equal([Tab::SpeciesList::ObservationsIndexReturn],
                   tabs.map(&:class))
    end

    def test_form_name_list
      tabs = Tab::SpeciesList::FormNameList.new.to_a

      assert_equal([Tab::SpeciesList::Create], tabs.map(&:class))
    end
  end
end
