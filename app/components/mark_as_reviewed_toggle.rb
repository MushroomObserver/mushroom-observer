# frozen_string_literal: true

module Components
  # Component for rendering a toggle to mark observations as reviewed.
  #
  # NOTE: There are potentially two of these toggles for the same obs, on
  # the obs_needing_ids index. Ideally, they'd be in sync. In reality, only
  # the matrix_box (page) checkbox will update if the (lightbox) caption
  # checkbox changes. Updating the lightbox checkbox to stay in sync with
  # the page is harder because the caption is not created. Updating it would
  # only work with some additions to the lightbox JS, to keep track of the
  # checked state on show, and cost an extra db lookup. Not worth it, IMO.
  # - Nimmo 20230215
  #
  # https://stackoverflow.com/questions/68624668/how-can-i-submit-a-form-on-input-change-with-turbo-streams
  #
  # @example Default usage (lightbox caption)
  #   render(Components::MarkAsReviewedToggle.new(obs_id: @obs.id))
  #
  # @example Matrix box usage
  #   render(Components::MarkAsReviewedToggle.new(
  #     obs_id: @obs.id,
  #     selector: "box_reviewed",
  #     label_class: "stretched-link"
  #   ))
  #
  # @example With reviewed state
  #   render(Components::MarkAsReviewedToggle.new(
  #     obs_id: @obs.id,
  #     reviewed: true
  #   ))
  #
  class MarkAsReviewedToggle < Base
    include Phlex::Rails::Helpers::FormWith

    prop :obs_id, Integer
    prop :selector, String, default: -> { "caption_reviewed" }
    prop :label_class, String, default: -> { "" }
    prop :reviewed, _Nilable(_Boolean), default: -> {}

    def view_template
      div(class: "d-inline", id: "#{@selector}_toggle_#{@obs_id}") do
        render_form
      end
    end

    private

    def render_form
      form_with(
        url: observation_view_path(id: @obs_id),
        class: "d-inline-block",
        method: :put,
        data: { turbo: true, controller: "reviewed-toggle" }
      ) do |f|
        div(class: "d-inline form-group form-inline") do
          render_label(f)
        end
      end
    end

    def render_label(form)
      form.label(
        "#{@selector}_#{@obs_id}",
        class: "caption-reviewed-link #{@label_class}"
      ) do
        plain(reviewed_text)
        whitespace
        form.check_box(
          :reviewed,
          checked: @reviewed,
          class: "mx-3",
          id: "#{@selector}_#{@obs_id}",
          data: {
            reviewed_toggle_target: "toggle",
            action: "reviewed-toggle#submitForm"
          }
        )
      end
    end

    def reviewed_text
      @reviewed ? :marked_as_reviewed.l : :mark_as_reviewed.l
    end
  end
end
