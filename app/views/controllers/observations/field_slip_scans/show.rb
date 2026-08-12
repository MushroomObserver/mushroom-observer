# frozen_string_literal: true

# Every photo of the observation with its field-slip scan state: a
# scan button for unscanned photos (zbar found no code, so only the
# person can say which photo shows the slip), a link to the photo's
# review or status page once a scan exists.
module Views::Controllers::Observations::FieldSlipScans
  class Show < Views::FullPageBase
    prop :observation, ::Observation
    prop :user, ::User
    prop :extracts, _Hash(Integer, ::FieldSlipExtract)

    def view_template
      add_page_title(:field_slip_scan_title.t(id: @observation.id))

      Panel(panel_id: "field_slip_scan_photos") do |p|
        p.with_body do
          plain(:field_slip_scan_help.l)
          div(class: "d-flex flex-wrap mt-3") do
            @observation.images.each { |image| render_photo(image) }
          end
        end
      end
      render_observation_link
    end

    private

    def render_photo(image)
      div(class: "mr-4 mb-3 text-center") do
        InteractiveImage(image: image, user: @user, size: :small,
                         votes: false)
        div { render_photo_state(image) }
      end
    end

    def render_photo_state(image)
      extract = @extracts[image.id]
      if extract.nil?
        Button(type: :post, name: :field_slip_extract_button.l,
               target: image_field_slip_extract_path(image.id))
      else
        Link(type: :get, name: state_label(extract),
             target: edit_image_field_slip_extract_path(image.id))
      end
    end

    def state_label(extract)
      if extract.complete?
        :field_slip_scan_review.l
      elsif extract.failed?
        :field_slip_scan_failed.l
      else
        :field_slip_scan_reading.l
      end
    end

    def render_observation_link
      p do
        Link(type: :get, name: :field_slip_extract_observation_link.l,
             target: permanent_observation_path(@observation.id))
      end
    end
  end
end
