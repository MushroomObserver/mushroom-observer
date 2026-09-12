#!/usr/bin/env ruby
# frozen_string_literal: true

# Attaches slip-less observations to the field slip their completed
# extraction read, for observations the QR decode missed (zbar failed
# on ~27% of the 2026 CMS fair's slip photos while the extraction read
# the printed code off nearly all of them). One-time repair for
# observations created before ExtractFieldSlipJob learned to do this
# itself; safe to re-run -- already-linked observations are skipped.
#
#   bin/rails runner script/attach_slips_from_extracts.rb
#   bin/rails runner script/attach_slips_from_extracts.rb --apply
#
# Uses FieldSlip::Attacher, so the guards hold: never an observation
# that has a slip, never a slip already in use, never a closed
# project's existing slip.
class SlipExtractRepairer
  USAGE = "Usage: bin/rails runner " \
          "script/attach_slips_from_extracts.rb [--apply]"

  def self.from_argv(argv)
    apply = argv.delete("--apply").present?
    abort("#{USAGE}\nUnrecognized: #{argv.join(" ")}") if argv.any?

    new(apply: apply)
  end

  def initialize(apply:)
    @apply = apply
    @tally = Hash.new(0)
  end

  def run
    puts(@apply ? "APPLYING changes." : "DRY RUN.")
    # Streamed rather than loaded whole: every completed extract on
    # the site flows through here.
    FieldSlipExtract.where(status: "complete").includes(:image).
      find_each do |extract|
        obs, image = candidate_for(extract)
        repair(obs, image, extract) if obs
      end
    summarize
  end

  private

  # The slip-less observation behind an extract that read a code, or
  # nil when there is nothing to repair.
  def candidate_for(extract)
    obs = extract.observation
    return nil unless obs && obs.occurrence_id.nil?

    code = extract.value_for(extract.template.code_field).to_s.strip
    return nil if code.blank?

    [obs, extract.image]
  end

  def repair(obs, image, extract)
    code = extract.value_for(extract.template.code_field).to_s.strip
    result =
      if @apply
        FieldSlip::Attacher.attach(observation: obs, code: code,
                                   user: obs.user)
      else
        predicted_result(obs, code)
      end
    @tally[result] += 1
    puts(format("  %-15s obs %-8d img %-8d %s",
                result, obs.id, image.id, code))
  end

  # The same checks Attacher runs, minus the writes, so the dry run
  # reports what apply would do.
  def predicted_result(obs, code)
    return :already_linked if obs.occurrence_id

    existing = FieldSlip.find_by(code: code.upcase)
    return :in_use if existing&.occurrence
    return :closed_project if barred?(existing, obs.user)
    return :invalid unless code.match?(/[^\d.-]/)

    :attached
  end

  def barred?(slip, user)
    project = slip&.project
    project && !project.member?(user) && !project.can_join?(user)
  end

  def summarize
    puts("Results: #{@tally.map { |k, v| "#{k}=#{v}" }.join(", ")}")
    return if @apply

    puts("Dry run - nothing written. To apply: bin/rails runner " \
         "script/attach_slips_from_extracts.rb --apply")
  end
end

SlipExtractRepairer.from_argv(ARGV).run
