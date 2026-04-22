#!/usr/bin/env ruby
# frozen_string_literal: true

#  USAGE::
#
#    script/classification_perf.rb [-v|--verbose]
#
#  DESCRIPTION::
#
#    Read-only benchmark of the handful of classification / sub-taxon
#    queries we think are the likely slow ones (see issue #4155 and
#    discussion #4154). Runs each query once with a cold connection,
#    then a few more times after that to see the warm-cache steady
#    state. No writes.
#
#    Queries measured, for each TARGET taxon:
#
#      A. Observation.names(lookup: target, include_subtaxa: true).count
#      B. Name.names(lookup: target, include_subtaxa: true).count
#      C. Name.classification_has(target).count
#
#    Plus, if the target is a genus and a sample Project has it as a
#    target_name, Project#candidate_observations.count.
#
################################################################################

require_relative("../config/boot")
require_relative("../config/environment")

require("benchmark")

verbose = false
ARGV.each do |flag|
  case flag
  when "-v", "--verbose"
    verbose = true
  else
    puts("USAGE: script/classification_perf.rb [-v|--verbose]")
    exit(1)
  end
end
VERBOSE = verbose

# A mix of ranks where add_higher_names (classification LIKE scan) is the
# expected bottleneck, plus one genus for add_lower_names (text_name prefix).
TARGETS = [
  "Fungi",          # Kingdom — biggest possible scan
  "Basidiomycota",  # Phylum
  "Agaricales",     # Order — archetypal "slow" case per issue #4155
  "Amanitaceae",    # Family
  "Amanita",        # Genus — for add_lower_names path
  "Amanita muscaria" # Species — for a shallow-subtaxa baseline
].freeze

WARMUPS = 1
TRIALS = 3

def time_block(&block)
  t = Benchmark.realtime(&block)
  (t * 1000).round(1)
end

def row_count_str(result)
  result.is_a?(Integer) ? format("rows=%-7d", result) : " " * 12
end

def warm_trial_str(trials)
  trials.map { |t| format("%7.1fms", t) }.join(" ")
end

def measure(label, &block)
  # Cold attempt first (not really cold without restarting the connection,
  # but this captures first-call overhead from query-plan caching etc.).
  result = nil
  cold = time_block { result = yield }
  trials = Array.new(TRIALS) { time_block(&block) }
  puts(format("  %-55s %s cold=%7.1fms  warm=%s  median=%7.1fms",
              label, row_count_str(result), cold,
              warm_trial_str(trials), trials.sort[trials.length / 2]))
end

def lookup_name(text)
  Name.where(text_name: text, correct_spelling_id: nil).first
end

def summary_counts
  total = Name.count
  with_class = Name.where.not(classification: [nil, ""]).count
  puts("Names: #{total}; with classification: #{with_class} " \
       "(#{(100.0 * with_class / total).round(2)}%)")
  puts("Observations: #{Observation.count}")
  puts("")
end

################################################################################

puts("classification_perf.rb — read-only benchmark")
puts(Time.zone.now)
puts("")
summary_counts

TARGETS.each do |text|
  name = lookup_name(text)
  unless name
    puts("-- #{text}: not found in Name table, skipping")
    puts("")
    next
  end

  puts("== #{text} (rank=#{name.rank}, id=#{name.id}) ==")

  measure("Observation.names(include_subtaxa:true).count") do
    Observation.names(lookup: name.id, include_subtaxa: true).count
  end

  measure("Name.names(include_subtaxa:true).count") do
    Name.names(lookup: name.id, include_subtaxa: true).count
  end

  measure("Name.classification_has(#{text.inspect}).count") do
    Name.classification_has(text).count
  end

  # If this target is set on at least one project, benchmark the full
  # candidate_observations pipeline for that project.
  proj = Project.joins(:target_names).
         where(names: { id: name.id }).first
  if proj
    measure("Project(id=#{proj.id}).candidate_observations.count") do
      proj.candidate_observations.count
    end
  end

  puts("")
end

puts("Done at #{Time.zone.now}")
