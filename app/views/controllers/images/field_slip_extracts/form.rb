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
    # `approved_name` is set only on the confirmation round-trip: it is
    # the name the reviewer is being asked to create, and carrying it
    # back on the form action is what turns the resubmit into approval.
    def initialize(image:, extract:, review:, approved_name: nil, **attrs)
      @image = image
      @extract = extract
      @review = review
      @approved_name = approved_name
      super(review, **attrs)
    end

    def view_template
      super do
        hidden_field("_method", value: "patch")
        div(class: "table-responsive") { render_table }
        render_location_section
        render_name_section
        submit(:field_slip_extract_save.l)
      end
    end

    def form_action
      path = image_field_slip_extract_path(@image.id)
      return path if @approved_name.blank?

      "#{path}?#{{ approved_name: @approved_name }.to_query}"
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
    # correcting it is the whole point of the step.
    def render_extracted_cell(row)
      if row.editable
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
      if row.savable
        checkbox_field("use[#{row.field}]", checked: row.default_use?,
                                            label: false)
      else
        small { plain(:field_slip_extract_check_only.l) }
      end
    end

    # Locality, like the ID, is corrected through an autocompleter and
    # so needs a real label -- but unlike the ID it is an ordinary
    # attribute write, so it keeps its tick box. The box is prefilled
    # with the suggested full name when the project already uses a
    # location the abbreviation obviously means; the flag above says
    # what the slip actually read.
    def render_location_section
      row = @review.location_row
      return if row.nil? || row.blank?

      panel = Components::Panel.new(panel_id: "field_slip_extract_location")
      render(panel) do |p|
        p.with_body do
          autocompleter_field("value[#{row.field}]",
                              type: :location, value: @review.location_value,
                              label: :field_slip_extract_locality.l)
          render_current_note(row)
          checkbox_field("use[#{row.field}]",
                         checked: row.default_use?,
                         label: :field_slip_extract_apply.l)
        end
      end
    end

    def render_current_note(row)
      return if row.current.to_s.blank?

      div do
        small { plain(:field_slip_extract_currently.l(value: row.current)) }
      end
    end

    # The ID gets its own section rather than a table cell. Two reasons,
    # both load-bearing: a name autocompleter only renders its dropdown
    # and hidden id field when it has a real label (`label: false`
    # silently drops the append slot they live in), and unlike every
    # other field this one creates a Naming and a Vote rather than
    # writing an attribute.
    def render_name_section
      row = @review.name_row
      return if row.nil? || row.blank?

      # `with_body`, not a bare block: Panel is slot-based, and content
      # passed straight to it is discarded rather than rendered.
      render(Components::Panel.new(panel_id: "field_slip_extract_name")) do |p|
        p.with_body do
          render_name_field(row)
          render_name_use(row)
          render_vote_field
          Help(content: :field_slip_extract_id_help.l)
        end
      end
    end

    def render_name_field(row)
      autocompleter_field("value[#{row.field}]",
                          type: :name, value: row.extracted,
                          label: :field_slip_extract_id.l)
    end

    # Ticked by default only when the ID already resolves to a name MO
    # holds. An unrecognized one -- "Lumpy Bracket" -- starts clear, so
    # creating a Name is always something the reviewer chose to do.
    def render_name_use(row)
      checkbox_field("use[#{row.field}]", checked: @review.name_known,
                                          label: :field_slip_extract_propose.l)
    end

    # Defaults to the weakest positive value: relaying what a slip says
    # is not asserting the reviewer's own determination.
    def render_vote_field
      select_field("vote", Vote.confidence_menu,
                   label: :field_slip_extract_vote.l,
                   value: Vote::MIN_POS_VOTE)
    end
  end
end
