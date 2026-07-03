# frozen_string_literal: true

# Sidebar info nav: send-a-comment (same webmaster path as
# `Tab::Sidebar::Info::ReportABug`, different label and DOM id).
class Tab::Sidebar::Info::SendAComment < Tab::Base
  def title
    :app_send_a_comment.t
  end

  def path
    new_admin_emails_webmaster_questions_path
  end
end
