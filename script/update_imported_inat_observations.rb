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

INAT_API_BASE = "https://api.inaturalist.org/v1/observations"
RATE_LIMIT_DELAY = 1 # seconds between API requests
BATCH_SIZE = 200

# Statistics tracking
@stats = {
  observations_processed: 0,
  namings_added: 0,
  provisional_names_added: 0,
  sequences_added: 0,
  errors: []
}

# Main execution
if ARGV.empty?
  puts "Usage: bin/rails runner script/update_imported_inat_observations.rb " \
       "'AR_SEARCH_STRING' [USER_ID]"
  puts ""
  puts "Arguments:"
  puts "  AR_SEARCH_STRING - ActiveRecord query to find observations"
  puts "  USER_ID          - User ID to attribute new records to (default: 0)"
  puts ""
  puts "Example:"
  puts "  bin/rails runner script/update_imported_inat_observations.rb \\"
  puts "    'Observation.where.not(inat_id: nil).limit(10)' 0"
  exit(1)
end

search_string = ARGV[0]
user_id = ARGV[1].to_i

puts "Executing search: #{search_string}"
puts "Using user_id: #{user_id}"
puts ""

observations = eval(search_string).to_a # rubocop:disable Security/Eval

puts "Found #{observations.count} MO observations"

# Filter to only those with inat_id
observations_with_inat = observations.select(&:inat_id)
puts "#{observations_with_inat.count} have inat_id's"

if observations_with_inat.empty?
  puts "Exiting."
  exit(0)
end

# Validate user exists
user = User.find_by(id: user_id)
if user.nil?
  puts "ERROR: User with id #{user_id} not found."
  puts "Please provide a valid user ID as the second argument."
  exit(1)
end

puts "Updates will be attributed to #{user.unique_text_name}"
puts ""

# Set User.current for Naming.construct
# FIXME: This is not thread-safe; consider refactoring if using threads
User.current = user

inat_ids = observations_with_inat.map(&:inat_id)
puts "Fetching iNat obs data (may take a while due to rate limiting)..."

inat_data = fetch_inat_observations(inat_ids)
puts "Retrieved data for #{inat_data.count} iNat observations"
puts ""

puts "Processing observations..."
observations_with_inat.each do |obs|
  process_observation(obs, inat_data[obs.inat_id])
rescue StandardError => e
  @stats[:errors] << "Observation #{obs.id}: #{e.message}"
  puts("  ERROR processing observation #{obs.id}: #{e.message}")
end

print_summary

#####

def fetch_inat_observations(inat_ids)
  results = {}
  inat_ids.each_slice(BATCH_SIZE) do |batch|
    fetch_batch(batch, results)
    sleep(RATE_LIMIT_DELAY)
  end
  results
end

def fetch_batch(batch, results)
  page = 1
  loop do
    break unless fetch_page?(batch, page, results)

    page += 1
    sleep(RATE_LIMIT_DELAY)
  end
end

def fetch_page?(batch, page, results)
  response = make_api_request(batch, page)
  return false unless response.is_a?(Net::HTTPSuccess)

  data = JSON.parse(response.body, symbolize_names: true)
  store_results(data[:results], results)
  more_pages?(data[:total_results], page)
end

def make_api_request(batch, page)
  uri = build_api_uri(batch, page)
  Net::HTTP.get_response(uri)
rescue StandardError => e
  puts("Warning: API request failed - #{e.message}")
  nil
end

def build_api_uri(batch, page)
  uri = URI(INAT_API_BASE)
  params = {
    id: batch.join(","),
    per_page: BATCH_SIZE,
    page: page,
    only_id: false
  }
  uri.query = URI.encode_www_form(params)
  uri
end

def store_results(observations, results)
  observations.each do |obs|
    results[obs[:id]] = obs
  end
end

def more_pages?(total_results, page)
  fetched_so_far = page * BATCH_SIZE
  fetched_so_far < total_results
end

def process_observation(obs, inat_obs_data)
  return unless inat_obs_data

  puts("Processing MO observation #{obs.id} (iNat #{obs.inat_id})...")
  @stats[:observations_processed] += 1

  # Process suggested identifications
  process_identifications(obs, inat_obs_data[:identifications])

  # Process provisional name
  process_provisional_name(obs, inat_obs_data)

  # Process sequences
  process_sequences(obs, inat_obs_data[:ofvs])

  # Recalculate naming consensus after adding new namings
  Observation::NamingConsensus.new(obs).calc_consensus
  obs.save! if obs.changed?
end

def process_identifications(obs, identifications)
  return unless identifications&.any?

  identifications.each do |ident|
    process_identification(obs, ident)
  end
end

def process_identification(obs, ident)
  taxon = ident[:taxon]
  return unless taxon

  # FIXME: This needs a ton of help
  # inat taxon names are not like MO names
  # Check ::Inat::Obs
  taxon_name = taxon[:name]
  return unless taxon_name

  # Find or create Name in MO
  name = find_or_skip_name(taxon_name)
  return unless name

  # Check if this name or a synonym has already been proposed
  return if name_already_proposed?(obs, name)

  # Create the naming
  create_naming(obs, name, ident)
end

def find_or_skip_name(taxon_name)
  # Try to find exact match
  # FIXME: Try complexes first.
  name = Name.find_by(text_name: taxon_name)
  return name if name

  # FIXME: Huh???
  # Try search_name (normalized version)
  search_name = taxon_name.tr(" ", "_").downcase
  name = Name.find_by(search_name: search_name)
  return name if name

  puts("  - Name '#{taxon_name}' not found in MO database, skipping")
  nil
end

def name_already_proposed?(obs, name)
  # Check if the name itself has been proposed
  return true if obs.namings.exists?(name_id: name.id)

  # FIXME: Probably don't want to do this.
  # Check if a synonym has been proposed
  name.synonyms.each do |synonym|
    return true if obs.namings.exists?(name_id: synonym.id)
  end

  false
end

def create_naming(obs, name, ident)
  naming = build_naming(obs, name, ident)

  if naming.save
    record_naming_success(name)
  else
    record_naming_failure(obs, naming)
  end
end

def build_naming(obs, name, ident)
  now = Time.zone.now
  user = User.current

  Naming.new(
    created_at: now,
    updated_at: now,
    observation_id: obs.id,
    name_id: name.id,
    user_id: user.id,
    reasons: build_naming_reason(ident).to_yaml
  )
end

def build_naming_reason(ident)
  identifier = ident[:user][:login]
  date = ident[:created_at_details][:date]
  { 1 => "iNat suggested identification by #{identifier} on #{date}" }
end

def record_naming_success(name)
  puts("  + Added naming: #{name.text_name}")
  @stats[:namings_added] += 1
end

def record_naming_failure(obs, naming)
  error_msg = naming.errors.full_messages.join(", ")
  puts("  - Failed to add naming: #{error_msg}")
  @stats[:errors] << "Naming for observation #{obs.id}: #{error_msg}"
end

def process_provisional_name(obs, inat_obs_data)
  ofvs = inat_obs_data[:ofvs]
  return unless ofvs&.any?

  prov_field = find_provisional_name_field(ofvs)
  return unless prov_field

  prov_name = prov_field[:value]
  return if prov_name.blank?
  return if skip_provisional_name?(obs, prov_name)

  add_provisional_name_to_notes(obs, prov_name)
  # FIXME: Create a Naming
end

def find_provisional_name_field(ofvs)
  ofvs.find { |field| field[:name] =~ /^Provisional Species Name/ }
end

def skip_provisional_name?(obs, prov_name)
  # Check if already proposed or already in notes
  return true if provisional_name_is_proposed?(obs, prov_name)

  if provisional_name_in_notes?(obs, prov_name)
    puts("  - Provisional name '#{prov_name}' already in notes")
    return true
  end

  false
end

def provisional_name_in_notes?(obs, prov_name)
  obs.notes && obs.notes[:Other]&.include?(prov_name)
end

def provisional_name_is_proposed?(obs, prov_name)
  # Check if provisional name matches any proposed name's text_name
  obs.namings.includes(:name).any? do |naming|
    naming.name.text_name.casecmp?(prov_name)
  end
end

def add_provisional_name_to_notes(obs, prov_name)
  update_observation_notes(obs, prov_name)

  if obs.save
    record_provisional_name_success(prov_name)
  else
    record_provisional_name_failure(obs)
  end
end

def update_observation_notes(obs, prov_name)
  obs.notes ||= {}
  obs.notes[:Other] ||= ""
  prov_note = "\n\n_Provisional name from iNat: #{prov_name}_"
  obs.notes[:Other] += prov_note
end

def record_provisional_name_success(prov_name)
  puts("  + Added provisional name: #{prov_name}")
  @stats[:provisional_names_added] += 1
end

def record_provisional_name_failure(obs)
  error_msg = obs.errors.full_messages.join(", ")
  puts("  - Failed to add provisional name: #{error_msg}")
  @stats[:errors] << "Provisional name for observation #{obs.id}: #{error_msg}"
end

def process_sequences(obs, ofvs)
  return unless ofvs&.any?

  sequence_fields = ofvs.select { |f| sequence_field?(f) }
  return unless sequence_fields.any?

  sequence_fields.each do |field|
    process_sequence_field(obs, field)
  end
end

def sequence_field?(field)
  # FIXME: double-check
  # Proabaly want to do same as iNat importer
  field[:datatype] == "dna" ||
    field[:name] =~ /DNA/ && field[:value] =~ /^[ACTG]{1,}/
end

def process_sequence_field(obs, field)
  locus = field[:name]
  bases = field[:value]

  return if bases.blank?
  return if sequence_already_exists?(obs, locus, bases)

  create_sequence(obs, locus, bases)
end

def sequence_already_exists?(obs, locus, bases)
  # Normalize bases for comparison (remove whitespace, convert to uppercase)
  normalized_bases = bases.gsub(/\s+/, "").upcase

  obs.sequences.any? do |seq|
    seq.locus == locus &&
      seq.bases&.gsub(/\s+/, "")&.upcase == normalized_bases
  end
end

def create_sequence(obs, locus, bases)
  sequence = build_sequence(obs, locus, bases)

  if sequence.save
    record_sequence_success(locus)
  else
    record_sequence_failure(obs, sequence)
  end
end

def build_sequence(obs, locus, bases)
  Sequence.new(
    observation: obs,
    user: User.current,
    locus: locus,
    bases: bases,
    archive: "",
    accession: "",
    notes: "Imported from iNat observation field"
  )
end

def record_sequence_success(locus)
  puts("  + Added sequence: #{locus}")
  @stats[:sequences_added] += 1
end

def record_sequence_failure(obs, sequence)
  error_msg = sequence.errors.full_messages.join(", ")
  puts("  - Failed to add sequence: #{error_msg}")
  @stats[:errors] << "Sequence for observation #{obs.id}: #{error_msg}"
end

#####

def print_summary
  puts("")
  print_summary_header
  print_summary_stats
  print_summary_errors if @stats[:errors].any?
  puts("=" * 70)
end

def print_summary_header
  puts("=" * 70)
  puts("SUMMARY")
  puts("=" * 70)
end

def print_summary_stats
  puts("Observations processed: #{@stats[:observations_processed]}")
  puts("Namings added:          #{@stats[:namings_added]}")
  puts("Provisional names added: #{@stats[:provisional_names_added]}")
  puts("Sequences added:        #{@stats[:sequences_added]}")
  puts("Errors:                 #{@stats[:errors].count}")
end

def print_summary_errors
  puts("")
  puts("ERRORS:")
  @stats[:errors].each do |error|
    puts("  - #{error}")
  end
end
