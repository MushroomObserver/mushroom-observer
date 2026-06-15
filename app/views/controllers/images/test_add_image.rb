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

    # Reuses `Components::ApplicationForm::FileField` via
    # `FieldProxy`, the established standalone-mode entry point for
    # form components outside a Superform parent (same pattern as
    # the herbaria curator-add field). The proxy's `namespace:` →
    # `key:` form yields the `upload[image1]`-style param name
    # `fields_for(:upload)` would have produced.
    def render_image_field(index)
      field = ::Components::ApplicationForm::FieldProxy.new(
        "upload", :"image#{index}"
      )
      render(::Components::ApplicationForm::FileField.new(
               field,
               wrapper_options: {
                 label: "#{:image_add_image.t} #{index}:",
                 wrap_class: "mt-3"
               }
             ))
    end
  end
end
