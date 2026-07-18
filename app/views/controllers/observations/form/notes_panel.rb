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

      # The plain notes parts (template + orphaned + Other keys that
      # aren't shared with the occurrence), followed by one three-state
      # part per notes key the primary shares with its occurrence
      # siblings (Occurrence#adopt_options_by_key).
      def observation_form_note_parts
        adopt = observation_adopt_options
        plain_note_parts(adopt.keys) + occurrence_note_parts(adopt)
      end

      # Adopt options per notes key for the primary of a multi-member
      # occurrence (Occurrence#adopt_options_by_key); {} otherwise.
      def observation_adopt_options
        return {} unless model.shows_merged_notes?

        model.occurrence.adopt_options_by_key
      end

      # Template / orphaned / Other parts whose keys aren't shared with
      # the occurrence -- rendered as ordinary textareas.
      def plain_note_parts(occurrence_keys)
        observation_notes_form_parts.filter_map do |part|
          key = model.notes_normalized_key(part)
          next if occurrence_keys.include?(key)

          Components::Form::Notes::Part.new(
            key: key,
            value: model.notes_part_value(part),
            label: single_notes_part? ? :NOTES : part
          )
        end
      end

      # One three-state part per occurrence-shared key, its notes_state
      # (:set / :hide / :inherit) read from what the primary actually
      # stores for the key.
      def occurrence_note_parts(adopt)
        adopt.map do |key, options|
          Components::Form::Notes::Part.new(
            key: key, value: model.notes[key].to_s,
            label: key.to_s.tr("_", " "),
            adopt_options: options, notes_state: notes_state_for(key)
          )
        end
      end

      # What the primary currently shows for a shared key: a stored value
      # (:set), a stored blank that suppresses the inherited value
      # (:hide), or no stored key at all, so it inherits (:inherit).
      def notes_state_for(key)
        return :inherit unless model.notes.key?(key)

        model.notes[key].present? ? :set : :hide
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
