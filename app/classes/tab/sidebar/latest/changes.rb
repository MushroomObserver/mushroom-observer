# frozen_string_literal: true

# Sidebar latest nav: activity logs ("latest changes"). User-only.
class Tab::Sidebar::Latest::Changes < Tab::Base
  def title
    :app_latest_changes.t
  end

  def path
    activity_logs_path
  end
end
