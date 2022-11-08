# frozen_string_literal: true

# Ask project admins for admin privileges on project.
class AdminMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender, receiver, project, subject, message)
    setup_user(receiver)
    @title = subject
    @sender = sender
    @message = message || ""
    @project = project
    debug_log(:admin_request, sender, receiver, project: project)
    mo_mail(@title, to: receiver, reply_to: sender)
  end
end
