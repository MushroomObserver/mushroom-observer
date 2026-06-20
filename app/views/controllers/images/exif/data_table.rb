# frozen_string_literal: true

module Views::Controllers::Images
  module EXIF
    # EXIF key/value table chunk. Wraps the rows in
    # `<div id="exif_data_table">` so the standalone `EXIF::Show`
    # page and the controller's turbo_stream modal-body branch can
    # share the same rendering.
    class DataTable < Views::Base
      prop :data, _Nilable(_Array(_Array(::String))), default: nil

      def view_template
        div(id: "exif_data_table") do
          render(::Components::Table.new(@data, class: "table-striped mb-0",
                                                show_headers: false)) do |t|
            t.column("key") { |row| row.first.to_s }
            t.column("value") { |row| row.last.to_s }
          end
        end
      end
    end
  end
end
