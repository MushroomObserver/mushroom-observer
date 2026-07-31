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
      # `chosen` is {slip field => edited value} for the ticked fields.
      def initialize(observation:, chosen:, user:)
        @observation = observation
        @chosen = chosen
        @user = user
      end

      def apply
        assign_columns
        assign_notes
        @observation.save!
        @observation
      end

      private

      def targets
        @targets ||= @chosen.filter_map do |field, value|
          target = Extractor::FIELDS[field]
          [target, value.to_s.strip] if target && value.present?
        end
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

          [target.to_s.delete_prefix("notes.").to_sym, value]
        end.to_h
        return if patch.empty?

        @observation.notes = @observation.notes.to_h.merge(patch)
      end

      def assign_collector(value)
        attrs = Observation.collector_attrs(resolved_user(value) || value)
        @observation.collector = attrs[:collector]
        @observation.collector_user_id = attrs[:collector_user_id]
      end

      def assign_when(value)
        parsed = Date.parse(value)
        @observation.when = parsed
      rescue Date::Error
        nil # a date the reviewer left unparseable is skipped, not fatal
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
