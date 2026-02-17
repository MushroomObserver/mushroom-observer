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
puts(DRY_RUN ? "DRY RUN - No emails will be sent" :
               "LIVE RUN - Sending emails")
puts("=" * 60)
puts

# Restored users: unverified, created in the deletion window
restored_start = Time.zone.parse("2026-01-16 05:13:00 UTC")
restored_end = Time.zone.parse("2026-01-17 05:13:00 UTC")

restored_users = User.where(verified: nil)
                     .where(created_at: restored_start..restored_end)
                     .order(:created_at)

puts("Found #{restored_users.count} restored user(s).")
puts

# Collect emails from restored users
restored_emails = restored_users.map(&:email).uniq

# For each restored email, find ALL unverified accounts with that email
# (includes both restored users and later accounts that weren't deleted)
multi_account_emails = {}
restored_emails.each do |email|
  all_accounts = User.where(verified: nil, email: email).order(:created_at)
  multi_account_emails[email] = all_accounts if all_accounts.size > 1
end

# Split restored users into Group A (unique email) and Group B (shared)
multi_emails_set = multi_account_emails.keys.to_set
group_a = restored_users.select { |u| !multi_emails_set.include?(u.email) }
group_b_emails = multi_account_emails

puts("Group A (restored, unique email): #{group_a.size}")
puts("Group B (shared email, one email per): #{group_b_emails.size}")
puts

domain = MO.http_domain

def send_email(user, subject, body)
  AccountRecoveryMailer.build(
    receiver: user,
    subject: subject,
    body: body
  ).deliver_now
end

# --- Group A: Restored users with unique email ---
puts("--- Group A: Restored Users (unique email) ---")
group_a.each do |user|
  verify_url = "#{domain}/account/verify/#{user.id}" \
               "?auth_code=#{user.auth_code}"

  body = <<~HTML
    <p>Dear #{ERB::Util.html_escape(user.login)},</p>

    <p>You recently received a verification email from Mushroom
    Observer. Unfortunately, a routine maintenance process
    temporarily removed your account before you had a chance to
    verify it, which caused that verification link to stop
    working. We apologize for the confusion.</p>

    <p>Your account has been restored. The verification link from
    the earlier email should now work again. If you no longer have
    that email, you can use the link below:</p>

    <p><a href="#{verify_url}">#{verify_url}</a></p>

    <p>If you have any questions, please contact us at
    webmaster@mushroomobserver.org.</p>

    <p>Thank you for your patience,<br/>
    The Mushroom Observer Team</p>
  HTML

  subject = "Mushroom Observer - Account Restored, Please Verify"

  puts("  #{user.email} (#{user.login}, ID: #{user.id})")
  unless DRY_RUN
    send_email(user, subject, body)
    puts("    SENT")
  end
end
puts

# --- Group B: Shared-email users ---
puts("--- Group B: Multi-Account Users ---")
group_b_emails.each do |email, users|
  # Use the most recently created account as the receiver
  # (for email_html preference), since that's likely the one
  # they intended to use
  receiver = users.last

  account_list = users.map do |u|
    verify_url = "#{domain}/account/verify/#{u.id}" \
                 "?auth_code=#{u.auth_code}"
    status = u.created_at.between?(restored_start, restored_end) ?
               " (restored)" : ""
    "<li>Login: <strong>#{ERB::Util.html_escape(u.login)}</strong>" \
      " (Account ##{u.id})#{status} &mdash; " \
      "<a href=\"#{verify_url}\">Verify this account</a></li>"
  end.join("\n")

  body = <<~HTML
    <p>Dear Mushroom Observer user,</p>

    <p>We recently experienced a technical issue with our email system
    that prevented verification emails from being delivered between
    January 14 and February 17, 2026. We apologize for the
    inconvenience.</p>

    <p>We noticed that you created multiple accounts with this email
    address. Thank you for your persistence! Here are the accounts
    associated with #{ERB::Util.html_escape(email)}:</p>

    <ul>
    #{account_list}
    </ul>

    <p>Please click the verification link for the account you would
    like to use. You only need to verify one account. Any unverified
    accounts will be automatically removed after 30 days.</p>

    <p>If you have any questions, please contact us at
    webmaster@mushroomobserver.org.</p>

    <p>Thank you for your patience,<br/>
    The Mushroom Observer Team</p>
  HTML

  subject = "Mushroom Observer - Your Accounts Are Ready to Verify"

  logins = users.map(&:login).join(", ")
  puts("  #{email} (logins: #{logins})")
  unless DRY_RUN
    send_email(receiver, subject, body)
    puts("    SENT")
  end
end
puts

puts("=" * 60)
if DRY_RUN
  puts("DRY RUN complete. Re-run with SEND_FOR_REAL=1 to send.")
else
  puts("All emails sent. Check log/email-debug.log for delivery log.")
end
puts("=" * 60)
