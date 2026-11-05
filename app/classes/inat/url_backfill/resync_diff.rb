# frozen_string_literal: true

class Inat
  class URLBackfill
    # Names what one resync changed, read off the observation before and
    # after: ReflectionResync reports a single :synced status, not
    # per-engine counts, and the log line has to be specific enough to
    # check by hand weeks later.
    class ResyncDiff
      # The fields Inat::ReflectionResync#scalar_attributes writes.
      SCALAR_FIELDS = %w[when notes gps_hidden location_id where lat
                         lng].freeze

      class << self
        def snapshot(obs)
          { thumb: obs.thumb_image_id, name: obs.name_id,
            sequences: obs.sequences.pluck(:id).to_set,
            scalars: obs.slice(*SCALAR_FIELDS) }.
            merge(image_snapshot(obs)).merge(naming_snapshot(obs))
        end

        def describe(before, after)
          parts = collection_changes(before, after) +
                  attribute_changes(before, after)
          parts.compact.join(", ").presence || "no visible diff"
        end

        private

        def image_snapshot(obs)
          ids = ObservationImage.where(observation_id: obs.id).
                pluck(:image_id)
          { images: ids.to_set,
            meta: Image.where(id: ids).
                  pluck(:id, :license_id, :copyright_holder).to_set }
        end

        def naming_snapshot(obs)
          ids = obs.namings.pluck(:id)
          { namings: ids.to_set,
            votes: Vote.where(naming_id: ids).pluck(:id, :value).to_set }
        end

        def collection_changes(before, after)
          [:images, :sequences, :namings].map do |key|
            count_change(key, before[key], after[key])
          end
        end

        def attribute_changes(before, after)
          [image_meta_change(before, after), scalar_change(before, after),
           vote_change(before, after),
           ("thumb" if before[:thumb] != after[:thumb]),
           ("name" if before[:name] != after[:name])]
        end

        # A reweight keeps the vote row, so count the values that moved.
        def vote_change(before, after)
          moved = (after[:votes] - before[:votes]).count
          "votes #{moved}" if moved.positive?
        end

        # License or copyright-holder edits on images the obs kept.
        def image_meta_change(before, after)
          kept = before[:images] & after[:images]
          edited = (after[:meta] - before[:meta]).count do |id, _l, _c|
            kept.include?(id)
          end
          "image-meta #{edited}" if edited.positive?
        end

        # Names the scalar-core fields that moved: when, notes, location...
        def scalar_change(before, after)
          moved = SCALAR_FIELDS.reject do |field|
            before[:scalars][field] == after[:scalars][field]
          end
          "scalars(#{moved.join("/")})" if moved.any?
        end

        def count_change(label, before, after)
          added = (after - before).size
          removed = (before - after).size
          return nil if added.zero? && removed.zero?

          "#{label} +#{added}/-#{removed}"
        end
      end
    end
  end
end
