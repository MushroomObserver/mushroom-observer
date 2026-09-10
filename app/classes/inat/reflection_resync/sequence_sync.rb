# frozen_string_literal: true

class Inat
  class ReflectionResync
    # Syncs DNA sequences from a fetched iNat observation onto its
    # reflection (#4215). The iNat side comes from the shared
    # SequenceFieldDetector, so import and sync agree on what counts as
    # a sequence; the MO side is compared by the model's identity
    # notion, Sequence#bases_nucleotides (description line, digits and
    # whitespace stripped):
    #
    #   - matching bases                    -> already synced, no-op;
    #   - new on iNat, no stale counterpart -> create, owned by the
    #     observation's owner (as an import would be);
    #   - one iNat variant and one stale MO sequence sharing a locus
    #     -> edited on iNat: update the bases in place;
    #   - several variants or candidates sharing a locus -> ambiguous:
    #     touch nothing, report for the batch's alert digest.
    #
    # No deletions: sequences stay community-editable on reflections,
    # so an MO-only sequence may be user-added.
    #
    # Activity logging rides on Sequence's model callbacks
    # (log_sequence_added / log_sequence_updated), so synced changes
    # appear in the log the same way hand-entered ones do.
    class SequenceSync
      Outcome = Data.define(:added, :updated, :alerts) do
        def changed?
          added.positive? || updated.positive?
        end
      end

      def call(obs, inat_obs)
        @obs = obs
        @added = 0
        @updated = 0
        @alerts = []
        sync(inat_obs.sequences)
        Outcome.new(added: @added, updated: @updated, alerts: @alerts)
      end

      private

      def sync(desired)
        return if desired.empty?

        @existing = @obs.sequences.to_a
        @desired_norms = desired.map { |d| normalize(d[:bases]) }
        new_variants(desired).group_by { |d| d[:locus] }.
          each { |locus, wants| reconcile_locus(locus, wants) }
      end

      # iNat sequences with no bases match anywhere on the reflection.
      def new_variants(desired)
        desired.reject do |d|
          norm = normalize(d[:bases])
          @existing.any? { |s| s.bases_nucleotides == norm }
        end
      end

      # MO sequences on this locus whose bases match nothing on iNat.
      def stale_for(locus)
        @existing.select do |s|
          s.locus == locus && @desired_norms.exclude?(s.bases_nucleotides)
        end
      end

      def reconcile_locus(locus, wants)
        stale = stale_for(locus)
        if stale.empty?
          wants.each { |d| create_sequence(d) }
        elsif wants.one? && stale.one?
          update_sequence(stale.first, wants.first)
        else
          @alerts << "ambiguous sequence sync for locus #{locus.inspect}: " \
                     "#{wants.size} new iNat variant(s) vs #{stale.size} " \
                     "stale MO sequence(s) - left untouched"
        end
      end

      def create_sequence(desired)
        @obs.sequences.create!(
          user: @obs.user,
          locus: desired[:locus],
          bases: desired[:bases],
          archive: desired[:archive],
          accession: desired[:accession].to_s,
          notes: desired[:notes].to_s
        )
        @added += 1
      rescue ActiveRecord::RecordInvalid => e
        @alerts << "iNat sequence rejected (locus " \
                   "#{desired[:locus].inspect}): #{e.message}"
      end

      def update_sequence(seq, desired)
        # Sequence's update callback logs as observation.current_user;
        # the resync is the system actor.
        seq.observation = @obs
        @obs.current_user = User.admin
        seq.update!(bases: desired[:bases])
        @updated += 1
      rescue ActiveRecord::RecordInvalid => e
        @alerts << "sequence update rejected (locus " \
                   "#{desired[:locus].inspect}, sequence #{seq.id}): " \
                   "#{e.message}"
      end

      # Sequence#bases_nucleotides for a raw iNat value.
      def normalize(bases)
        bases.to_s.sub(Sequence::DESCRIPTION, "").gsub(/[\d\s]/, "")
      end
    end
  end
end
