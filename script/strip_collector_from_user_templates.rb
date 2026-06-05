#!/usr/bin/env ruby
# frozen_string_literal: true

# Remove the now-forbidden exact "Collector" heading from users'
# notes_template (#4211). Collector has its own observation column, so it
# may no longer be a notes sub-heading; leaving it in a saved template
# would block the user's next profile save. Variant headings (e.g.
# "Collector's Name") are independent fields and are left untouched.
#
#   bin/rails runner script/strip_collector_from_user_templates.rb
#   DRY_RUN=1 bin/rails runner script/strip_collector_from_user_templates.rb
#
# Idempotent: re-running finds no exact "Collector" parts.
dry_run = ENV["DRY_RUN"].present?
changed = 0

User.where("notes_template LIKE ?", "%Collector%").find_each do |user|
  parts = user.notes_template.to_s.split(",").map(&:squish)
  next unless parts.include?("Collector")

  kept = parts.reject { |p| p == "Collector" }.join(", ")
  changed += 1
  puts("user #{user.id} #{user.login}: #{user.notes_template.inspect} -> " \
       "#{kept.inspect}")
  next if dry_run

  user.update_column(:notes_template, kept)
end

if dry_run
  puts("DRY RUN — #{changed} templates would change.")
else
  puts("Stripped 'Collector' from #{changed} templates.")
end
