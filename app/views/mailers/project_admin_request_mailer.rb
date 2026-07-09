# frozen_string_literal: true

# Ask project admins for admin privileges on project.
class Views::Mailers::ProjectAdminRequestMailer < Views::Mailers::Base
  prop :subject, ::String
  prop :sender, ::User
  prop :project, ::Project
  prop :message, ::String

  class Html < self
    include Views::Mailers::StandardMessageBody
  end

  class Text < self
    include Views::Mailers::StandardMessageBody
  end

  private

  def intro
    :email_admin_request_intro.l(user: @sender.legal_name,
                                 email: @sender.email,
                                 project: @project.title)
  end

  def handy_links = :email_handy_links.l

  def links
    [[:admin_request_change_member_status.t,
      "#{MO.http_domain}/projects/#{@project.id}/members/#{@sender.id}" \
      "/edit"],
     [:email_links_show_user.t, "#{MO.http_domain}/users/#{@sender.id}"],
     [:email_links_latest_changes.t, MO.http_domain]]
  end
end
