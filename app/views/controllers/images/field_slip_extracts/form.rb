# frozen_string_literal: true

# Review form for a machine-read field slip: one row per field the
# model read, showing what it read next to what the observation already
# holds, with a tick box deciding whether to apply it.
#
# Rows default to ticked only where there is nothing to lose -- a field
# the observation has no value for. Where the two disagree the box
# starts clear, so applying the whole form can never silently overwrite
# something a person entered; the reviewer has to say so.
module Views::Controllers::Images::FieldSlipExtracts
  class Form < ::Components::ApplicationForm
    # Superform wants the form's data object as the first positional
    # arg; the review IS that object, so it goes to `super` rather than
    # being held as a plain prop.
    def initialize(image:, extract:, review:, **attrs)
      @image = image
      @extract = extract
      @review = review
      super(review, **attrs)
    end

    def view_template
      super do
        hidden_field("_method", value: "patch")
        div(class: "table-responsive") { render_table }
        render_id_note
        submit(:field_slip_extract_save.l)
      end
    end

    def form_action
      image_field_slip_extract_path(@image.id)
    end

    private

    def render_table
      render(Components::Table.new(@review.rows_to_show)) do |t|
        t.column(:field_slip_extract_field.l)
        t.column(:field_slip_extract_read.l)
        t.column(:field_slip_extract_current.l)
        t.column(:field_slip_extract_use.l)
        t.row { |row| render_row(row) }
      end
    end

    def render_row(row)
      tr do
        td { plain(row.field) }
        td { render_extracted_cell(row) }
        td { render_current_cell(row) }
        td { render_use_cell(row) }
      end
    end

    # Editable: the model's reading is a starting point, and a reviewer
    # correcting a misread here is the whole point of the step.
    def render_extracted_cell(row)
      if row.savable
        text_field("value[#{row.field}]", value: row.extracted, label: false)
      else
        plain(row.extracted.to_s)
      end
      render_confidence(row)
    end

    def render_confidence(row)
      return if row.confidence == "high"

      div do
        small do
          plain(:field_slip_extract_confidence.l(level: row.confidence))
        end
      end
    end

    def render_current_cell(row)
      current = row.current.to_s
      if current.blank?
        small { plain(:field_slip_extract_empty.l) }
      else
        plain(current)
      end
    end

    def render_use_cell(row)
      unless row.savable
        small { plain(:field_slip_extract_review_only.l) }
        return
      end

      checkbox_field("use[#{row.field}]", checked: row.default_use?,
                                          label: false)
    end

    # The ID is shown but never written here: proposing a name creates a
    # naming and a vote, which is a different act with its own rules.
    def render_id_note
      return if @extract.value_for("ID").blank?

      Help(content: :field_slip_extract_id_help.l)
    end
  end
end
