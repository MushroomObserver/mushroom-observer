#!/usr/bin/env ruby
# frozen_string_literal: true

# Recovery script for users deleted by refresh_caches between
# Feb 14-17, 2026 at 05:13 UTC each day.
#
# These users were unverified, created during the email outage
# (starting ~Jan 14), and never received verification emails.
# cull_unverified_users deleted them in nightly runs once they
# were 1 month old.
#
# The cull_unverified_users method deleted:
#   1. UserGroup named "user {id}" for each user
#   2. All UserGroupUser records for those user IDs
#   3. The User records themselves
#
# This script restores users from a database backup dump, re-creates
# their UserGroup and UserGroupUser associations, and generates a
# report of affected users.
#
# PREREQUISITES:
#   1. Load the backup into a separate database, e.g.:
#        mysql -u root -p -e "CREATE DATABASE mo_backup"
#        mysql -u root -p mo_backup < /path/to/backup.sql
#
#   2. Set BACKUP_DB env var to the name of the backup database.
#
# USAGE:
#   # Dry run (default) - shows what would be restored
#   BACKUP_DB=mo_backup bin/rails runner script/recover_deleted_users.rb
#
#   # Actually restore users
#   BACKUP_DB=mo_backup RECOVER_FOR_REAL=1 \
#     bin/rails runner script/recover_deleted_users.rb
#
#   # Custom date range (if using a backup that only covers a subset)
#   BACKUP_DB=mo_backup \
#     CREATED_AFTER="2026-01-16 05:13:00" \
#     CREATED_BEFORE="2026-01-17 05:13:00" \
#     bin/rails runner script/recover_deleted_users.rb

BACKUP_DB = ENV.fetch("BACKUP_DB", "mo_backup")
DRY_RUN = ENV["RECOVER_FOR_REAL"] != "1"
CONN = ActiveRecord::Base.connection

# Time window for affected users. cull_unverified_users runs daily at
# 05:13 UTC and deletes users where created_at <= 1.month.ago.
# The outage started ~Jan 14, so users created from Jan 14 onward
# never received verification emails and were deleted in nightly runs
# from Feb 14-17. Adjust CREATED_AFTER based on the backup available.
CREATED_AFTER = ENV.fetch("CREATED_AFTER", "2026-01-14 00:00:00")
CREATED_BEFORE = ENV.fetch("CREATED_BEFORE", "2026-01-17 05:13:00")

def print_header
  puts("=" * 60)
  if DRY_RUN
    puts("DRY RUN - No changes will be made")
  else
    puts("LIVE RUN - Restoring users")
  end
  puts("=" * 60)
  puts
end

def fetch_backup_users
  puts("Querying backup database '#{BACKUP_DB}' for deleted users...")
  rows = query_backup_users

  if rows.empty?
    puts("No users found in backup matching criteria. Exiting.")
    exit(0)
  end

  puts("Found #{rows.count} user(s) to restore:")
  puts
  rows.each do |u|
    puts("  ID: #{u["id"]}, Login: #{u["login"]}, " \
         "Email: #{u["email"]}, Created: #{u["created_at"]}")
  end
  puts
  rows
end

def query_backup_users
  quoted_db = CONN.quote_table_name(BACKUP_DB)
  quoted_after = CONN.quote(CREATED_AFTER)
  quoted_before = CONN.quote(CREATED_BEFORE)
  CONN.select_all(
    "SELECT * FROM #{quoted_db}.users " \
    "WHERE verified IS NULL " \
    "AND created_at >= #{quoted_after} " \
    "AND created_at < #{quoted_before} " \
    "ORDER BY id"
  )
end

def remove_already_existing(backup_users)
  existing_ids = User.where(
    id: backup_users.pluck("id")
  ).pluck(:id)

  if existing_ids.any?
    puts("WARNING: Users #{existing_ids.join(", ")} already exist " \
         "in production. Skipping those.")
    backup_users = backup_users.reject do |u|
      existing_ids.include?(u["id"])
    end
  end

  if backup_users.empty?
    puts("All users already exist. Nothing to restore.")
    exit(0)
  end

  backup_users
end

def find_multi_account_emails(backup_users)
  emails = backup_users.pluck("email")
  multi = emails.tally.select { |_email, count| count > 1 }.keys
  print_multi_accounts(backup_users, multi) if multi.any?
  multi
end

def print_multi_accounts(backup_users, multi)
  puts("Users with multiple accounts (same email):")
  multi.each do |email|
    logins = backup_users.select { |u| u["email"] == email }.
             map { |u| u["login"] }
    puts("  #{email}: #{logins.join(", ")}")
  end
  puts
end

def restore_user(attrs, all_users_group)
  insert_user_record(attrs)
  create_user_groups(attrs, all_users_group)
end

def insert_user_record(attrs)
  user_columns = CONN.columns("users").map(&:name)
  filtered = attrs.to_h.slice(*user_columns)
  cols = filtered.keys.map { |c| "`#{c}`" }.join(", ")
  vals = filtered.values.map { |v| CONN.quote(v) }.join(", ")
  CONN.execute("INSERT INTO users (#{cols}) VALUES (#{vals})")
  puts("  Restored User ##{attrs["id"]} (#{attrs["login"]})")
end

def create_user_groups(attrs, all_users_group)
  user_id = attrs["id"]
  one_user_group = UserGroup.create!(
    name: "user #{user_id}", meta: true
  )
  puts("    Created UserGroup '#{one_user_group.name}' " \
       "(ID: #{one_user_group.id})")
  UserGroupUser.create!(
    user_id: user_id, user_group_id: one_user_group.id
  )
  UserGroupUser.create!(
    user_id: user_id, user_group_id: all_users_group.id
  )
  puts("    Added to 'all users' group")
end

def print_report(backup_users, multi_account_emails, dry_run:)
  puts("=" * 60)
  puts("RECOVERY REPORT")
  puts("=" * 60)
  puts
  puts("Total users: #{backup_users.count}")
  puts("Multi-account emails: #{multi_account_emails.size}")
  puts
  print_all_users(backup_users, multi_account_emails)
  print_multi_report(backup_users, multi_account_emails)
  print_next_steps(dry_run)
end

def print_all_users(backup_users, multi_account_emails)
  puts("--- All Users ---")
  backup_users.each do |u|
    flag = multi_account_emails.include?(u["email"]) ? " [MULTI]" : ""
    puts("  ID=#{u["id"]} login=#{u["login"]} " \
         "email=#{u["email"]} created=#{u["created_at"]}#{flag}")
  end
  puts
end

def print_multi_report(backup_users, multi_account_emails)
  return unless multi_account_emails.any?

  puts("--- Multi-Account Users ---")
  multi_account_emails.each do |email|
    users = backup_users.select { |u| u["email"] == email }
    puts("  #{email}:")
    users.each { |u| puts("    - #{u["login"]} (ID: #{u["id"]})") }
  end
  puts
end

def print_next_steps(dry_run)
  if dry_run
    puts("(Dry run - no changes were made)")
  else
    puts("Recovery complete. Next steps:")
    puts("  1. Run script/send_recovery_emails.rb to email users")
    puts("  2. Monitor log/email-debug.log for delivery confirmation")
  end
end

# Main execution
print_header

backup_users = fetch_backup_users
backup_users = remove_already_existing(backup_users)
multi_account_emails = find_multi_account_emails(backup_users)

all_users_group = UserGroup.find_by(name: "all users")
unless all_users_group
  puts("ERROR: 'all users' group not found. Aborting.")
  exit(1)
end
puts("'all users' group ID: #{all_users_group.id}")
puts

if DRY_RUN
  puts("DRY RUN: Would restore #{backup_users.count} user(s).")
  puts("DRY RUN: Would create #{backup_users.count} UserGroup(s).")
  puts("DRY RUN: Would create #{backup_users.count * 2} " \
       "UserGroupUser(s).")
  puts
  puts("Re-run with RECOVER_FOR_REAL=1 to perform restoration.")
  puts
  print_report(backup_users, multi_account_emails, dry_run: true)
  exit(0)
end

puts("Restoring users...")
ActiveRecord::Base.transaction do
  backup_users.each do |u|
    restore_user(u, all_users_group)
  end
end

puts
puts("Successfully restored #{backup_users.count} user(s).")
puts
print_report(backup_users, multi_account_emails, dry_run: false)
