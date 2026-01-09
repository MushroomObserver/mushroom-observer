# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap file input field component with form-group wrapper and slots
  # Matches the markup and behavior of file_field_with_label helper
  #
  # Supports two modes:
  # 1. Default (file-input controller): Single file with validation
  # 2. Custom controller: For multi-file uploads (e.g., form-images)
  #
  # @example Default usage (single file with validation)
  #   form.file_field(:image)
  #
  # @example Multi-file with custom controller
  #   form.file_field(:images,
  #     multiple: true,
  #     controller: "form-images",
  #     action: "change->form-images#addSelectedFiles")
  #
  class FileField < Superform::Rails::Components::Input
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

    def render_with_wrapper
      div(class: wrapper_class, data: wrapper_data) do
        render_label_row if show_label?
        render(between_slot) if between_slot
        yield
        render_filename_display unless custom_controller?
        render(append_slot) if append_slot
      end
    end

    def wrapper_class
      base = "form-group"
      wrap_class = wrapper_options[:wrap_class]
      wrap_class.present? ? "#{base} #{wrap_class}" : base
    end

    def wrapper_data
      return {} if custom_controller?

      { controller: "file-input" }
    end

    def show_label?
      wrapper_options[:label] != false
    end

    def label_text
      label_option = wrapper_options[:label]
      label_option.is_a?(String) ? label_option : field.key.to_s.humanize
    end

    def render_label_row
      label(for: field.dom.id, class: "mr-3") { label_text }
    end

    def render_file_input_button
      span(class: "file-field btn btn-default") do
        plain(button_text)
        input(**file_input_attributes, type: "file")
      end
    end

    def button_text
      wrapper_options[:button_text] || :select_file.l
    end

    def render_filename_display
      span(data: { file_input_target: "name" }) do
        :no_file_selected.t
      end
    end

    def file_input_attributes
      base_attrs = {
        accept: attributes[:accept] || "image/*",
        multiple: attributes[:multiple]
      }.compact

      base_attrs.
        merge(attributes.except(:accept, :multiple, :controller,
                                :action, :data)).
        merge(data: file_input_data)
    end

    def file_input_data
      custom_controller? ? custom_data_attributes : default_data_attributes
    end

    def custom_controller?
      attributes[:controller].present?
    end

    def custom_data_attributes
      { action: attributes[:action] }.merge(attributes[:data] || {})
    end

    def default_data_attributes
      max_size = MO.image_upload_max_size
      max_size_in_mb = (max_size.to_f / 1024 / 1024).round
      max_upload_msg = :validate_image_file_too_big.l(max: max_size_in_mb)

      {
        action: "change->file-input#validate",
        file_input_target: "input",
        max_upload_size: max_size,
        max_upload_msg: max_upload_msg
      }.merge(attributes[:data] || {})
    end
  end
end
