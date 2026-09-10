# frozen_string_literal: true

class Inat
  class ReflectionResync
    # Mirrors DNA sequences from a fetched iNat observation onto its
    # reflection (#4215). Sequences on a reflection are source-owned --
    # native sequence adds are routed to the occurrence companion, like
    # every other native contribution -- so the sync is authoritative:
    # after it runs, the reflection's sequences are iNat's.
    #
    # The iNat side comes from the shared SequenceFieldDetector, so
    # import and sync agree on what counts as a sequence; the MO side is
    # compared by the model's identity notion, Sequence#bases_nucleotides
    # (description line, digits and whitespace stripped):
    #
    #   - matching bases -> kept as is;
    #   - one iNat variant and one stale MO sequence sharing a locus ->
    #     edited on iNat: bases updated in place (keeps the record's
    #     id and history);
    #   - other stale MO sequences -> removed from iNat: deleted;
    #   - remaining iNat variants -> created, owned by the observation's
    #     owner (as an import would be);
    #   - an iNat value Sequence validation rejects -> skipped and
    #     reported for the batch's alert digest.
    #
    # All writes log through Sequence's model callbacks
    # (log_sequence_added / _updated / _destroyed), attributed to the
    # owner for adds and the admin actor for updates and deletions.
    class SequenceSync
      Outcome = Data.define(:added, :updated, :removed, :alerts) do
        def changed?
          added.positive? || updated.positive? || removed.positive?
        end
      end

      def call(obs, inat_obs)
        @obs = obs
        @added = 0
        @updated = 0
        @removed = 0
        @alerts = []
        sync(inat_obs.sequences)
        Outcome.new(added: @added, updated: @updated, removed: @removed,
                    alerts: @alerts)
      end

      private

      def sync(desired)
        @existing = @obs.sequences.to_a
        return if desired.empty? && @existing.empty?

        @desired_norms = desired.map { |d| normalize(d[:bases]) }
        loci = (new_variants(desired).pluck(:locus) +
                stale_sequences.map(&:locus)).uniq
        loci.each { |locus| reconcile_locus(locus, desired) }
      end

      # iNat sequences with no bases match anywhere on the reflection.
      def new_variants(desired)
        desired.reject do |d|
          norm = normalize(d[:bases])
          @existing.any? { |s| s.bases_nucleotides == norm }
        end
      end

      # MO sequences whose bases match nothing on iNat.
      def stale_sequences
        @existing.select do |s|
          @desired_norms.exclude?(s.bases_nucleotides)
        end
      end

      def reconcile_locus(locus, desired)
        wants = new_variants(desired).select { |d| d[:locus] == locus }
        stale = stale_sequences.select { |s| s.locus == locus }
        reconcile_pairing(wants, stale)
      end

      def reconcile_pairing(wants, stale)
        return update_sequence(stale.first, wants.first) if
          wants.one? && stale.one?

        stale.each { |s| remove_sequence(s) }
        wants.each { |d| create_sequence(d) }
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
        as_system_actor(seq)
        seq.update!(bases: desired[:bases])
        @updated += 1
      rescue ActiveRecord::RecordInvalid => e
        @alerts << "sequence update rejected (locus " \
                   "#{desired[:locus].inspect}, sequence #{seq.id}): " \
                   "#{e.message}"
      end

      def remove_sequence(seq)
        as_system_actor(seq)
        seq.destroy!
        @removed += 1
      end

      # Sequence's update/destroy callbacks log as
      # observation.current_user; the resync is the system actor.
      def as_system_actor(seq)
        seq.observation = @obs
        @obs.current_user = User.admin
      end

      # Sequence#bases_nucleotides for a raw iNat value.
      def normalize(bases)
        bases.to_s.sub(Sequence::DESCRIPTION, "").gsub(/[\d\s]/, "")
      end
    end
  end
end
