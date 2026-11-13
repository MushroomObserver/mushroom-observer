# frozen_string_literal: true

# What an external site newly identified as a name one of the
# receiver's projects watches (#5416). One watched name and one kind
# per message (#5677); each row names the observation, the name
# applied and the date it was seen -- which is what says whether a
# voucher is still a possibility.
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

  INTRO_TAGS = {
    ::ProjectExternalSiteAlert::NEW_OBSERVATION =>
      { one: :email_project_alert_find_intro_one,
        many: :email_project_alert_find_intro },
    ::ProjectExternalSiteAlert::OTHER_ACTIVITY =>
      { one: :email_project_alert_activity_intro_one,
        many: :email_project_alert_activity_intro }
  }.freeze

  private

  def intro
    count = by_observation.size
    alert = @alerts.first
    intro_tag(count).l(count: count, name: alert.target_name.to_s,
                       site: alert.external_site&.name.to_s)
  end

  def intro_tag(count)
    INTRO_TAGS.dig(@alerts.first.kind, count == 1 ? :one : :many)
  end

  # Grouped by observation rather than by project: one observation can
  # match several of the receiver's projects, and they want to read
  # about it once, with the projects it matched named on the row.
  # Each observation's alerts, newest observation first, undated last.
  # The id itself is not wanted, so the groups come back as a plain
  # Array -- which is also what keeps `each` from looking like a Hash
  # iteration.
  def by_observation
    @by_observation ||=
      @alerts.group_by(&:remote_observation_id).values.
      sort_by { |alerts| recency(alerts) }
  end

  def recency(alerts)
    observed = alerts.filter_map(&:observed_on).max
    observed ? [0, -observed.jd] : [1, 0]
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
    plain(row_text(alert, project_names(alerts)))
    whitespace
    if html?
      link_to(alert.remote_url, alert.remote_url)
    else
      plain(alert.remote_url.to_s)
    end
  end

  # iNat does not always have a date for an observation, and "observed
  # unknown" is worse than saying so.
  def row_text(alert, projects)
    return undated_row_text(alert, projects) if alert.observed_on.blank?

    :email_project_alert_row.l(name: alert.name.to_s,
                               date: alert.observed_on.web_date,
                               projects: projects)
  end

  def undated_row_text(alert, projects)
    :email_project_alert_row_undated.l(name: alert.name.to_s,
                                       projects: projects)
  end

  def project_names(alerts)
    alerts.map { |alert| alert.project.title }.uniq.sort.to_sentence
  end

  def links
    [[:email_links_your_projects.l, "#{MO.http_domain}/projects"],
     [:email_links_latest_changes.l, MO.http_domain]]
  end
end
