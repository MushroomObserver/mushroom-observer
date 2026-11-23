# frozen_string_literal: true

# What was newly identified as a name one of the receiver's projects
# watches, here or on an external site (#5416, #5721). One watched
# name and one kind per message (#5677); each row names the
# observation, the name applied and the date it was seen -- which is
# what says whether a voucher is still a possibility.
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
    ::ProjectAlert::NEW_OBSERVATION =>
      { one: :email_project_alert_find_intro_one,
        many: :email_project_alert_find_intro },
    ::ProjectAlert::OTHER_ACTIVITY =>
      { one: :email_project_alert_activity_intro_one,
        many: :email_project_alert_activity_intro }
  }.freeze

  # Keyed by whether the row has a date -- iNat does not always have
  # one, and "observed unknown" is worse than saying so -- and by
  # whether it says what happened, which a find's row leaves to its
  # message.
  ROW_TAGS = {
    [true, true] => :email_project_alert_row_activity,
    [true, false] => :email_project_alert_row,
    [false, true] => :email_project_alert_row_activity_undated,
    [false, false] => :email_project_alert_row_undated
  }.freeze

  private

  def intro
    count = by_observation.size
    alert = @alerts.first
    intro_tag(count).l(count: count, name: alert.target_name.to_s,
                       site: alert.source_name)
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
      @alerts.group_by(&:observation_key).values.
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
      link_to(alert.url, alert.url)
    else
      plain(alert.url.to_s)
    end
  end

  def row_text(alert, projects)
    args = { name: alert.name.to_s, projects: projects }
    args[:date] = alert.observed_on.web_date if alert.observed_on.present?
    what = alert.activity_phrase
    args[:what] = what if what.present?
    ROW_TAGS[[args.key?(:date), args.key?(:what)]].l(**args)
  end

  def project_names(alerts)
    alerts.map { |alert| alert.project.title }.uniq.sort.to_sentence
  end

  def links
    [[:email_links_your_projects.l, "#{MO.http_domain}/projects"],
     [:email_links_latest_changes.l, MO.http_domain]]
  end
end
