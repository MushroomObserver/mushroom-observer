# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap file input field component with form-group wrapper and slots
  # Matches the markup and behavior of file_field_with_label helper
  class FileField < Superform::Rails::Components::Input
    include Phlex::Rails::Helpers::ClassNames
    include Phlex::Slotable

    slot :between
    slot :append

    attr_reader :wrapper_options

    def initialize(field, attributes:, wrapper_options: {})
      super(field, attributes: attributes)
      @wrapper_options = wrapper_options
    end

    def view_template
      render_with_wrapper do
        render_file_input_button
      end
    end

    private

    # rubocop:disable Metrics/AbcSize
    def render_with_wrapper
      label_option = wrapper_options[:label]
      show_label = label_option != false
      label_text = if label_option.is_a?(String)
                     label_option
                   else
                     field.key.to_s.humanize
                   end
      wrap_class = wrapper_options[:wrap_class]

      div(class: form_group_class("form-group", wrap_class),
          data: { controller: "file-input" }) do
        render_label_row(label_text) if show_label
        render(between_slot) if between_slot
        yield
        render_filename_display
        render(append_slot) if append_slot
      end
    end
    # rubocop:enable Metrics/AbcSize

    def render_label_row(label_text)
      label(for: field.dom.id, class: "mr-3") { label_text }
    end

    def render_file_input_button
      span(class: "file-field btn btn-default") do
        plain(:select_file.l)
        input(**file_input_attributes, type: "file")
      end
    end

    def render_filename_display
      span(data: { file_input_target: "name" }) do
        :no_file_selected.t
      end
    end

    def file_input_attributes
      max_size = MO.image_upload_max_size
      max_size_in_mb = (max_size.to_f / 1024 / 1024).round
      max_upload_msg = :validate_image_file_too_big.l(max: max_size_in_mb)

      attributes.merge(
        data: {
          action: "change->file-input#validate",
          file_input_target: "input",
          max_upload_size: max_size,
          max_upload_msg: max_upload_msg
        }
      )
    end

    def form_group_class(base, wrap_class)
      classes = base
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end
  end
end
