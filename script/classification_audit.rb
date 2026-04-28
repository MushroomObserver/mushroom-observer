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
#      Phase 2 – For each synonym group with at least one non-deprecated
#                member that has a classification, pick a winning
#                classification and apply it to every member whose
#                current classification doesn't already match one of
#                the non-deprecated members'. When non-deprecated
#                members agree, the winner is their shared value. When
#                they diverge, the winner is the classification of the
#                non-deprecated member with the most observations
#                (text_name asc as deterministic tiebreaker). Members
#                whose existing classification matches any non-deprecated
#                member's are left untouched (issue #4130 Q3).
#      Reports – Three CSV files in the repo root:
#                  classification_audit_no_classification_genera.csv
#                  classification_audit_synonym_conflicts.csv
#                  classification_audit_changes.csv   (per-row log)
#                Plus baseline and post-run summary counts on stdout.
#
#                The changes CSV has one row per candidate name
#                whose classification was (or would be) touched, with
#                was_empty and value_changed booleans so you can
#                filter "null → value" cases separately from
#                "overwritten with the same value".
#
#    Use --dry-run to skip mutations; reports and summaries still print.
#    See issue #4155, discussion #4154, and roadmap discussion #4167.
#
#    Post-#4163: classification lives only on `names`, versioned via
#    `name_versions`. Phase 2 saves per-row so each touched Name
#    gets a version row attributed to webmaster (#4166).
#
################################################################################

require_relative("../config/boot")
require_relative("../config/environment")
require("csv")

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
CHANGES_CSV =
  REPORT_DIR.join("classification_audit_changes.csv")
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

# Per-change log accumulated across both phases. One row per candidate
# name whose classification was (or would be) touched. Write-once at
# end. Columns: phase, name_id, text_name, rank, deprecated,
# was_empty, value_changed, trigger, url.
module ChangesLog
  @rows = []

  class << self
    attr_reader :rows

    def add(row)
      @rows << row
    end
  end
end

def url_for_id(id)
  "#{BASE_URL}/names/#{id}"
end

def record_change(phase, info)
  ChangesLog.add([phase, info[:name_id], info[:text_name], info[:rank],
                  info[:deprecated],
                  info[:old_cls].to_s.strip.empty?,
                  normalize(info[:old_cls]) != normalize(info[:new_cls]),
                  info[:trigger], url_for_id(info[:name_id])])
end

# Names whose classification actually changed during this run.
# Computed from ChangesLog rows where value_changed (index 6) is true.
# Drives the end-of-run digest email per affected user (#4169).
def affected_name_ids
  ChangesLog.rows.select { |row| row[6] }.to_set { |row| row[1] }
end

def write_changes_csv
  log("Writing #{CHANGES_CSV}")
  CSV.open(CHANGES_CSV, "w") do |csv|
    csv << %w[phase name_id text_name rank deprecated
              was_empty value_changed trigger url]
    ChangesLog.rows.each { |row| csv << row }
  end
  log("  #{ChangesLog.rows.length} change rows recorded")
  log("")
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

def record_phase_1_candidates(genus, affected_ids)
  Name.where(id: affected_ids).
    pluck(:id, :text_name, :rank, :deprecated, :classification).
    each do |id, tn, rank, dep, old_cls|
      record_change(1, name_id: id, text_name: tn, rank: rank,
                       deprecated: dep, old_cls: old_cls,
                       new_cls: genus.classification,
                       trigger: "genus:#{genus.text_name}")
    end
end

def process_genus(genus)
  affected_ids = genus.subtaxa_whose_classification_needs_to_be_changed
  return 0 if affected_ids.blank?

  vlog("  #{genus.text_name}: #{affected_ids.length} subtaxa/synonyms")
  record_phase_1_candidates(genus, affected_ids)
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
  # `each` (not `find_each`) so the `order(:text_name)` from
  # `genera_with_classification` is honored — `find_each` walks by
  # primary key and would scramble our log/CSV row order.
  genera.each { |genus| process_genus_safely(genus, totals) }
  log("  Phase 1 complete: #{totals[:touched]} rows #{would_str}updated; " \
      "#{totals[:in_sync]} genera already in sync")
  log("")
end

################################################################################
# Phase 2: unify classification within synonym groups
################################################################################

# Returns [candidates, cls_set]:
#   candidates – non-deprecated, non-misspelled members with a
#                non-blank classification (eligible to be the source)
#   cls_set    – set of normalized classifications across `candidates`
#                (members whose existing classification matches any of
#                these are considered already aligned and left alone)
def synonym_group_classifications(members)
  non_dep = members.reject do |n|
    n.deprecated || n.correct_spelling_id.present?
  end
  candidates = non_dep.reject { |n| n.classification.to_s.strip.empty? }
  cls_set = candidates.map { |n| normalize(n.classification) }.uniq
  [candidates, cls_set]
end

# Most-observed candidate wins; ties broken by text_name asc so the
# audit is deterministic across runs.
def pick_winning_source(candidates)
  return candidates.first if candidates.size == 1

  counts = Observation.where(name_id: candidates.map(&:id)).
           group(:name_id).count
  candidates.min_by { |n| [-counts.fetch(n.id, 0), n.text_name.to_s] }
end

def record_phase_2_candidates(stale, syn_id, new_cls, tiebreaker)
  trigger = "synonym_id:#{syn_id}"
  trigger += "(tiebreaker)" if tiebreaker
  stale.each do |n|
    record_change(2, name_id: n.id, text_name: n.text_name,
                     rank: n.rank, deprecated: n.deprecated,
                     old_cls: n.classification, new_cls: new_cls,
                     trigger: trigger)
  end
end

def apply_winning_classification(members, winning_cls, cls_set, syn_id,
                                 tiebreaker:)
  stale = members.reject do |n|
    cls_set.include?(normalize(n.classification))
  end
  return 0 if stale.empty?

  record_phase_2_candidates(stale, syn_id, winning_cls, tiebreaker)
  sync_synonym_classification(stale.map(&:id), winning_cls) unless DRY_RUN
  stale.length
end

# Phase 3 of the classification roadmap (#4163, #4166): switch from
# `update_all` (bypasses `acts_as_versioned`) to per-row save so each
# affected Name gets a `name_versions` row. Phase 2 of the audit can
# change a Name's classification without any parent edit to fall back
# on, so the smart version browser can't infer historical state from
# ancestors — we have to record it directly.
#
# Two flags on each save:
#
# - `skip_notify = true` — suppresses `Name#notify_users` so an audit
#   run doesn't fire one NameChangeMailer per affected name per
#   subscriber (would be tens of thousands of emails per run).
#   `acts_as_versioned` still fires; the version trail is the audit
#   record. A future "one summary email per user with the list of
#   affected taxa" mailer is tracked separately (#4169).
# - `validate: false` — some legacy Name rows have `author` strings
#   that fail current format rules (grandfathered in from before the
#   validation tightened). We're only touching `classification`;
#   failing the whole batch on an unrelated column would block
#   legitimate audit work.
#
# Volume is bounded (~7-10K rows per weekly run on production-scale
# data), so the slower per-row path is fine. Description and
# observation cache writes went away with the column itself in #4165.
def sync_synonym_classification(name_ids, classification)
  Name.transaction do
    Name.where(id: name_ids).find_each do |name|
      name.skip_notify = true
      name.classification = classification
      name.save!(validate: false)
    end
  end
end

def process_synonym_group(syn_id)
  members = Name.where(synonym_id: syn_id).to_a
  candidates, cls_set = synonym_group_classifications(members)
  return [:skipped, false] if candidates.empty?

  tiebreaker = cls_set.size > 1
  winning = pick_winning_source(candidates)
  changed = apply_winning_classification(members, winning.classification,
                                         cls_set, syn_id,
                                         tiebreaker: tiebreaker)
  [changed.zero? ? :skipped : changed, tiebreaker]
end

def phase_2_propagate_within_synonym_groups
  log("Phase 2: unifying classification across synonym groups")
  groups = Name.where.not(synonym_id: nil).
           select(:synonym_id).distinct.pluck(:synonym_id)
  log("  #{groups.size} synonym groups")

  totals = { copied: 0, skipped: 0, divergent: 0, tiebroken_rewrites: 0 }
  groups.each { |syn_id| accumulate_phase_2(syn_id, totals) }
  log_phase_2_summary(totals)
end

def log_phase_2_summary(totals)
  log("  Phase 2 complete: #{totals[:copied]} rows #{would_str}updated; " \
      "#{totals[:skipped]} groups already in sync or with no source; " \
      "#{totals[:divergent]} groups with divergent non-deprecated " \
      "classifications (#{totals[:tiebroken_rewrites]} required " \
      "tiebreaker rewrites)")
  log("")
end

def accumulate_phase_2(syn_id, totals)
  result, tiebreaker = process_synonym_group(syn_id)
  totals[:divergent] += 1 if tiebreaker
  if result == :skipped
    totals[:skipped] += 1
  else
    totals[:copied] += result
    totals[:tiebroken_rewrites] += 1 if tiebreaker
  end
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
  # `each` (not `find_each`) so the scope's `order(:text_name)` is
  # honored in the CSV.
  scope.each do |g|
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
  _candidates, cls_set = synonym_group_classifications(members)
  cls_set.size > 1 ? members : nil
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

def send_audit_digests
  return log("Skipping digest emails (DRY_RUN)") if DRY_RUN

  affected = affected_name_ids
  return log("No name classifications changed; no digest emails to send") \
    if affected.empty?

  log("Queueing digest emails for #{affected.size} affected names")
  count = NameAuditDigest.send_digests(
    name_ids: affected.to_a,
    sender: User.find(WEBMASTER_ID),
    audit_date: START
  )
  log("  #{count} digest emails queued")
  log("")
end

classification_counts("BASELINE")
phase_1_propagate_from_genera
# Snapshot conflicts BEFORE Phase 2 — once Phase 2's tiebreaker
# resolves a group, its non-deprecated members agree and the report
# would show 0 rows for that synonym_id. Curators want to see what
# was auto-resolved.
report_synonym_conflicts
phase_2_propagate_within_synonym_groups
classification_counts("AFTER")
report_no_classification_genera
write_changes_csv
send_audit_digests

log("classification_audit.rb complete in #{elapsed}s")
