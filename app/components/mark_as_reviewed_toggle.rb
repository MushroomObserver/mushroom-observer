# frozen_string_literal: true

module Components
  # Component for rendering a toggle to mark observations as reviewed.
  #
  # https://stackoverflow.com/questions/68624668/how-can-i-submit-a-form-on-input-change-with-turbo-streams
  #
  # @example Default usage (lightbox caption)
  #   obs_view = observation_view_for(@obs, @user)
  #   MarkAsReviewedToggle(observation_view: obs_view)
  #
  # @example Matrix box usage
  #   MarkAsReviewedToggle(
  #     observation_view: obs_view,
  #     selector: "box_reviewed",
  #     label_class: "stretched-link"
  #   )
  #
  class MarkAsReviewedToggle < ApplicationForm
    def initialize(observation_view:, selector: "caption_reviewed",
                   label_class: "")
      @observation_view = observation_view
      @obs_id = observation_view.observation_id
      @selector = selector
      @label_class = label_class
      super(observation_view,
            id: "#{selector}_form_#{@obs_id}",
            method: :put,
            local: false,
            data: { controller: "reviewed-toggle" })
    end

    def view_template
      div(class: "d-inline form-group form-inline") do
        checkbox_field(:reviewed,
                       label: reviewed_text,
                       label_class: label_class_value,
                       label_position: :before,
                       wrap_class: "d-inline",
                       id: "#{@selector}_#{@obs_id}",
                       class: "mx-3",
                       data: checkbox_data)
      end
    end

    def around_template
      div(class: "d-inline", id: "#{@selector}_toggle_#{@obs_id}") do
        super
      end
    end

    protected

    def form_action
      observation_view_path(id: @obs_id)
    end

    private

    def reviewed_text
      @observation_view.reviewed ? :marked_as_reviewed.l : :mark_as_reviewed.l
    end

    def label_class_value
      ["caption-reviewed-link", @label_class].compact_blank.join(" ")
    end

    def checkbox_data
      { reviewed_toggle_target: "toggle",
        action: "reviewed-toggle#submitForm" }
    end
  end
end
