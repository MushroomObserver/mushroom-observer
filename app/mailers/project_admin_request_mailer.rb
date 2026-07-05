# frozen_string_literal: true

# Ask project admins for admin privileges on project.
class ProjectAdminRequestMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(sender:, receiver:, project:, subject:, message:)
    setup_user(receiver)
    debug_log(:admin_request, sender, receiver, project:)
    mo_mail(subject, to: receiver, reply_to: sender,
                     view_namespace: Views::Mailers::ProjectAdminRequestMailer,
                     view_params: { subject:, sender:, project:,
                                    message: message || "" })
  end
end
