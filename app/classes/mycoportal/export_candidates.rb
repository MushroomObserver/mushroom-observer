# frozen_string_literal: true

module Mycoportal
  # Decides which Observations belong in a MyCoPortal (MCP) export batch,
  # independent of any admin-picked Query. Report::Mycoportal and
  # Report::MycoportalImageList handle CSV formatting; this class only
  # computes the candidate observation ids.
  #
  # Every filter here is a set-based ActiveRecord/Arel condition (join +
  # where), not a per-observation Ruby loop, so the whole computation runs
  # as a handful of indexed SQL queries regardless of table size. The one
  # exception -- kingdom filtering -- necessarily runs Name#kingdom parsing
  # in Ruby, but only once per *distinct* consensus Name among candidates,
  # not once per Observation.
  class ExportCandidates
    # Observations already exported to MCP whose consensus/content has
    # changed since the last export -- these need to be re-sent.
    def updated_observation_ids
      exported_observations.
        where(Observation[:updated_at].gt(ExternalLink[:last_synced_at])).
        distinct.pluck(:id)
    end

    # Observations never exported to MCP that are good enough to send.
    def new_observation_ids
      not_yet_exported.
        where(Observation.confidence_lower_bound(
                MO.mycoportal_min_observation_vote
              )).
        where.not(name_id: excluded_name_ids).
        where.not(name_id: non_fungal_name_ids).
        where.not(id: empty_observation_ids).
        distinct.pluck(:id)
    end

    private

    def exported_observations
      Observation.joins(:external_links).
        where(external_links: {
                external_site_id: ExternalSite.mycoportal.id,
                relationship: ExternalLink.relationships[:export]
              })
    end

    def not_yet_exported
      Observation.where.not(id: exported_observations.select(:id))
    end

    # Consensus name text_name matches one of the placeholder/junk names
    # (Duplicate, Undetermined, Mixed collection, etc.) that never belong
    # in MCP.
    def excluded_name_ids
      Name.where(text_name: MO.mycoportal_excluded_names).select(:id)
    end

    # Consensus name's kingdom isn't Fungi/Protozoa. Bounded by the number
    # of *distinct* consensus names among not-yet-exported observations,
    # not by the observation count.
    def non_fungal_name_ids
      candidate_name_ids = not_yet_exported.distinct.pluck(:name_id).compact
      Name.where(id: candidate_name_ids).
        select(&:non_fungal_kingdom?).map(&:id)
    end

    # No proposed name (or only proposal is Fungi), unknown location, no
    # notes, no sequences, no images -- nothing worth sending.
    def empty_observation_ids
      Observation.has_name(false).
        where(location_id: unknown_location_ids).
        has_notes(false).
        has_sequences(false).
        has_images(false).
        pluck(:id)
    end

    def unknown_location_ids
      [nil, Location.unknown&.id].compact
    end
  end
end
