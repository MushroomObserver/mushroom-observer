# frozen_string_literal: true

module Views::Controllers::Observations
  class Form < ::Components::ApplicationForm
    # Private mixin: notes-section adapter for the observation form.
    # Converts the observation's raw notes parts (strings like
    # "Habitat" or `Observation.other_notes_part`) into the uniform
    # `Components::Form::Notes::Part` shape, and renders the shared
    # `FormNotes` component with the right panel/expanded/single-part
    # configuration.
    #
    # Extracted to keep the parent class under `Metrics/ClassLength`.
    # Field-slip's eventual Phlex form will have its own adapter
    # (its parts already have the right shape, so it won't need
    # this much glue).
    module NotesPanel
      private

      def render_notes_panel
        render(Components::Form::Notes.new(
                 form: self,
                 parts: observation_form_note_parts,
                 panel_id: "observation_notes",
                 expanded: notes_panel_expanded?,
                 single_part_mode: single_notes_part?,
                 above_help: above_notes_help
               ))
      end

      def observation_form_note_parts
        observation_notes_form_parts.map do |part|
          Components::Form::Notes::Part.new(
            key: model.notes_normalized_key(part),
            value: model.notes_part_value(part),
            label: single_notes_part? ? :NOTES : part
          )
        end
      end

      def observation_notes_form_parts
        @observation_notes_form_parts ||= model.form_notes_parts(@user)
      end

      def single_notes_part?
        observation_notes_form_parts == [Observation.other_notes_part]
      end

      def notes_panel_expanded?
        (create? && observation_notes_form_parts.length > 1) ||
          model.notes.present?
      end

      # Deferred Proc — `FormNotes` `instance_exec`s this in its own
      # render context so the `<p>` tag emits to the help-block buffer
      # at render time (an eager `tag.p(...)` returned here would be
      # built outside that buffer and require safe-joining). FormNotes
      # adds the textile-formatting help itself below the field, so
      # this only includes the prose "what to put in notes" copy.
      def observation_above_notes_help
        proc { p { :form_observations_notes_help.t } }
      end

      def above_notes_help
        single_notes_part? ? observation_above_notes_help : nil
      end
    end
  end
end
