# frozen_string_literal: true

# User-nav dropdown tabs shown at the bottom of the menu: admin
# mode toggle + logout (logout omitted when no user).
class Tab::UserNav::LogOut < Tab::Collection
  def initialize(user:, in_admin_mode: false)
    super()
    @user = user
    @in_admin_mode = in_admin_mode
  end

  private

  def tabs
    [
      Tab::UserNav::AdminMode.new(in_admin_mode: @in_admin_mode),
      (Tab::UserNav::Logout.new if @user)
    ].compact
  end
end
