# frozen_string_literal: true

# Notify a project owner when a Site Admin self-promotes to Project
# Admin via the Administer Project button (issue #4145).
class ProjectAdministrationMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(site_admin:, project:, receiver:)
    setup_user(receiver)
    @site_admin = site_admin
    @project = project
    @title = :email_subject_project_administered.l(project: project.title)
    debug_log(:project_administration, site_admin, receiver,
              project: project)
    mo_mail(@title, to: receiver, reply_to: site_admin)
  end
end
