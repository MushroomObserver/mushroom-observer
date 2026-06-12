# frozen_string_literal: true

# Action-nav for the user profile show page. Composition depends on
# whether the viewer is looking at their own profile (self-view) or
# someone else's (other-view), with admin extras appended in either
# case when `admin:` is true.
class Tab::User::ProfileActions < Tab::Collection
  def initialize(show_user:, user:, admin: false)
    super()
    @show_user = show_user
    @user = user
    @admin = admin
  end

  private

  def tabs
    base = if @show_user == @user
             self_tabs
           else
             other_tabs
           end
    return base unless @admin

    base + admin_tabs
  end

  def self_tabs
    [
      Tab::User::Observations.new(user: @show_user,
                                  text: :show_user_your_observations.t),
      Tab::User::CommentsFor.new(user: @show_user,
                                 text: :show_user_comments_for_you.t),
      Tab::Account::ShowNotifications.new,
      Tab::Account::EditProfile.new,
      Tab::Account::EditPreferences.new,
      Tab::User::LifeList.new(user: @show_user)
    ]
  end

  def other_tabs
    [
      Tab::User::Observations.new(user: @show_user),
      Tab::User::CommentsFor.new(user: @show_user)
    ]
  end

  def admin_tabs
    [Tab::User::AdminChangeBonuses.new(user: @show_user),
     Tab::User::AdminDestroy.new(user: @show_user)]
  end
end
