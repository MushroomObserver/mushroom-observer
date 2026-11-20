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
      (admin_mode_tab if show_admin_mode?),
      (Tab::UserNav::Logout.new if @user)
    ].compact
  end

  def admin_mode_tab
    Tab::UserNav::AdminMode.new(in_admin_mode: @in_admin_mode)
  end

  # `in_admin_mode?` is session state alone, so an admin who turns it
  # on and then switches to a non-admin user still needs the toggle to
  # get back out.
  def show_admin_mode?
    @user&.admin || @in_admin_mode
  end
end
