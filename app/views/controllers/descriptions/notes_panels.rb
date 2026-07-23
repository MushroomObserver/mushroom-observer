# frozen_string_literal: true

# Middle section of every name / location description show page: one
# `Components::Panel` per non-empty notes field (general description,
# diagnostic features, distribution, look-alikes, …) plus a
# fallback "no notes yet" message when all notes are empty.
module Views::Controllers::Descriptions
  class NotesPanels < Views::Base
    prop :description, ::Description

    def view_template
      Textile.register_name(@description.name) if parent_type == :name

      any_notes = false
      field_values.each do |field, value|
        any_notes = true
        render_panel(field, value)
      end

      trusted_html(:show_description_empty.tpl) unless any_notes
    end

    private

    def parent_type
      @description.parent.type_tag
    end

    def model_class
      @description.type_tag.to_s.camelize.constantize
    end

    # Yields `[field, value]` pairs for every non-blank notes field.
    def field_values
      model_class.all_note_fields.filter_map do |field|
        value = @description.send(field).to_s
        next unless value.match?(/\S/)

        [field, value]
      end
    end

    def render_panel(field, value)
      Panel do |panel|
        panel.with_heading { :"form_#{parent_type}s_#{field}".l }
        panel.with_body { trusted_html(value.tpl) }
      end
    end
  end
end
