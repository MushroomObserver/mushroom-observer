# frozen_string_literal: true

# Shared by the release scripts (prerelease.rb, update_article_changelog.rb,
# update_release_banner.rb): where the MO Article changelog lives, and the
# first line of the site banner before and after a release. Only that
# first line announces the release; the rest of the banner is left alone.

require("tzinfo")

module ReleaseNotes
  # Bumped by hand at yearly rollover (create the next year's article,
  # update this) -- article creation is not automated.
  ARTICLE_ID = 55
  ARTICLE_URL = "https://mushroomobserver.org/articles/#{ARTICLE_ID}".freeze
  PENDING_FILE = "article_pending.textile"
  CHANGELOG_URL = "https://github.com/MushroomObserver/mushroom-observer/" \
                  "blob/%<branch>s/CHANGELOG.md"
  LOCAL_ZONES = { "eastern" => "America/New_York",
                  "pacific" => "America/Los_Angeles" }.freeze
  LINE_BREAK = %r{<br\s*/?>\s*\z}

  module_function

  # Posted by hand after `prerelease.rb --apply`, when production has no
  # part in the change yet.
  def pending_banner_line(deploy_time)
    "Next release #{day(deploy_time)} #{utc_clock(deploy_time)} UTC " \
      "(#{local_clocks(deploy_time)}). See \"pre-release change log\":" \
      "#{changelog_url("changelog-pending")} for details"
  end

  # Set by deploy.sh once the release is up.
  def released_banner_line(release_time, user_facing:)
    if user_facing
      "#{day(release_time)} release complete. See \"MO Improvements\":" \
        "#{ARTICLE_URL} for details"
    else
      "#{day(release_time)} release complete. No user-facing changes - " \
        "\"details here\":#{changelog_url("main")}"
    end
  end

  # message with its first line replaced by line, keeping the old line's
  # trailing <br/> and every later line as they were.
  def with_first_line(message, line)
    first, separator, rest = message.to_s.partition(/\r?\n/)
    "#{line}#{first[LINE_BREAK]}#{separator}#{rest}"
  end

  def changelog_url(branch)
    format(CHANGELOG_URL, branch: branch)
  end

  def day(time)
    time.utc.strftime("%b %-d")
  end

  def utc_clock(time)
    utc = time.utc
    return "noon" if utc.hour == 12 && utc.min.zero?

    utc.strftime("%H:%M")
  end

  def local_clocks(time)
    LOCAL_ZONES.map do |label, zone|
      local = TZInfo::Timezone.get(zone).to_local(time.utc)
      "#{local.strftime(local.min.zero? ? "%-l%P" : "%-l:%M%P")} #{label}"
    end.join(", ")
  end
end
