# frozen_string_literal: true

class FieldSlip
  module Extractor
    # What the prompt needs to know about the observation an image
    # belongs to: which project's aliases apply, what the event's dates
    # were, and which slip code is already attached (so the model's
    # reading of the printed code can be checked against it).
    #
    # An image can hang off several observations and an observation can
    # be in several projects; both are rare, and taking the first is
    # enough to build a prompt -- the reviewer sees every value before
    # anything is saved.
    class Context
      def self.for_image(image)
        new(observation: image.observations.first)
      end

      attr_reader :observation

      def initialize(observation:)
        @observation = observation
      end

      # The attached slip's project is authoritative: an observation
      # can sit in several projects (the obs form pre-checks the last
      # one used), and picking `projects.first` read the wrong event's
      # aliases and template for a slip that says exactly which project
      # it belongs to.
      def project
        @project ||= observation&.field_slip&.project ||
                     observation&.projects&.first
      end

      # Which printed layout this project's slips use.
      def template
        @template ||= FieldSlip::Template.for_project(project)
      end

      def field_slip_code
        observation&.field_slip&.code
      end

      # [name, target-name] pairs for the project's aliases of one type,
      # newest first so a corrected alias outranks a stale one when the
      # list is truncated.
      def aliases(target_type)
        return [] unless project

        ProjectAlias.where(project: project, target_type: target_type).
          includes(:target).order(updated_at: :desc).
          filter_map { |a| [a.name, alias_target_name(a)] if a.target }
      end

      def date_range
        return nil unless project&.start_date && project.end_date

        [project.start_date.to_s, project.end_date.to_s]
      end

      private

      def alias_target_name(project_alias)
        target = project_alias.target
        case target
        when Location then target.name
        when User then target.legal_name.presence || target.login
        else target.to_s
        end
      end
    end
  end
end
