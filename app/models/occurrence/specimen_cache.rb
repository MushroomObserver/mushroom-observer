# frozen_string_literal: true

# Maintains the cached has_specimen column: true if any member
# observation has a specimen.
module Occurrence::SpecimenCache
  extend ActiveSupport::Concern

  # Recompute cached has_specimen from associated observations.
  def recompute_has_specimen!
    update!(has_specimen: observations.where(specimen: true).exists?)
  end

  class_methods do
    # Nightly safety net: recompute has_specimen on all occurrences.
    # A row that fails validation (e.g. a dangling primary_observation)
    # doesn't abort the sweep: its failure message is recorded, yielded
    # to the caller, and the remaining rows are still repaired.
    def refresh_has_specimen_cache(dry_run: false)
      msgs = []
      find_each do |occ|
        correct = occ.observations.where(specimen: true).exists?
        next if occ.has_specimen == correct

        msgs << "Occurrence ##{occ.id}: has_specimen " \
                "#{occ.has_specimen} -> #{correct}"
        begin
          occ.update!(has_specimen: correct) unless dry_run
        rescue ActiveRecord::RecordInvalid => e
          failure = "Occurrence ##{occ.id}: has_specimen repair " \
                    "failed - #{e.message}"
          msgs << failure
          yield(failure) if block_given?
        end
      end
      msgs
    end
  end
end
