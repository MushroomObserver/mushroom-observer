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
      render_alerts
      render_links_section(links)
    end
  end

  class Text < self
    def view_template
      emit_tp(intro)
      gap
      render_alerts
      gap
      render_links_section(links)
    end
  end

  private

  def intro
    count = by_observation.size
    tag = if count == 1
            :email_project_alert_intro_one
          else
            :email_project_alert_intro
          end
    tag.l(count: count)
  end

  # Grouped by observation rather than by project: one observation can
  # match several of the receiver's projects, and they want to read
  # about it once, with the projects it matched named on the row.
  # Each observation's alerts, oldest observation first. The id itself
  # is not wanted, so the groups come back as a plain Array -- which is
  # also what keeps `each` from looking like a Hash iteration.
  def by_observation
    @by_observation ||=
      @alerts.group_by(&:remote_observation_id).values.
      sort_by { |alerts| alerts.filter_map(&:observed_on).min || Date.new }
  end

  def render_alerts
    if html?
      ul do
        by_observation.each do |alerts|
          li do
            emit_alert_row(alerts)
          end
        end
      end
    else
      by_observation.each do |alerts|
        emit_alert_row(alerts)
        newline
      end
    end
  end

  def emit_alert_row(alerts)
    alert = alerts.first
    plain(:email_project_alert_row.l(name: alert.name.to_s,
                                     date: observed_on(alert),
                                     projects: project_names(alerts)))
    whitespace
    if html?
      link_to(alert.remote_url, alert.remote_url)
    else
      plain(alert.remote_url.to_s)
    end
  end

  def project_names(alerts)
    alerts.map { |alert| alert.project.title }.uniq.sort.to_sentence
  end

  def observed_on(alert)
    alert.observed_on ? alert.observed_on.web_date : :unknown.l
  end

  def links
    [[:email_links_your_projects.l, "#{MO.http_domain}/projects"],
     [:email_links_latest_changes.l, MO.http_domain]]
  end
end
