#!/usr/bin/env ruby
# frozen_string_literal: true

# Send custom recovery/verification emails to users whose accounts
# were deleted by refresh_caches on Feb 17, 2026 at 05:13 UTC and
# then restored from backup.
#
# Two groups:
#   Group A: Restored users with a unique email (no other unverified
#            account shares their email). They get a straightforward
#            "your account was restored, please verify" email.
#
#   Group B: Restored users whose email is shared with one or more
#            other unverified accounts (either other restored users,
#            or later accounts the person created that weren't deleted).
#            They get an email listing ALL accounts for that email
#            with individual verification links.
#
# Multi-account detection spans both restored users AND existing
# unverified users in production — because some people created a new
# account after their original was deleted.
#
# PREREQUISITES:
#   1. script/recover_deleted_users.rb has already been run
#   2. AccountRecoveryMailer exists with news_delivery
#
# USAGE:
#   # Dry run (default) - shows what emails would be sent
#   bin/rails runner script/send_recovery_emails.rb
#
#   # Actually send emails
#   SEND_FOR_REAL=1 bin/rails runner script/send_recovery_emails.rb

DRY_RUN = ENV["SEND_FOR_REAL"] != "1"

puts("=" * 60)
puts(DRY_RUN ? "DRY RUN - No emails will be sent" : "LIVE RUN - Sending emails")
puts("=" * 60)
puts

# Restored users: unverified, created during the outage and deleted
# by nightly refresh_caches runs from Feb 14-17.
# This must match the range used in recover_deleted_users.rb.
restored_start = Time.zone.parse(
  ENV.fetch("CREATED_AFTER", "2026-01-14 00:00:00 UTC")
)
restored_end = Time.zone.parse(
  ENV.fetch("CREATED_BEFORE", "2026-01-17 05:13:00 UTC")
)

restored_users = User.where(verified: nil).
                 where(created_at: restored_start...restored_end).
                 order(:created_at)

puts("Found #{restored_users.count} restored user(s).")
puts

# Collect emails from restored users
restored_emails = restored_users.map(&:email).uniq

# Find ALL unverified accounts for those emails in a single query
# (includes both restored users and later accounts that weren't deleted)
all_unverified = User.where(verified: nil, email: restored_emails).
                 order(:email, :created_at)
grouped = all_unverified.group_by(&:email)
multi_account_emails = grouped.select do |_email, accounts|
  accounts.size > 1
end

# Split restored users into Group A (unique email) and Group B (shared)
multi_emails_set = multi_account_emails.keys.to_set
group_a = restored_users.reject { |u| multi_emails_set.include?(u.email) }
group_b_emails = multi_account_emails

puts("Group A (restored, unique email): #{group_a.size}")
puts("Group B (shared email, one email per): #{group_b_emails.size}")
puts

domain = MO.http_domain

def send_email(user, subject, body)
  mail = AccountRecoveryMailer.build(
    receiver: user,
    subject: subject,
    body: body
  )
  unless mail
    puts("    SKIPPED (no email generated for #{user.email})")
    return
  end
  mail.deliver_now
end

def preview_email(subject, body, label)
  puts
  puts("  --- #{label} EMAIL PREVIEW ---")
  puts("  Subject: #{subject}")
  puts
  puts(html_to_plaintext(body))
  puts
  path = "/tmp/recovery_email_#{label}.html"
  File.write(path, body)
  puts("  HTML preview written to: #{path}")
  puts("  --- END PREVIEW ---")
  puts
end

def html_to_plaintext(html)
  html.gsub(/<[^>]+>/, "").gsub("&mdash;", "—").
    gsub("&nbsp;", " ").gsub(/\n{3,}/, "\n\n").
    lines.map { |l| "    #{l.strip}" }.join("\n")
end

def group_a_email(user, domain)
  verify_url = "#{domain}/account/verify/#{user.id}" \
               "?auth_code=#{user.auth_code}"
  subject = "Mushroom Observer - Account Restored, Please Verify"
  body = <<~HTML
    <p>Dear #{ERB::Util.html_escape(user.login)},</p>

    <p>We recently experienced a technical issue with our email system
    at Mushroom Observer that prevented verification emails from being
    delivered for several weeks. As a result, your account was
    removed by a routine maintenance process before you had a chance
    to verify it. We apologize for the inconvenience.</p>

    <p>Your account has been restored. Please use the link below to
    verify your account:</p>

    <p><a href="#{verify_url}">#{verify_url}</a></p>

    <p>If you have any questions, please contact us at
    webmaster@mushroomobserver.org.</p>

    <p>Thank you for your patience,<br/>
    The Mushroom Observer Team</p>
  HTML
  [subject, body]
end

def send_multi_account_email(email, users, opts)
  receiver = users.last
  account_list = build_account_list(users, opts)
  body = multi_account_body(email, account_list)
  subject = "Mushroom Observer - Account Verification Followup"

  logins = users.map(&:login).join(", ")
  puts("  #{email} (logins: #{logins})")
  if DRY_RUN
    preview_email(subject, body, "group_b") if opts[:show_preview]
    return
  end

  send_email(receiver, subject, body)
  puts("    SENT")
end

def build_account_list(users, opts)
  users.map do |u|
    verify_url = "#{opts[:domain]}/account/verify/#{u.id}" \
                 "?auth_code=#{u.auth_code}"
    restored = u.created_at.between?(
      opts[:restored_start], opts[:restored_end]
    )
    status = restored ? " (restored)" : ""
    "<li>Login: <strong>#{ERB::Util.html_escape(u.login)}</strong>" \
      "#{status}<br/> " \
      "<a href=\"#{verify_url}\">#{verify_url}</a></li>"
  end.join("\n")
end

def multi_account_body(email, account_list)
  <<~HTML
    <p>Dear Mushroom Observer user,</p>

    <p>We recently experienced a technical issue with our email system
    that may have prevented some verification emails from being
    delivered between January 14 and February 17, 2026. We apologize
    for the inconvenience.</p>

    <p>We noticed that you have multiple accounts associated with
    this email address. Thank you for your persistence! Here are the
    accounts currently associated with
    #{ERB::Util.html_escape(email)}:</p>

    <ul>
    #{account_list}
    </ul>

    <p><strong>Important: Please verify only one of these
    accounts.</strong> Choose the login name you prefer and click its
    verification link. Do not verify more than one &mdash; having
    multiple active accounts with the same email can cause confusion,
    such as observations and other data being split across accounts
    in ways that are difficult to fix later. Any accounts you leave
    unverified will be automatically removed after 30 days.</p>

    <p>If you have already verified more than one of these accounts,
    please contact us at webmaster@mushroomobserver.org and let us
    know which account you would like to keep. We can help merge or
    remove the extra account(s).</p>

    <p>If you have any other questions, please contact us at
    webmaster@mushroomobserver.org.</p>

    <p>Thank you for your patience,<br/>
    The Mushroom Observer Team</p>
  HTML
end

# --- Group A: Restored users with unique email ---
puts("--- Group A: Restored Users (unique email) ---")
group_a_preview_shown = false
group_a.each do |user|
  subject, body = group_a_email(user, domain)
  puts("  #{user.email} (#{user.login}, ID: #{user.id})")
  if DRY_RUN
    unless group_a_preview_shown
      preview_email(subject, body, "group_a")
      group_a_preview_shown = true
    end
  else
    send_email(user, subject, body)
    puts("    SENT")
  end
end
puts

# --- Group B: Shared-email users ---
puts("--- Group B: Multi-Account Users ---")
group_b_preview_shown = false
group_b_emails.each do |email, users|
  opts = { domain: domain, restored_start: restored_start,
           restored_end: restored_end,
           show_preview: !group_b_preview_shown }
  send_multi_account_email(email, users, opts)
  group_b_preview_shown = true
end
puts

puts("=" * 60)
if DRY_RUN
  puts("DRY RUN complete. Re-run with SEND_FOR_REAL=1 to send.")
else
  puts("All emails sent. Check log/email-debug.log for delivery log.")
end
puts("=" * 60)
