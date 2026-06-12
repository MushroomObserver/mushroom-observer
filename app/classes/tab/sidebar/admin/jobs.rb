# frozen_string_literal: true

# Sidebar admin nav: jobs queue page.
class Tab::Sidebar::Admin::Jobs < Tab::Base
  def title
    :app_jobs.t
  end

  def path
    "/jobs"
  end

  def html_options
    { id: "nav_admin_jobs_link" }
  end
end
