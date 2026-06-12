# frozen_string_literal: true

# Sidebar info nav: bug report (webmaster question form).
class Tab::Sidebar::Info::ReportABug < Tab::Base
  def title
    :app_report_a_bug.t
  end

  def path
    new_admin_emails_webmaster_questions_path
  end

  def html_options
    { id: "nav_bug_report_link" }
  end
end
