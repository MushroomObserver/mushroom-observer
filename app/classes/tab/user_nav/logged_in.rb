# frozen_string_literal: true

# User-nav dropdown tabs shown when logged in: your observations,
# comments for you, your projects, your species lists, interests,
# profile, preferences.
class Tab::UserNav::LoggedIn < Tab::Collection
  def initialize(user:)
    super()
    @user = user
  end

  private

  def tabs
    [
      Tab::User::Observations.new(
        user: @user, text: :app_your_observations.t
      ),
      Tab::User::CommentsFor.new(
        user: @user, text: :app_comments_for_you.t
      ),
      Tab::Project::ForUser.new(user: @user),
      Tab::SpeciesList::ForUser.new(user: @user),
      Tab::Account::ShowInterests.new,
      Tab::Account::EditProfile.new,
      Tab::Account::EditPreferences.new
    ]
  end
end
