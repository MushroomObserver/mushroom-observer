# frozen_string_literal: true

require_relative("deploy_time")

# Picks script/prerelease.rb's deploy time: --now, then --at, then the
# open changelog PR's tag, then (for --apply) one typed at a prompt.
#
# deploy.sh stamps tags with the server's UTC clock, so all of these are
# UTC -- a developer's local clock could otherwise mint a name that
# sorts before the newest deployed tag.
class PrereleaseDeployTime
  TAG_FORMAT = "deploy-%Y-%m-%d-%H-%M"
  TAG_TIME = /deploy-(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})/
  RESET_HINT = "Use --at <date-time> --apply to reset the time."

  attr_reader :time

  # The DeployTime::Result for text, or nil for no text. A bad value
  # yields the error message to the block.
  def self.parse(text)
    return nil unless text

    DeployTime.parse(text)
  rescue DeployTime::Error => e
    yield(e.message)
  end

  # at: the parsed --at Result; at_text: what was typed for it;
  # pending_pr: the open changelog PR's number and title, or nil.
  def initialize(now: false, at: nil, at_text: nil, pending_pr: nil,
                 apply: false)
    @now = now
    @at = at
    @at_text = at_text
    @pending_pr = pending_pr
    @apply = apply
    @time, @source = chosen
  end

  # Without a time, a dry run shows ??-?? in the tag.
  def tag
    return @time.strftime(TAG_FORMAT) if @time

    Time.now.utc.strftime("deploy-%Y-%m-%d-??-??")
  end

  def report
    return "Deploy time: not set; give --at TIME, or --apply asks for one." \
      unless @time

    line = "Deploy time: #{@time.strftime("%Y-%m-%d %H:%M")} UTC " \
           "(from #{@source})"
    line += " -- in the past" if @source != "--now" && @time < Time.now.utc
    @source.start_with?("PR #") ? "#{line}\n#{RESET_HINT}" : line
  end

  private

  def chosen
    return [Time.now.utc, "--now"] if @now
    return [@at.time, "--at #{@at_text.inspect}, #{@at.zone}"] if @at

    from_pr = pending_pr_time
    return [from_pr, "PR ##{@pending_pr["number"]}"] if from_pr

    @apply ? ask : [nil, nil]
  end

  def pending_pr_time
    parts = @pending_pr&.fetch("title")&.match(TAG_TIME)
    parts && Time.utc(*parts.captures.map(&:to_i))
  end

  def ask
    unless $stdin.tty?
      abort("No changelog PR to take the deploy time from; give --at " \
            "TIME or --now.")
    end
    loop do
      $stderr.print("Deploy time (#{DeployTime::EXAMPLES}): ")
      text = $stdin.gets.to_s.strip
      abort("No deploy time given.") if text.empty?
      result = self.class.parse(text) { |error| warn(error) }
      return [result.time, "#{text.inspect}, #{result.zone}"] if result
    end
  end
end
