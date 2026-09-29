# frozen_string_literal: true

# What an external site newly identified as a name one of the
# receiver's projects watches (#5416). Grouped by project, each row
# naming the observation, the name applied and the date it was seen --
# which is what says whether a voucher is still a possibility.
class Views::Mailers::ProjectAlertMailer < Views::Mailers::Base
  prop :subject, ::String
  prop :receiver, ::User
  prop :alerts, ::Array

  class Html < self
    def view_template
      render(Views::Layouts::Mailer::Html.new(subject: @subject)) do
        render_body
      end
    end

    private

    def render_body
      emit_tp(intro)
      render_projects
      render_links_section(links)
    end
  end

  class Text < self
    def view_template
      emit_tp(intro)
      gap
      render_projects
      gap
      render_links_section(links)
    end
  end

  private

  def intro
    :email_project_alert_intro.l(count: @alerts.size)
  end

  def by_project
    @by_project ||= @alerts.group_by(&:project).
                    sort_by { |project, _| project.title.to_s }
  end

  def render_projects
    by_project.each do |project, alerts|
      emit_tp(:email_project_alert_project.l(project: project.title))
      render_alerts(alerts.sort_by(&:id))
      gap
    end
  end

  # A row per alert: list items under one list in HTML, plain lines in
  # text.
  def render_alerts(alerts)
    if html?
      ul { alerts.each { |alert| li { emit_alert_row(alert) } } }
    else
      alerts.each do |alert|
        emit_alert_row(alert)
        newline
      end
    end
  end

  def emit_alert_row(alert)
    plain(:email_project_alert_row.l(name: alert.name.to_s,
                                     date: observed_on(alert)))
    whitespace
    if html?
      link_to(alert.remote_url, alert.remote_url)
    else
      plain(alert.remote_url.to_s)
    end
  end

  def observed_on(alert)
    alert.observed_on ? alert.observed_on.web_date : :unknown.l
  end

  def links
    [[:email_links_your_projects.l, "#{MO.http_domain}/projects"],
     [:email_links_latest_changes.l, MO.http_domain]]
  end
end
