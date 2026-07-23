# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Mixin providing image-upload form helpers.
  # Included by Components::ApplicationForm; requires the including class
  # to provide Superform's +namespace+, +field+, and +render+ methods.
  module UploadHelpers
    # Renders image upload fields in a :upload namespace.
    # Creates params[:model][:upload][image], etc. (nested under form model)
    # Pass a block to render content in the file field's between slot.
    def upload_fields(file_field_label: :image.ti, **args, &between_block)
      args => {
        copyright_holder:, copyright_year:, licenses:, upload_license_id:
      }

      namespace(:upload) do |upload|
        render_upload_image_field(upload, file_field_label, &between_block)
        render_upload_copyright_holder(upload, copyright_holder)
        render_upload_year(upload, copyright_year)
        render_upload_license(upload, licenses, upload_license_id)
      end
    end

    # Creates a namespace for image fields indexed by image ID.
    # Generates params like: observation[good_image][123][notes]
    # @param type [Symbol] :good_image or :image (for existing vs new uploads)
    # @param image_id [Integer, String] the image ID
    # @yield [namespace] the nested namespace for field building
    def image_namespace(type, image_id, &block)
      namespace(type) do |type_ns|
        type_ns.namespace(image_id.to_s, &block)
      end
    end

    private

    def render_upload_image_field(upload, label, &between_block)
      file_component = upload.field(:image).file(
        wrapper_options: { label: label }
      )
      file_component.with_between(&between_block) if between_block
      render(file_component)
    end

    def render_upload_copyright_holder(upload, holder)
      render(
        upload.field(:copyright_holder).text(
          wrapper_options: { label: :image_copyright_holder,
                             inline: true },
          value: holder
        )
      )
    end

    def render_upload_year(upload, year)
      render(
        upload.field(:copyright_year).select(
          upload_year_options,
          wrapper_options: { label: :when.ti, inline: true },
          selected: year
        )
      )
    end

    def render_upload_license(upload, licenses, selected_id)
      # `licenses` is Rails-shape `[[label, value], ...]` (from
      # `License.available_names_and_ids`); pass through.
      license_select = upload.field(:license_id).select(
        licenses,
        wrapper_options: { label: :license.ti, inline: true },
        selected: selected_id
      )

      license_select.with_append { render_copyright_warning }

      render(license_select)
    end

    def render_copyright_warning
      Help(content: ["(", :image_copyright_warning.t, ")"].safe_join)
    end

    def upload_year_options
      (1980..Time.zone.now.year).to_a.reverse.map { |y| [y.to_s, y] }
    end
  end
end
