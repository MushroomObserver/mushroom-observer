# frozen_string_literal: true

# Shared by the release scripts (prerelease.rb, update_article_changelog.rb,
# update_release_banner.rb): when a deploy is scheduled, where the MO
# Article changelog lives, and the first line of the site banner before
# and after a release. Only that first line announces the release; the
# rest of the banner is left alone.

require("date")
require("tzinfo")
require_relative("article_rows")

module ReleaseNotes
  # Bumped by hand at yearly rollover (create the next year's article,
  # update this) -- article creation is not automated.
  ARTICLE_ID = 55
  ARTICLE_URL = "https://mushroomobserver.org/articles/#{ARTICLE_ID}".freeze
  PENDING_FILE = "article_pending.textile"
  CHANGELOG_URL = "https://github.com/MushroomObserver/mushroom-observer/" \
                  "blob/%<branch>s/CHANGELOG.md"
  # Scheduled deploys stay at 8am Eastern through daylight saving changes,
  # so their UTC time moves between 12:00 and 13:00.
  DEPLOY_ZONE = "America/New_York"
  DEPLOY_HOUR = 8
  LOCAL_ZONES = { "eastern" => "America/New_York",
                  "pacific" => "America/Los_Angeles" }.freeze
  LINE_BREAK = %r{<br\s*/?>\s*\z}
  # A merge commit's subject, or a squash merge's "(#1234)" suffix.
  PR_SUBJECT = /\AMerge pull request #(\d+)|\(#(\d+)\)\z/

  module_function

  # Today's deploy time if it hasn't passed (the time itself counts as not
  # passed), otherwise tomorrow's. UTC.
  def next_deploy_time(now = Time.now.utc)
    today = TZInfo::Timezone.get(DEPLOY_ZONE).to_local(now).to_date
    scheduled = deploy_time_on(today)
    now <= scheduled ? scheduled : deploy_time_on(today + 1)
  end

  # The scheduled deploy time on a calendar date, in UTC.
  def deploy_time_on(date)
    TZInfo::Timezone.get(DEPLOY_ZONE).local_to_utc(
      Time.utc(date.year, date.month, date.day, DEPLOY_HOUR)
    )
  end

  # Posted by hand after `prerelease.rb --apply`, when production has no
  # part in the change yet.
  def pending_banner_line(deploy_time)
    "Next release #{when_text(deploy_time)}. See \"pre-release change " \
      "log\":#{changelog_url("changelog-pending")} for details"
  end

  # Set by deploy.sh once a pre-release deploy is up.
  def released_banner_line(release_time, user_facing:)
    "#{day(release_time)} release complete. #{details(user_facing)}"
  end

  # Set by deploy.sh after a forced deploy, which skips the pre-release.
  def urgent_banner_line(release_time, user_facing:)
    "Urgent release complete: #{when_text(release_time)}. " \
      "#{details(user_facing)}"
  end

  # message with its first line replaced by line, keeping the old line's
  # trailing <br/> and every later line as they were.
  def with_first_line(message, line)
    first, separator, rest = message.to_s.partition(/\r?\n/)
    "#{line}#{first[LINE_BREAK]}#{separator}#{rest}"
  end

  # PR numbers from `git log --format=%s` subjects.
  def pr_numbers(subjects)
    subjects.filter_map do |subject|
      match = subject.strip.match(PR_SUBJECT)
      (match[1] || match[2]).to_i if match
    end.uniq
  end

  # Whether any PR (gh pr list JSON shape: number, title, url, mergedAt,
  # body) has a usable `article: yes` changelog block -- the same test
  # that puts a row in the MO Article.
  def user_facing?(pulls)
    ArticleRows.new.rows_for(pulls).first.any?
  end

  def details(user_facing)
    if user_facing
      "See \"MO Improvements\":#{ARTICLE_URL} for details"
    else
      "No user-facing changes - \"details here\":#{changelog_url("main")}"
    end
  end

  def when_text(time)
    "#{day(time)} #{utc_clock(time)} UTC (#{local_clocks(time)})"
  end

  def changelog_url(branch)
    format(CHANGELOG_URL, branch: branch)
  end

  def day(time)
    time.getutc.strftime("%b %-d")
  end

  def utc_clock(time)
    utc = time.getutc
    return "noon" if utc.hour == 12 && utc.min.zero?

    utc.strftime("%H:%M")
  end

  def local_clocks(time)
    LOCAL_ZONES.map do |label, zone|
      local = TZInfo::Timezone.get(zone).to_local(time.getutc)
      "#{local.strftime(local.min.zero? ? "%-l%P" : "%-l:%M%P")} #{label}"
    end.join(", ")
  end
end
