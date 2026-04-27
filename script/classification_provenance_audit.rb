#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    bin/rails runner script/classification_provenance_audit.rb
#
#  DESCRIPTION::
#
#    Phase 2 of the classification roadmap (#4163 follow-up). Walks
#    every Name and buckets it by what its classification source
#    likely is. Helps size Phase 4 (genus imports) and Phase 5
#    (external-source validation) by showing the shape of what's
#    in production right now.
#
#    Buckets:
#      - no_classification:
#          The Name has no classification at all.
#      - above_genus_curator:
#          Rank above Genus, has a classification. Has to be curator
#          input — there's nothing to inherit from.
#      - genus_curator:
#          Rank == Genus, has a classification. Curator input.
#      - below_genus_no_genus:
#          Below Genus, has classification, but no genus row found
#          for the leading word of its text_name. Rare; likely a data
#          quirk. Treat as curator input.
#      - below_genus_genus_blank:
#          Below Genus with classification, genus exists but its own
#          classification is blank. The Name is the only source.
#      - below_genus_matches_genus:
#          Classification matches the inferred genus's classification
#          verbatim. Almost certainly propagated.
#      - below_genus_differs_from_genus:
#          Classification differs from the inferred genus's. Either
#          hand-curated or stale propagation.
#
#    Outputs `classification_provenance.csv` (summary, one row per
#    bucket) and prints the same to stdout.
#
################################################################################

require_relative("../config/boot")
require_relative("../config/environment")
require("csv")

OUT = Rails.root.join("classification_provenance.csv")
START = Time.zone.now

def elapsed
  (Time.zone.now - START).round(1)
end

def log(msg)
  puts("[#{elapsed}s] #{msg}")
end

def normalize(str)
  str.to_s.gsub(/\s+/, " ").strip
end

# Pre-load genera into a lookup by text_name so we don't run a query
# per Name. For each text_name we keep a single representative,
# preferring non-deprecated and non-"sensu" (mirrors `accepted_genus`'s
# tiebreaker but skips synonym resolution to keep this O(N) overall).
def load_genera_by_text_name
  rows = Name.where(rank: Name.ranks[:Genus]).
         pluck(:text_name, :classification, :deprecated, :author)
  rows.group_by(&:first).transform_values do |group|
    group.min_by do |_text, _cls, deprecated, author|
      [deprecated ? 1 : 0, author.to_s.start_with?("sensu ") ? 1 : 0]
    end
  end
end

def lookup_genus(name, genera_by_text)
  return nil unless name.text_name.include?(" ")

  genera_by_text[name.text_name.split(" ", 2).first]
end

def bucket_for(name, genus_row)
  return "no_classification" if name.classification.blank?
  return "above_genus_curator" if Name.ranks_above_genus.include?(name.rank)
  return "genus_curator" if name.rank == "Genus"
  return "below_genus_no_genus" if genus_row.nil?

  genus_classification = genus_row[1]
  return "below_genus_genus_blank" if genus_classification.blank?

  if normalize(name.classification) == normalize(genus_classification)
    "below_genus_matches_genus"
  else
    "below_genus_differs_from_genus"
  end
end

def percent_of(count, total)
  total.zero? ? 0 : (100.0 * count / total).round(2)
end

def write_csv(counts, total)
  CSV.open(OUT, "w") do |csv|
    csv << %w[bucket count percentage]
    counts.sort_by { |_, count| -count }.each do |bucket, count|
      csv << [bucket, count, percent_of(count, total)]
    end
  end
  log("Wrote #{OUT}")
end

def print_summary(counts, total)
  log("=" * 60)
  log("bucket                                count    percent")
  counts.sort_by { |_, count| -count }.each do |bucket, count|
    log(format("%-32s %10d %9.2f%%",
               bucket, count, percent_of(count, total)))
  end
  log("-" * 60)
  log(format("%-32s %10d", "total", total))
end

def report(counts)
  total = counts.values.sum
  write_csv(counts, total)
  print_summary(counts, total)
end

log("Loading genera into memory…")
genera_by_text = load_genera_by_text_name
log("  #{genera_by_text.size} unique genus text_names")

# Bucket non-genus rows row-by-row, but dedupe genera by text_name so
# Phase 4's "how many genera need classification" answer counts unique
# taxonomic concepts, not the handful of duplicate accepted/deprecated/
# sensu rows that share a text_name. (Non-genus duplicates are still
# row-counted; a similar dedupe pass for those is a separate refinement.)
log("Scanning non-genus names…")
counts = Hash.new(0)
processed = 0
Name.where.not(rank: Name.ranks[:Genus]).find_each(batch_size: 5000) do |name|
  bucket = bucket_for(name, lookup_genus(name, genera_by_text))
  counts[bucket] += 1
  processed += 1
  log("  #{processed} processed") if (processed % 20_000).zero?
end
log("Scanned #{processed} non-genus names")

log("Bucketing genera (one representative per unique text_name)…")
genera_by_text.each_value do |_text_name, classification, _deprecated, _author|
  counts[classification.blank? ? "no_classification" : "genus_curator"] += 1
end
log("Bucketed #{genera_by_text.size} unique genus text_names")

report(counts)
