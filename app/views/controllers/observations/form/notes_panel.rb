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
      # The two keys `field_slip_note_fields` renders itself. Once an
      # observation stores either, `notes_orphaned_parts` also offers it
      # as a plain part, so the edit form rendered each twice -- and the
      # extra field, rendered second, won the submitted value. Since it
      # shows the unwrapped code while the plain part shows the stored
      # link, editing silently unwrapped a saved iNat link. See #4932.
      FIELD_SLIP_NOTE_KEYS = [:Field_Slip_ID_By, :Other_Codes].freeze

      private

      def render_notes_panel
        render(Components::Form::Notes.new(
                 form: self,
                 parts: observation_form_note_parts,
                 panel_id: "observation_notes",
                 expanded: notes_panel_expanded?,
                 single_part_mode: single_notes_part?,
                 above_help: above_notes_help,
                 extra_fields: field_slip_note_fields
               ))
      end

      # "Id by" and "Other Codes" — the two field-slip note fields that
      # aren't plain text. Id by is a user autocompleter (it resolves to a
      # user through project aliases on save) and Other Codes carries the
      # "this is an iNat id" checkbox that turns it into a link. Both live
      # in the notes area per #4932; the Scientific Name field already
      # covers what the slip form called "ID", so that one doesn't move.
      #
      # `instance_exec`'d by the Notes component inside its `:notes`
      # namespace, so `notes_ns` fields submit as
      # `observation[notes][<key>]` alongside the parts. The iNat checkbox
      # is not a note — it is a transform flag — so it goes through
      # `@form` as a top-level `inat` param, the same shape the slip form
      # uses.
      #
      # Values are read here and captured by the closure, exactly as the
      # ordinary parts pass `part.value`. Superform can't resolve them
      # from the model on its own — `notes` is a Hash, not an association
      # — and a field that renders empty submits empty, which
      # `notes_to_sym_and_compact` then drops. Editing an observation
      # would silently delete both values.
      #
      # An iNat-flagged code shows as the bare id with the box ticked,
      # rather than as the generated markup, so the pair round-trips.
      def field_slip_note_fields
        return nil if editable_field_code.blank?

        id_by = model.notes_part_value(:Field_Slip_ID_By)
        stored_codes = model.notes_part_value(:Other_Codes)
        codes = FieldSlipNotesBuilder.inat_code(stored_codes)
        inat = FieldSlipNotesBuilder.inat_link?(stored_codes)

        proc do |notes_ns|
          render(notes_ns.field(:Field_Slip_ID_By).autocompleter(
                   type: :user, wrapper_options: { label: :id_by },
                   value: id_by
                 ))
          render(notes_ns.field(:Other_Codes).text(
                   wrapper_options: { label: :field_slip_other_codes },
                   value: codes
                 ))
          @form.checkbox_field("inat", label: :field_slip_other_inat,
                                       checked: inat)
        end
      end

      # The plain notes parts (template + orphaned + Other keys not shared
      # with the occurrence), followed by one value-source part per notes
      # key ANY occurrence sibling holds (Occurrence#sibling_note_keys) --
      # every shared key gets the row, whether or not the values currently
      # differ, so the UI is consistent rather than depending on the
      # current/sibling values agreeing.
      def observation_form_note_parts
        shared = shared_note_keys
        plain_note_parts(shared) + occurrence_note_parts(shared)
      end

      # Empty unless a field code is in play, matching the guard on
      # `field_slip_note_fields` -- without a code those fields aren't
      # rendered, so their keys still need a plain part to be editable.
      def dedicated_note_keys
        return [] if editable_field_code.blank?

        FIELD_SLIP_NOTE_KEYS
      end

      # Notes keys shared with the occurrence's other members, or [] when
      # this isn't the primary of a multi-member occurrence.
      def shared_note_keys
        return [] unless model.shows_merged_notes?

        model.occurrence.sibling_note_keys
      end

      # Template / orphaned / Other parts whose keys aren't shared with
      # the occurrence -- rendered as ordinary textareas.
      def plain_note_parts(shared_keys)
        skip = shared_keys + dedicated_note_keys
        observation_notes_form_parts.filter_map do |part|
          key = model.notes_normalized_key(part)
          next if skip.include?(key)

          Components::Form::Notes::Part.new(
            key: key,
            value: model.notes_part_value(part),
            label: single_notes_part? ? :notes : part
          )
        end
      end

      # One value-source part per shared key: notes_state (:set/:hide/
      # :inherit) from what the primary stores, plus any distinct
      # differing sibling values as adopt options (empty when they agree).
      def occurrence_note_parts(shared_keys)
        adopt = shared_adopt_options
        inherited = shared_inherited_values
        shared_keys.map do |key|
          Components::Form::Notes::Part.new(
            key: key, value: model.notes[key].to_s,
            label: key.to_s.tr("_", " "),
            adopt_options: adopt[key] || [],
            notes_state: notes_state_for(key),
            inherited_value: inherited[key]
          )
        end
      end

      # Differing-sibling adopt options per key (empty for agreeing keys);
      # {} when not the primary of a multi-member occurrence.
      def shared_adopt_options
        return {} unless model.shows_merged_notes?

        model.occurrence.adopt_options_by_key
      end

      # The value each shared key inherits (most-recent sibling's) so the
      # form's :inherit state can show it greyed; {} when not the primary
      # of a multi-member occurrence.
      def shared_inherited_values
        return {} unless model.shows_merged_notes?

        model.occurrence.inherited_values_by_key
      end

      # What the primary currently shows for a shared key: a stored value
      # (:set), a stored blank that suppresses the inherited value
      # (:hide), or no stored key at all, so it inherits (:inherit).
      def notes_state_for(key)
        return :inherit unless model.notes.key?(key)

        model.notes[key].present? ? :set : :hide
      end

      def observation_notes_form_parts
        @observation_notes_form_parts ||=
          model.form_notes_parts(@user, extra: field_slip_note_headings)
      end

      # The field slip's standard headings, shown whenever a field code is
      # in play so slip data has somewhere to go on this form.
      #
      # Driven by the code rather than by what `notes` already holds:
      # `notes_to_sym_and_compact` drops blank values, so keying off
      # content would make every heading the user left empty disappear
      # from a validation-failure re-render.
      def field_slip_note_headings
        return [] if editable_field_code.blank?

        FieldSlip::NOTE_HEADINGS.map(&:to_s)
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
