# frozen_string_literal: true

# Where the review page waits for a background extraction (see
# ExtractFieldSlipJob): a self-refreshing "reading..." panel while the
# job runs (or is about to -- the QR jobs may still be attaching the
# slip), and the error with a retry button when the provider failed.
# Once the extract completes, the reload lands on the review form.
module Views::Controllers::Images::FieldSlipExtracts
  class Status < Views::FullPageBase
    prop :image, ::Image
    prop :extract, _Nilable(::FieldSlipExtract), default: nil
    prop :user, ::User

    def view_template
      add_page_title(:field_slip_extract_status_title.t)

      if @extract&.failed?
        render_failed
      else
        render_pending
      end
      render_observation_link
    end

    private

    def render_pending
      div(data: { controller: "reload-poll" }) do
        Panel(panel_id: "field_slip_extract_pending") do |p|
          p.with_body do
            span(class: "spinner-right mx-2")
            plain(:field_slip_extract_pending.t)
          end
        end
      end
    end

    def render_failed
      Alert(level: :danger) do
        plain(:field_slip_extract_failed.t(error: @extract.error.to_s))
      end
      Button(type: :post, name: :field_slip_extract_retry.l,
             target: image_field_slip_extract_path(@image.id))
    end

    def render_observation_link
      observation = @image.observations.first
      return unless observation

      p do
        Link(type: :get, name: :field_slip_extract_observation_link.l,
             target: permanent_observation_path(observation.id))
      end
    end
  end
end
