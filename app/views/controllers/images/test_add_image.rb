# frozen_string_literal: true

module Views::Controllers::Images
  # Admin/test page for measuring image upload performance. Posts to
  # `test_upload_image`. Images uploaded through this page are not
  # saved and no database changes are made. Driven by
  # `script/perf_monitor`. Converted from
  # `images/test_add_image.html.erb`.
  class TestAddImage < Views::Base
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
      form_with(url: { action: :test_upload_image,
                       log_id: @log_entry&.id },
                multipart: true) do |form|
        div(class: "form-group form-inline") do
          form.fields_for(:upload) do |upload_form|
            (1..4).each { |i| render_image_field(upload_form, i) }
          end
        end
        form.submit(:UPLOAD.l, class: "btn btn-default center-block mt-3")
      end
    end

    def render_image_field(upload_form, index)
      upload_form.file_field("image#{index}",
                             class: "mt-3",
                             label: "#{:image_add_image.t} #{index}:")
    end
  end
end
