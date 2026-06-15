# frozen_string_literal: true

module Views::Controllers::Images
  # Admin/test page for measuring image upload performance. Posts to
  # `test_upload_image`. Images uploaded through this page are not
  # saved and no database changes are made. Driven by
  # `script/perf_monitor`. Converted from
  # `images/test_add_image.html.erb`.
  class TestAddImage < Views::Base
    include ::Phlex::Rails::Helpers::FormAuthenticityToken

    # `@log_entry` is the most recent upload-log row when present;
    # the model lives outside MO core and is duck-typed here
    # (responds to `id` + `created_at`).
    prop :log_entry, _Nilable(::Object), default: nil

    def view_template
      add_page_title("Test Upload Speed")

      p do
        plain("This page is strictly for testing image upload " \
              "performance.  Images uploaded through this page " \
              "are not saved and no database changes are made.")
      end

      render_last_log_summary if @log_entry
      render_form
    end

    private

    def render_last_log_summary
      p do
        plain("Test #{@log_entry.id} created: " \
              "#{@log_entry.created_at.web_time}")
      end
    end

    def render_form
      form(action: form_action, method: "post",
           enctype: "multipart/form-data") do
        input(type: "hidden", name: "authenticity_token",
              value: form_authenticity_token)
        div(class: "form-group form-inline") do
          (1..4).each { |i| render_image_field(i) }
        end
        input(type: "submit", name: "commit", value: :UPLOAD.l,
              class: "btn btn-default center-block mt-3")
      end
    end

    def form_action
      args = { action: :test_upload_image }
      args[:log_id] = @log_entry.id if @log_entry
      url_for(args)
    end

    # Hand-rolled Bootstrap-wrapped file input that matches the
    # markup `forms_helper#file_field_with_label` emits for the ERB
    # version of this page — `data-controller="file-input"` for
    # client-side size validation, the "Select file" / "No file
    # selected" UI spans, and the `accept="image/*"` constraint. We
    # don't go through `Components::ApplicationForm::FileField`
    # because this admin form posts raw `upload[image1]`-style params
    # (not Superform-nested under a FormObject), and we don't go
    # through the ERB helper because Phlex views shouldn't dispatch
    # into ActionView (`view_context.foo` / `helpers.foo` —
    # banned by `no_helpers_in_phlex_views_test`).
    def render_image_field(index)
      field_name = "image#{index}"
      input_id = "upload_#{field_name}"

      div(class: "form-group mt-3",
          data: { controller: "file-input" }) do
        label(for: input_id, class: "mr-3") do
          plain("#{:image_add_image.t} #{index}:")
        end
        span(class: "file-field btn btn-default") do
          plain(:select_file.t)
          input(type: "file", id: input_id,
                name: "upload[#{field_name}]",
                accept: "image/*", **file_input_validation_data)
        end
        span(data: { file_input_target: "name" }) do
          plain(:no_file_selected.t)
        end
      end
    end

    def file_input_validation_data
      max_size = ::MO.image_upload_max_size
      max_mb = (max_size.to_f / 1024 / 1024).round
      {
        data: {
          action: "change->file-input#validate",
          file_input_target: "input",
          max_upload_size: max_size,
          max_upload_msg: :validate_image_file_too_big.l(max: max_mb)
        }
      }
    end
  end
end
