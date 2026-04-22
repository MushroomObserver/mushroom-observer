#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    script/classification_audit.rb [-n|--dry-run] [-v|--verbose]
#
#  DESCRIPTION::
#
#    Audits and backfills `names.classification`:
#
#      Phase 1 – Propagate each genus's classification to its subtaxa
#                and to deprecated synonyms of those subtaxa (same as
#                the UI "Propagate Classification" action). Mutations
#                are attributed to webmaster (user 55281).
#      Phase 2 – For each synonym group whose non-deprecated members
#                share a single whitespace-normalized classification,
#                copy that classification to all members of the group
#                (including deprecated ones), overwriting any diverging
#                value.
#      Reports – Two CSV files in the repo root:
#                  classification_audit_no_classification_genera.csv
#                  classification_audit_synonym_conflicts.csv
#                Plus baseline and post-run summary counts on stdout.
#
#    Use --dry-run to skip mutations; reports and summaries still print.
#    See issue #4155 and discussion #4154.
#
################################################################################

require_relative("../config/boot")
require_relative("../config/environment")

dry_run = false
verbose = false
ARGV.each do |flag|
  case flag
  when "-n", "--dry-run"
    dry_run = true
  when "-v", "--verbose"
    verbose = true
  else
    puts("USAGE: script/classification_audit.rb [-n|--dry-run] [-v|--verbose]")
    exit(1)
  end
end
DRY_RUN = dry_run
VERBOSE = verbose

WEBMASTER_ID = 55_281
REPORT_DIR = Rails.root
NO_CLASS_CSV =
  REPORT_DIR.join("classification_audit_no_classification_genera.csv")
CONFLICTS_CSV =
  REPORT_DIR.join("classification_audit_synonym_conflicts.csv")
BASE_URL = MO.http_domain.presence || "https://mushroomobserver.org"

START = Time.zone.now

def elapsed
  (Time.zone.now - START).round(1)
end

def log(msg)
  puts("[#{elapsed}s] #{msg}")
end

def vlog(msg)
  log(msg) if VERBOSE
end

def normalize(str)
  str.to_s.gsub(/\s+/, " ").strip
end

def show_url(name)
  "#{BASE_URL}/names/#{name.id}"
end

def would_str
  DRY_RUN ? "would be " : ""
end

################################################################################
# Counts summary
################################################################################

def tally_name_rows
  has_obs = Observation.distinct.pluck(:name_id).to_set
  Name.pluck(:rank, :deprecated, :classification, :id).map do |r|
    rank_name, dep, cls, id = r
    [rank_name.to_s, [true, 1].include?(dep), cls.to_s.strip.empty?,
     has_obs.include?(id)]
  end
end

def sort_bucket_keys(buckets)
  buckets.sort_by do |(rank, dep, miss, obs), _|
    rank_int = Name.ranks[rank] || 0
    [-rank_int, dep ? 1 : 0, miss ? 1 : 0, obs ? 0 : 1]
  end
end

def print_counts_table(buckets)
  log("rank             deprecated missing_class  observed     count")
  sort_bucket_keys(buckets).each do |(rank, dep, miss, obs), count|
    log(format("%-16s %-10s %-14s %-9s %8d",
               rank, dep.to_s, miss.to_s, obs.to_s, count))
  end
end

def print_counts_summary(rows, buckets)
  missing = buckets.sum { |(_r, _d, miss, _o), c| miss ? c : 0 }
  missing_obs = buckets.sum { |(_r, _d, miss, obs), c| miss && obs ? c : 0 }
  total = rows.size
  pct = total.zero? ? 0 : (100.0 * missing / total).round(2)
  log("Total names: #{total}; missing classification: #{missing} " \
      "(#{pct}%); of those, #{missing_obs} have observations")
  log("")
end

def classification_counts(label)
  rows = tally_name_rows
  buckets = rows.tally
  log("===== #{label} =====")
  print_counts_table(buckets)
  print_counts_summary(rows, buckets)
end

################################################################################
# Phase 1: propagate from genera with classification
################################################################################

def process_genus(genus)
  affected_ids = genus.subtaxa_whose_classification_needs_to_be_changed
  return 0 if affected_ids.blank?

  vlog("  #{genus.text_name}: #{affected_ids.length} subtaxa/synonyms")
  Name.transaction { genus.propagate_classification } unless DRY_RUN
  affected_ids.length
end

def genera_with_classification
  Name.where(rank: Name.ranks[:Genus]).
    where.not(classification: [nil, ""]).
    order(:text_name)
end

def process_genus_safely(genus, totals)
  delta = process_genus(genus)
  delta.zero? ? totals[:in_sync] += 1 : totals[:touched] += delta
rescue StandardError => e
  log("  ! error on #{genus.text_name} (id=#{genus.id}): " \
      "#{e.class}: #{e.message}")
end

def phase_1_propagate_from_genera
  log("Phase 1: propagating classification from genera with classification")
  genera = genera_with_classification
  log("  #{genera.count} genera to process")

  User.current = User.find(WEBMASTER_ID)
  totals = { touched: 0, in_sync: 0 }
  genera.find_each { |genus| process_genus_safely(genus, totals) }
  log("  Phase 1 complete: #{totals[:touched]} rows #{would_str}updated; " \
      "#{totals[:in_sync]} genera already in sync")
  log("")
end

################################################################################
# Phase 2: unify classification within synonym groups
################################################################################

def synonym_group_canonical_class(members)
  non_dep = members.reject do |n|
    n.deprecated || n.correct_spelling_id.present?
  end
  canonical = non_dep.map(&:classification).map { |c| normalize(c) }.
              reject(&:empty?).uniq
  source = non_dep.detect { |n| normalize(n.classification) == canonical.first }
  [canonical, source]
end

def apply_synonym_classification(members, source)
  stale = members.reject do |n|
    normalize(n.classification) == normalize(source.classification)
  end
  return 0 if stale.empty?

  unless DRY_RUN
    Name.transaction do
      Name.where(id: stale.map(&:id)).
        update_all(classification: source.classification)
    end
  end
  stale.length
end

def process_synonym_group(syn_id)
  members = Name.where(synonym_id: syn_id).to_a
  canonical, source = synonym_group_canonical_class(members)
  return :conflict if canonical.size > 1
  return :skipped if source.nil?

  count = apply_synonym_classification(members, source)
  count.zero? ? :skipped : count
end

def phase_2_propagate_within_synonym_groups
  log("Phase 2: unifying classification across synonym groups")
  groups = Name.where.not(synonym_id: nil).
           select(:synonym_id).distinct.pluck(:synonym_id)
  log("  #{groups.size} synonym groups")

  copied = 0
  skipped = 0
  conflicts = 0
  groups.each do |syn_id|
    case (result = process_synonym_group(syn_id))
    when :conflict then conflicts += 1
    when :skipped then skipped += 1
    else copied += result
    end
  end
  log("  Phase 2 complete: #{copied} rows #{would_str}updated; " \
      "#{skipped} groups already in sync; #{conflicts} conflicts")
  log("")
end

################################################################################
# Reports
################################################################################

def genera_without_classification
  Name.where(rank: Name.ranks[:Genus]).
    where(Name.arel_table[:classification].eq(nil).or(
            Name.arel_table[:classification].eq("")
          )).
    order(:text_name)
end

def genera_with_obs_flags
  scope = genera_without_classification
  has_obs = Observation.where(name_id: scope.select(:id)).distinct.
            pluck(:name_id).to_set
  [scope, has_obs]
end

def write_no_class_csv(csv, scope, has_obs)
  csv << %w[id text_name deprecated has_observations url]
  count = 0
  scope.find_each do |g|
    csv << [g.id, g.text_name, g.deprecated, has_obs.include?(g.id),
            show_url(g)]
    count += 1
  end
  count
end

def report_no_classification_genera
  log("Writing #{NO_CLASS_CSV}")
  scope, has_obs = genera_with_obs_flags
  count = CSV.open(NO_CLASS_CSV, "w") do |csv|
    write_no_class_csv(csv, scope, has_obs)
  end
  log("  #{count} genera reported")
  log("")
end

def conflict_group_members(syn_id)
  members = Name.where(synonym_id: syn_id).order(:text_name).to_a
  canonical, _source = synonym_group_canonical_class(members)
  canonical.size > 1 ? members : nil
end

def conflict_csv_row(syn_id, member)
  [syn_id, member.id, member.text_name, member.deprecated,
   normalize(member.classification).first(120), show_url(member)]
end

def write_conflict_csv(csv, groups)
  csv << %w[synonym_id name_id text_name deprecated
            classification_snippet url]
  count = 0
  groups.each do |syn_id|
    members = conflict_group_members(syn_id)
    next unless members

    count += 1
    members.each { |m| csv << conflict_csv_row(syn_id, m) }
  end
  count
end

def report_synonym_conflicts
  log("Writing #{CONFLICTS_CSV}")
  groups = Name.where.not(synonym_id: nil).
           select(:synonym_id).distinct.pluck(:synonym_id)
  count = CSV.open(CONFLICTS_CSV, "w") { |csv| write_conflict_csv(csv, groups) }
  log("  #{count} synonym groups with conflicting classifications")
  log("")
end

################################################################################

log("classification_audit.rb starting " \
    "(#{DRY_RUN ? "DRY RUN" : "LIVE"}, verbose=#{VERBOSE})")
log("")

classification_counts("BASELINE")
phase_1_propagate_from_genera
phase_2_propagate_within_synonym_groups
classification_counts("AFTER")
report_no_classification_genera
report_synonym_conflicts

log("classification_audit.rb complete in #{elapsed}s")
