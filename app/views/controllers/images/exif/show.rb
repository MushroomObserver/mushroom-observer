# frozen_string_literal: true

module Views::Controllers::Images
  module EXIF
    # EXIF data page for an image. Renders the EXIF data inside a
    # standalone `<div id="exif_data_table">` table (via
    # `Components::Table` body mode). Converted from
    # `images/exif/show.erb` + `images/exif/_data.erb`.
    class Show < Views::Base
      prop :image, ::Image
      prop :data, _Nilable(_Array(_Array(::String))), default: nil

      def view_template
        add_page_title(:exif_data_for_image.t(image: @image.id))
        add_context_nav(::Tab::Image::EXIFShow.new(image: @image))
        container_class(:text)

        render(DataTable.new(data: @data))
      end
    end
  end
end
