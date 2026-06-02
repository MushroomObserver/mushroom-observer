# frozen_string_literal: true

require("test_helper")

module Tab::Checklist
  class CollectionsTest < UnitTestCase
    def setup
      @user = users(:rolf)
      @list = species_lists(:first_species_list)
    end

    def test_show_actions_user_scope
      tabs = Tab::Checklist::ShowActions.new(user: @user).to_a

      assert_equal(
        [Tab::User::Profile,
         Tab::User::Observations,
         Tab::User::EmailQuestion],
        tabs.map(&:class)
      )
    end

    # List scope without permission: just show the list.
    def test_show_actions_list_scope_no_permission
      tabs = Tab::Checklist::ShowActions.new(list: @list).to_a

      assert_equal([Tab::Object::Show], tabs.map(&:class))
    end

    # List scope with edit permission: show + edit.
    def test_show_actions_list_scope_with_permission
      tabs = Tab::Checklist::ShowActions.new(
        list: @list, permission: true
      ).to_a

      assert_equal(
        [Tab::Object::Show, Tab::SpeciesList::Edit], tabs.map(&:class)
      )
    end

    def test_show_actions_site_scope
      tabs = Tab::Checklist::ShowActions.new.to_a

      assert_equal(
        [Tab::Contributor::Index, Tab::Info::SiteStats], tabs.map(&:class)
      )
    end
  end
end
