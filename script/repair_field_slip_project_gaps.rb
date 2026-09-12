#!/usr/bin/env ruby
# frozen_string_literal: true

# Repairs field slips whose project does not contain all of the slip's
# observations, restoring the invariant that a slip associated with a
# project has every one of its observations in that project (#4932).
#
#   bin/rails runner script/repair_field_slip_project_gaps.rb          # dry run
#   bin/rails runner script/repair_field_slip_project_gaps.rb --apply
#
# Two outcomes, decided per gap by whether the observation satisfies the
# project's constraints:
#
#   ADD    the observation meets the constraints, so it simply belongs in
#          the project and was never added. Adds it.
#   ORPHAN the observation violates the constraints, which means the slip
#          was used outside the project's context — a spare slip, a
#          mis-scanned code, a foray slip used months later. Neither the
#          slip nor the observation should be in the project, so the
#          slip's project is cleared. A project-less slip confers no
#          membership, so the observation is already correct.
#
# Only admins may put a constraint-violating observation into a project,
# so ADD is never the answer for one; orphaning the slip is what makes
# the pair consistent without asserting a membership nobody chose.
#
# Idempotent: a second run finds nothing, because ADD satisfies the
# invariant and ORPHAN removes the slip from the scan (it looks only at
# slips that have a project).
#
# NOTE: run this *with* the fix to Project#adopt_matching_field_slips.
# On its own, adoption re-claims an orphaned slip whose code matches a
# prefix when the owner is a member, which would silently undo every
# ORPHAN below.
class FieldSlipProjectGapRepairer
  def initialize(apply: false)
    @apply = apply
    @added = 0
    @orphaned = 0
  end

  def run
    announce
    gaps.each { |slip, missing| repair(slip, missing) }
    summarize
  end

  private

  def announce
    puts(@apply ? "APPLYING changes." : "DRY RUN. Re-run with --apply.")
    puts
  end

  # [[slip, [observations not in slip.project]], ...]
  def gaps
    FieldSlip.where.not(project_id: nil).
      includes(:project, occurrence: { observations: :projects }).
      filter_map do |slip|
        observations = slip.occurrence&.observations.to_a
        next if observations.empty?

        missing = observations.reject do |obs|
          obs.project_ids.include?(slip.project_id)
        end
        [slip, missing] if missing.any?
      end
  end

  def repair(slip, missing)
    violating = missing.select { |obs| slip.project.violates_constraints?(obs) }

    if violating.any?
      orphan(slip, violating)
    else
      missing.each { |obs| add(slip, obs) }
    end
  end

  def add(slip, obs)
    @added += 1
    puts("ADD    obs #{obs.id} -> project #{slip.project_id} " \
         "(#{slip.project.title}) via #{slip.code}")
    slip.project.add_observation(obs) if @apply
  end

  def orphan(slip, violating)
    @orphaned += 1
    kinds = violating.flat_map { |obs| slip.project.violation_kinds_for(obs) }
    puts("ORPHAN slip #{slip.id} (#{slip.code}) from project " \
         "#{slip.project_id} (#{slip.project.title}) — obs " \
         "#{violating.map(&:id).join(", ")} violates #{kinds.uniq.join(", ")}")
    slip.update!(project_id: nil) if @apply
  end

  def summarize
    puts
    puts("#{@added} observations added, #{@orphaned} slips orphaned.")
    puts("Nothing was written. Re-run with --apply.") unless @apply
  end
end

FieldSlipProjectGapRepairer.new(apply: ARGV.include?("--apply")).run
