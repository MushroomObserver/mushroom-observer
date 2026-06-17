# frozen_string_literal: true

module Views::Controllers::Images::Exports
  # "Export" / "Don't export" toggle button for
  # `Images::ExportsController`. Wraps a PUT-button in
  # `<div id="image_export_<id>">` so the turbo-stream response
  # replaces the contents of that same target on each toggle.
  class Button < Views::Base
    prop :image, ::Image

    def view_template
      div(id: "image_export_#{@image.id}") do
        render(::Components::CrudButton::Put.new(
                 name: button_name,
                 target: export_image_path(id: @image.id, value: button_value)
               ))
      end
    end

    private

    def button_name
      @image.ok_for_export ? "Don't export" : "Export"
    end

    def button_value
      @image.ok_for_export ? 0 : 1
    end
  end
end
