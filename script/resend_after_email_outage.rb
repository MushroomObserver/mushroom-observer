#!/usr/bin/env ruby
# frozen_string_literal: true

# One-off remediation: re-engage users whose verify-account emails
# were lost between April 13 and May 11, 2026 due to the SMTP
# credential outage.
#
# For each affected email address:
#   - Lists any existing verified accounts (with a password-reset
#     link, since they can already sign in).
#   - Lists any unverified accounts (each with a fresh verify link).
#   - Apologizes, explains what happened, and notes the 30-day cull
#     window for unverified accounts.
#
# Usage:
#   bin/rails runner script/resend_after_email_outage.rb [options]
#
# Options:
#   --csv PATH                  CSV of impacted emails.
#   --dry-run                   Print would-be messages; don't send.
#   --limit N                   Process at most N emails.
#   --email ADDR                Process this address only.
#   --rate-seconds N            Sleep this long between sends (def 2.0).
#   --abort-after-failures N    Stop after N consecutive errors (def 5).

require "csv"
require "optparse"

# Drives the apology / resend-verification campaign over a list of
# impacted email addresses.
class Resender
  DEFAULT_CSV = "tmp/email_failure_extracts/" \
                "VerifyAccountMailer_plausible_humans_refined.csv"

  SUBJECT = "[Mushroom Observer] Apology and your account verification"

  OPTION_DEFAULTS = {
    csv: DEFAULT_CSV, dry_run: false, limit: nil, email: nil,
    rate_seconds: 2.0, abort_after_failures: 5
  }.freeze

  OPTION_SPECS = [
    ["--csv PATH",              :csv,                  String],
    ["--dry-run",               :dry_run,              :boolean],
    ["--limit N",               :limit,                Integer],
    ["--email ADDR",            :email,                :downcase],
    ["--rate-seconds N",        :rate_seconds,         Float],
    ["--abort-after-failures N", :abort_after_failures, Integer]
  ].freeze

  def self.parse_options(argv)
    opts = OPTION_DEFAULTS.dup
    parser = OptionParser.new do |o|
      OPTION_SPECS.each { |spec| add_option(o, opts, *spec) }
    end
    parser.parse!(argv)
    opts
  end

  def self.add_option(parser, opts, flag, key, type)
    case type
    when :boolean
      parser.on(flag) { opts[key] = true }
    when :downcase
      parser.on(flag) { |v| opts[key] = v.downcase }
    else
      parser.on(flag, type) { |v| opts[key] = v }
    end
  end

  def initialize(opts)
    @opts = opts
    @stats = { sent: 0, skipped: 0, errored: 0, consecutive_failures: 0 }
  end

  def run
    targets = load_target_emails
    puts("Targets: #{targets.size} email#{"s" unless targets.one?}")
    puts("")

    targets.each_with_index do |email, i|
      handle_email(email)
      break if aborted?

      sleep(@opts[:rate_seconds]) if live? && i + 1 < targets.size
    end

    print_summary unless @opts[:dry_run]
  end

  private

  def live?
    !@opts[:dry_run]
  end

  def aborted?
    @stats[:consecutive_failures] >= @opts[:abort_after_failures]
  end

  def load_target_emails
    return [@opts[:email]] if @opts[:email]

    seen = []
    CSV.foreach(@opts[:csv], headers: true) do |row|
      email = row["email"].to_s.strip.downcase
      next if email.empty? || row["no_emails"] == "true"
      next if seen.include?(email)

      seen << email
    end
    @opts[:limit] ? seen.first(@opts[:limit]) : seen
  end

  def handle_email(email)
    users = User.where("LOWER(email) = ?", email).order(:created_at).to_a
    if users.empty?
      @stats[:skipped] += 1
      warn("SKIP  no user with email #{email}")
      return
    end

    unverified, verified = users.partition { |u| u.verified.nil? }
    body = render_body(verified, unverified)
    deliver_or_dry_run(email, body, verified, unverified)
  end

  def deliver_or_dry_run(email, body, verified, unverified)
    if @opts[:dry_run]
      print_dry_run(email, body)
      return
    end
    send_and_track(email, body, verified, unverified)
  end

  def send_and_track(email, body, verified, unverified)
    deliver_email(email, body)
    record_success(email, verified, unverified)
  rescue StandardError => e
    record_failure(email, e)
  end

  def record_success(email, verified, unverified)
    @stats[:sent] += 1
    @stats[:consecutive_failures] = 0
    puts("SENT  #{email}  (verified=#{verified.size} " \
         "unverified=#{unverified.size})")
  end

  def record_failure(email, exception)
    @stats[:errored] += 1
    @stats[:consecutive_failures] += 1
    warn("ERROR #{email}: #{exception.class}: " \
         "#{exception.message.lines.first&.strip}")
    return unless aborted?

    warn("ABORT #{@stats[:consecutive_failures]} consecutive failures; " \
         "stopping.")
  end

  def deliver_email(email, body)
    mail = Mail.new
    mail.from    = MO.accounts_email_address
    mail.to      = email
    mail.subject = SUBJECT
    mail.body    = body
    mail.delivery_method.settings =
      Rails.application.credentials.gmail_smtp_settings_webmaster
    mail.deliver!
  end

  def print_dry_run(email, body)
    puts("=" * 78)
    puts("To:      #{email}")
    puts("Subject: #{SUBJECT}")
    puts("-" * 78)
    puts(body)
    puts("")
  end

  def print_summary
    puts("")
    puts("sent=#{@stats[:sent]} skipped=#{@stats[:skipped]} " \
         "errored=#{@stats[:errored]} " \
         "consecutive_failures=#{@stats[:consecutive_failures]}")
  end

  def render_body(verified, unverified)
    parts = render_greeting
    parts << render_verified_section(verified) if verified.any?
    parts.concat(render_unverified_section(unverified))
    parts << render_explanation
    parts.concat(render_closing)
    "#{parts.compact.join("\n\n")}\n"
  end

  def render_greeting
    [
      "Dear Mushroom Observer user,",
      "We owe you an apology. Automated email from Mushroom Observer " \
      "stopped reaching its recipients between April 13 and May 11, " \
      "2026, which means the account-verification message you (or " \
      "someone using this address) were expecting from us never " \
      "arrived. We are very sorry for the disruption this caused."
    ]
  end

  def render_explanation
    "What happened, in short: in connection with a routine credential " \
    "rotation (see #{MO.http_domain}/articles/52), email credentials " \
    "from before January 14, 2026 were unintentionally reapplied to " \
    "the production system in April. Our mail provider rejected " \
    "almost everything we tried to send during that window. " \
    "Unfortunately we did not notice the failure for nearly a month. " \
    "We are putting in place better monitoring of the account-creation " \
    "pipeline so that the next time this happens we catch it within " \
    "hours instead of weeks."
  end

  def render_verified_section(verified)
    return nil if verified.empty?

    count = verified.size
    noun = count == 1 ? "a verified account" : "#{count} verified accounts"
    lines = ["We already have #{noun} on file for this address:"]
    verified.each { |u| lines << "  - #{u.login}#{name_suffix(u)}" }
    lines << ""
    lines << "If you have forgotten the password for any of these, you " \
            "can request a new one here:"
    lines << "  #{MO.http_domain}/account/login/email_new_password"
    lines.join("\n")
  end

  def name_suffix(user)
    user.name.present? ? " (#{user.name})" : ""
  end

  def render_unverified_section(unverified)
    return [] if unverified.empty?

    [
      render_unverified_list(unverified),
      "Important: unverified accounts are normally deleted 30 days after " \
      "creation. We have suspended that policy until June 1, 2026 to " \
      "give everyone affected by this outage a reasonable window to " \
      "verify. If you want to keep any of the accounts above, please " \
      "click its verification link before then."
    ]
  end

  def render_unverified_list(unverified)
    verb = unverified.size == 1 ? "was" : "were"
    noun = unverified.size == 1 ? "account" : "accounts"
    lines = ["The following #{noun} #{verb} created with this address " \
             "but never verified, because our verification email did " \
             "not reach you:"]
    unverified.each { |u| lines.concat(unverified_block(u)) }
    lines.join("\n")
  end

  def unverified_block(user)
    url = "#{MO.http_domain}/account/verify/#{user.id}" \
          "?auth_code=#{user.auth_code}"
    ["",
     "  Login:   #{user.login}",
     "  Created: #{user.created_at.strftime("%Y-%m-%d")}",
     "  Verify:  #{url}"]
  end

  def render_closing
    [
      "Thank you for your patience, and again, we apologize.",
      "-- The Mushroom Observer team\n   #{MO.http_domain}"
    ]
  end
end

Resender.new(Resender.parse_options(ARGV)).run
