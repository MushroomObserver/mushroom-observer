# frozen_string_literal: true

# The review page's non-form states (see ExtractFieldSlipJob): a
# self-refreshing "reading..." panel while the job runs, the error
# with a retry button when the provider failed, and a not-scanned-yet
# panel with a scan button when no extract exists -- the landing spot
# for the no-slip-detected flash, and how a zbar-missed slip photo
# gets read at all. Once an extract completes, the reload (or the
# next visit) lands on the review form.
module Views::Controllers::Images::FieldSlipExtracts
  class Status < Views::FullPageBase
    prop :image, ::Image
    prop :extract, _Nilable(::FieldSlipExtract), default: nil
    prop :user, ::User

    def view_template
      add_page_title(:field_slip_extract_status_title.t)

      if @extract.nil?
        render_unscanned
      elsif @extract.failed?
        render_failed
      else
        render_pending
      end
      render_observation_link
    end

    private

    # No polling: nothing is running until the button is pressed.
    def render_unscanned
      render(Components::Panel.new(
               panel_id: "field_slip_extract_none"
             )) do |p|
        p.with_body do
          trusted_html(:field_slip_extract_none_yet.t)
        end
      end
      Button(type: :post, name: :field_slip_extract_button.l,
             target: image_field_slip_extract_path(@image.id))
    end

    def render_pending
      div(data: { controller: "reload-poll" }) do
        render(Components::Panel.new(
                 panel_id: "field_slip_extract_pending"
               )) do |p|
          p.with_body do
            span(class: "spinner-right mx-2")
            trusted_html(:field_slip_extract_pending.t)
          end
        end
      end
    end

    def render_failed
      Alert(level: :danger) do
        trusted_html(:field_slip_extract_failed.t(error: @extract.error.to_s))
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
