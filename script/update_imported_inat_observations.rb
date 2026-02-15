# frozen_string_literal: true

# Rails runner script to update key data in imported observations from iNat
# Updates: Proposed Names (from iNat identifications), Provisional Names,
# Sequences
#
# Usage:
#   bin/rails runner script/update_imported_inat_observations.rb \
#     'AR_SEARCH_STRING' [USER_ID]
#
# Examples:
#   bin/rails runner script/update_imported_inat_observations.rb \
#     'Observation.where.not(inat_id: nil).limit(10)' 0
#   bin/rails runner script/update_imported_inat_observations.rb \
#     'Observation.projects(389).where.not(inat_id: nil)' 123

require "net/http"
require "json"

# Main execution
if ARGV.empty?
  puts("Usage: bin/rails runner script/update_imported_inat_observations.rb " \
       "'AR_SEARCH_STRING' [USER_ID]")
  puts("")
  puts("Arguments:")
  puts("  AR_SEARCH_STRING - ActiveRecord query to find observations")
  puts("  USER_ID          - User ID to attribute new records to (default: 0)")
  puts("")
  puts("Example:")
  puts("  bin/rails runner script/update_imported_inat_observations.rb \\")
  puts("    'Observation.where.not(inat_id: nil).limit(10)' 0")
  exit(1)
end

search_string = ARGV[0]
user_id = ARGV[1].to_i

puts("Executing search: #{search_string}")
puts("Using user_id: #{user_id}")
puts("")

observations = eval(search_string).to_a # rubocop:disable Security/Eval

puts("Found #{observations.count} MO observations")

# Filter to only those with inat_id
observations_with_inat = observations.select(&:inat_id)
puts("#{observations_with_inat.count} have inat_id's")

if observations_with_inat.empty?
  puts("Exiting.")
  exit(0)
end

# Validate user exists
user = User.find_by(id: user_id)
if user.nil?
  puts("ERROR: User with id #{user_id} not found.")
  puts("Please provide a valid user ID as the second argument.")
  exit(1)
end

puts("Updates will be attributed to #{user.unique_text_name}")
puts("")

# Set User.current for Naming.construct
# FIXME: This is not thread-safe; consider refactoring if using threads
User.current = user

puts("Fetching iNat obs data (may take a while due to rate limiting)...")

# Run the updater
updater = Inat::ObservationUpdater.new(observations_with_inat, user)
stats = updater.run

puts("Retrieved data for iNat observations")
puts("")

puts("Processing observations...")
# Print details during processing
stats.details.each do |detail|
  puts("  #{detail}")
end

# Print summary
print_summary(stats)

#####

def print_summary(stats)
  puts("")
  print_summary_header
  print_summary_stats(stats)
  print_summary_errors(stats) if stats.errors.any?
  puts("=" * 70)
end

def print_summary_header
  puts("=" * 70)
  puts("SUMMARY")
  puts("=" * 70)
end

def print_summary_stats(stats)
  puts("Observations processed: #{stats.observations_processed}")
  puts("Namings added:          #{stats.namings_added}")
  puts("Provisional names added: #{stats.provisional_names_added}")
  puts("Sequences added:        #{stats.sequences_added}")
  puts("Errors:                 #{stats.error_count}")
end

def print_summary_errors(stats)
  puts("")
  puts("ERRORS:")
  stats.errors.each do |error|
    puts("  - #{error}")
  end
end
