# frozen_string_literal: true

# "Logout" link in the user-nav dropdown.
class Tab::UserNav::Logout < Tab::Base
  def title
    :app_logout.l
  end

  def path
    account_logout_path
  end

  # Logging out changes the session's theme/asset state, so Turbo
  # Drive's head-merging on the redirected page can corrupt
  # stylesheets. Opt this button out of Turbo entirely.
  def html_options
    { button: :post, data: { turbo: false } }
  end
end
