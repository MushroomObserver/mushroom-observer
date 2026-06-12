# frozen_string_literal: true

# Sidebar "User" section — mobile-only, shown when a user is logged
# in. Composes user / account links from those domains' Tab POROs +
# the mailing-list external link.
class Tab::Sidebar::UserActions < Tab::Collection
  def initialize(user:)
    super()
    @user = user
  end

  private

  def tabs
    [Tab::User::CommentsFor.new(
      user: @user, text: :app_comments_for_you.t
    ),
     Tab::Account::ShowInterests.new,
     Tab::User::Summary.new(user: @user),
     Tab::Account::EditPreferences.new,
     Tab::Sidebar::User::JoinMailingList.new]
  end
end
