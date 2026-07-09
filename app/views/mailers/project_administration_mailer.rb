# frozen_string_literal: true

# Notify a project owner when a Site Admin self-promotes to Project
# Admin. No fields, no boxed message, no report_abuse — but does
# have an unconditional divider (unlike other no-box mailers), so
# this writes its own view_template.
class Views::Mailers::ProjectAdministrationMailer < Views::Mailers::Base
  prop :subject, ::String
  prop :receiver, ::User
  prop :site_admin, ::User
  prop :project, ::Project

  class Html < self
    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        render_body
      end
    end

    private

    def render_body
      emit_tp(intro)
      emit_tp(handy_links)
      render_links_section(links)
    end
  end

  class Text < self
    def view_template
      emit_tp(intro)
      divider
      emit_tp(handy_links)
      gap
      render_links_section(links)
      newline
    end
  end

  private

  def intro
    :email_project_administered_intro.l(
      site_admin: @site_admin.legal_name, email: @site_admin.email,
      project: @project.title
    )
  end

  def handy_links = :email_handy_links.l

  def links
    [[:email_links_show_object.t(type: :Project.l),
      "#{MO.http_domain}/projects/#{@project.id}"],
     [:email_links_show_user.t,
      "#{MO.http_domain}/users/#{@site_admin.id}"]]
  end
end
