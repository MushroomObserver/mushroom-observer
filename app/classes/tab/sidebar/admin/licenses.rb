# frozen_string_literal: true

# Sidebar admin nav: licenses index.
class Tab::Sidebar::Admin::Licenses < Tab::Base
  def title
    :LICENSES.t
  end

  def path
    licenses_path
  end

  def html_options
    { id: "nav_admin_licenses_link" }
  end
end
