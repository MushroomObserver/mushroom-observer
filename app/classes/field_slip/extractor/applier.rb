# frozen_string_literal: true

class FieldSlip
  module Extractor
    # Writes a reviewed extract onto its observation.
    #
    # Only the fields the reviewer ticked are applied, and the values
    # applied are the ones they left in the form, not the ones the model
    # produced -- the extract is a starting point, the form is the
    # decision. The ID is deliberately not written as an attribute: it
    # becomes a proposed naming, which is a different act with its own
    # name-creation and voting rules, so it is left to the caller.
    class Applier
      ID_BY_KEY = :Field_Slip_ID_By
      COORD_TARGETS = [:lat, :lng].freeze

      # `chosen` is {slip field => edited value} for the ticked fields.
      # `template` maps each field to its Observation target.
      # `inat_code` says whether the template's iNat-codes field holds
      # an iNaturalist observation id, which is stored as a link rather
      # than as the bare number.
      def initialize(observation:, chosen:, user:, template:,
                     inat_code: false)
        @observation = observation
        @chosen = chosen
        @user = user
        @template = template
        @inat_code = inat_code
      end

      def apply
        assign_columns
        assign_notes
        enforce_coordinate_pair
        @observation.save!
        @observation
      end

      private

      def targets
        @targets ||= @chosen.filter_map do |field, value|
          target = @template.fields[field]
          [target, value_for(field, value)] if target && value.present?
        end
      end

      # An iNat id is stored as the link the field slip form writes, so
      # an observation reads back the same whichever route entered it.
      # Already-linked values pass through rather than nesting.
      # CRLF from a textarea submit normalizes to bare newlines, so a
      # multi-line Notes value stores the same shape however it arrived.
      def value_for(field, value)
        text = value.to_s.gsub("\r\n", "\n").strip
        return text unless field == @template.inat_codes_field
        return text unless @inat_code
        return text if FieldSlipNotesBuilder.inat_link?(text)

        inat_link_for(text)
      end

      # The box may hold more than the id ("10:29 388879492" -- a
      # timestamp doubling as a checksum against the iNat record). The
      # id becomes the link; the rest is kept beside it rather than
      # dropped. Removing the id uses the span as written, which can
      # differ from the id itself ("388 596 423").
      def inat_link_for(text)
        code = @template.inat_code_in(text)
        return text unless code

        link = FieldSlipNotesBuilder.inat_link(code)
        rest = leftover_around_code(text, @template.inat_code_raw(text))
        rest.present? ? "#{link} (#{rest})" : link
      end

      def leftover_around_code(text, raw_span)
        text.sub(raw_span.to_s, " ").squish.
          sub(/\A[#:\-\s]+/, "").sub(/[#:\-\s]+\z/, "")
      end

      def assign_columns
        targets.each do |target, value|
          next if target.to_s.start_with?("notes.")

          send(:"assign_#{target}", value)
        end
      end

      def assign_notes
        patch = targets.filter_map do |target, value|
          next unless target.to_s.start_with?("notes.")

          key = target.to_s.delete_prefix("notes.").to_sym
          [key, note_value(key, value)]
        end.to_h
        return if patch.empty?

        @observation.notes = @observation.notes.to_h.merge(patch)
      end

      # "Id by" names a person, and MO stores that as a textile user
      # link rather than as bare text -- the same shape
      # `ObservationsController::ProjectAliases#resolve_id_by_note`
      # writes, so an observation reads back the same whichever route
      # entered it. Unmatched text is kept verbatim: whoever identified
      # a collection is not always an MO user.
      def note_value(key, value)
        return value unless key == ID_BY_KEY

        user = resolved_user(value) || User.lookup_unique_text_name(value)
        user.is_a?(User) ? user.textile_name : value
      end

      def assign_collector(value)
        attrs = Observation.collector_attrs(resolved_user(value) || value)
        @observation.collector = attrs[:collector]
        @observation.collector_user_id = attrs[:collector_user_id]
      end

      # ISO only, deliberately. `Date.parse` is far too permissive to
      # trust here -- it reads "sometime in July" as July 1st of the
      # current year and raises nothing, so a garbage value would
      # silently set a wrong date rather than being skipped. The prompt
      # asks for YYYY-MM-DD and the field is prefilled with it, so
      # anything else is a typo and gets left alone.
      def assign_when(value)
        @observation.when = Date.strptime(value, "%Y-%m-%d")
      rescue Date::Error
        nil
      end

      # Parsed the way the observation form does, so "39°07'N" works;
      # a value that doesn't parse is skipped rather than saved (same
      # reasoning as `assign_when`).
      def assign_lat(value)
        parsed = Location.parse_latitude(value)
        return unless parsed

        @observation.lat = parsed
        applied_coords << :lat
      end

      def assign_lng(value)
        parsed = Location.parse_longitude(value)
        return unless parsed

        @observation.lng = parsed
        applied_coords << :lng
      end

      def applied_coords
        @applied_coords ||= []
      end

      # Coordinates land as a pair or not at all: half a pair would
      # fail Observation's own validation when the observation had
      # none, and would silently mix a slip coordinate with one from
      # another source when it did. Unless both were chosen and both
      # parsed, whatever was assigned reverts -- the other fields
      # still save.
      def enforce_coordinate_pair
        chosen = targets.count { |target, _| COORD_TARGETS.include?(target) }
        return if chosen.zero?
        return if chosen == 2 && applied_coords.size == 2

        @observation.restore_attributes(COORD_TARGETS)
      end

      # A location the project aliases (or MO itself) know becomes a real
      # Location; anything else is stored as free text, exactly as the
      # observation form does with a place name it can't resolve.
      def assign_place_name(value)
        location = alias_location(value) || Location.find_by(name: value)
        if location
          @observation.location = location
          @observation.where = location.name
        else
          @observation.location = nil
          @observation.where = value
        end
      end

      def alias_location(value)
        project_alias(value, "Location")&.target
      end

      def resolved_user(value)
        project_alias(value, "User")&.target
      end

      def project_alias(value, target_type)
        ids = @observation.project_ids
        return nil if ids.empty?

        ProjectAlias.where(project_id: ids, name: value.to_s.strip,
                           target_type: target_type).
          includes(:target).order(updated_at: :desc).first
      end
    end
  end
end
