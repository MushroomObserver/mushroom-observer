# frozen_string_literal: true

require("test_helper")

module Tab::User
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @user = users(:rolf)
      @other = users(:mary)
    end

    def test_observations
      tab = Tab::User::Observations.new(user: @user)

      assert_equal(
        :show_user_observations_by.t(name: @user.text_name), tab.title
      )
      assert_equal(routes.observations_path(by_user: @user.id), tab.path)
      assert_equal(@user, tab.model)
    end

    def test_observations_with_text_override
      tab = Tab::User::Observations.new(user: @user, text: "Your observations")

      assert_equal("Your observations", tab.title)
    end

    def test_profile
      tab = Tab::User::Profile.new(user: @user)

      assert_equal(:show_object.t(type: :profile), tab.title)
      assert_equal(routes.user_path(@user.id), tab.path)
    end

    def test_summary
      tab = Tab::User::Summary.new(user: @user)

      assert_equal(:app_your_summary.l, tab.title)
      assert_equal(routes.user_path(@user.id), tab.path)
    end

    def test_comments_for
      tab = Tab::User::CommentsFor.new(user: @user)

      assert_equal(
        :show_user_comments_for.t(name: @user.text_name), tab.title
      )
      assert_equal(routes.comments_path(for_user: @user.id), tab.path)
    end

    def test_comments_for_with_text_override
      tab = Tab::User::CommentsFor.new(user: @user, text: "Comments for you")

      assert_equal("Comments for you", tab.title)
    end

    def test_life_list
      tab = Tab::User::LifeList.new(user: @user)

      assert_equal(:app_life_list.t, tab.title)
      assert_equal(routes.checklist_path(id: @user.id), tab.path)
    end

    def test_email_question
      tab = Tab::User::EmailQuestion.new(user: @user)

      assert_equal(
        :show_user_email_to.t(name: @user.unique_text_name), tab.title
      )
      assert_equal(routes.new_question_for_user_path(@user.id), tab.path)
      assert_equal(:email, tab.html_options[:icon])
    end

    def test_admin_change_bonuses
      tab = Tab::User::AdminChangeBonuses.new(user: @user)

      assert_equal(:change_user_bonuses.t, tab.title)
      assert_equal(routes.edit_admin_user_path(@user.id), tab.path)
    end

    def test_admin_destroy
      tab = Tab::User::AdminDestroy.new(user: @user)

      assert_equal(:destroy_object.t(TYPE: User), tab.title)
      assert_equal(routes.admin_user_path(id: @user.id), tab.path)
      assert_equal(:destroy, tab.html_options[:button])
    end
  end

  class CollectionsTest < UnitTestCase
    def setup
      @user = users(:rolf)
      @other = users(:mary)
    end

    def test_show_actions
      tabs = Tab::User::ShowActions.new.to_a

      assert_equal([Tab::Contributor::Index], tabs.map(&:class))
    end

    # Self-view: viewer is looking at their own profile. Composition
    # includes Account links (notifications, profile edit, prefs) and
    # the life-list tab.
    def test_profile_actions_self_view
      tabs = Tab::User::ProfileActions.new(
        show_user: @user, user: @user
      ).to_a

      assert_equal(
        [Tab::User::Observations,
         Tab::User::CommentsFor,
         Tab::Account::ShowNotifications,
         Tab::Account::EditProfile,
         Tab::Account::EditPreferences,
         Tab::User::LifeList],
        tabs.map(&:class)
      )
    end

    # Other-view: just observations + comments for them.
    def test_profile_actions_other_view
      tabs = Tab::User::ProfileActions.new(
        show_user: @other, user: @user
      ).to_a

      assert_equal(
        [Tab::User::Observations, Tab::User::CommentsFor],
        tabs.map(&:class)
      )
    end

    # Admin mode appends admin tabs to either base composition.
    def test_profile_actions_admin_self_view
      tabs = Tab::User::ProfileActions.new(
        show_user: @user, user: @user, admin: true
      ).to_a

      classes = tabs.map(&:class)
      assert_includes(classes, Tab::User::AdminChangeBonuses)
      assert_includes(classes, Tab::User::AdminDestroy)
    end

    def test_profile_actions_admin_other_view
      tabs = Tab::User::ProfileActions.new(
        show_user: @other, user: @user, admin: true
      ).to_a

      assert_equal(
        [Tab::User::Observations,
         Tab::User::CommentsFor,
         Tab::User::AdminChangeBonuses,
         Tab::User::AdminDestroy],
        tabs.map(&:class)
      )
    end
  end
end
