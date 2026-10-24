# frozen_string_literal: true

# Component for rendering a toggle to mark observations as reviewed.
#
# https://stackoverflow.com/questions/68624668/how-can-i-submit-a-form-on-input-change-with-turbo-streams
#
# @example Default usage (lightbox caption)
#   obs_view = observation_view_for(@obs, @user)
#   ObservationFragment(type: :mark_as_reviewed_toggle,
#                        observation_view: obs_view)
#
# @example Matrix box usage
#   ObservationFragment(type: :mark_as_reviewed_toggle,
#                        observation_view: obs_view,
#                        selector: "box_reviewed",
#                        label_class: "stretched-link")
#
class Components::ObservationFragment::MarkAsReviewedToggle <
      Components::ApplicationForm
  prop :selector, String, default: "caption_reviewed"
  prop :label_class, String, default: ""

  def initialize(observation_view:, selector: "caption_reviewed",
                 label_class: "")
    super(observation_view,
          selector: selector,
          label_class: label_class,
          id: "#{selector}_form_#{observation_view.observation_id}",
          method: :put,
          turbo: true,
          data: { reviewed_toggle_target: "form" })
  end

  def view_template
    div(class: "d-inline form-group form-inline") do
      checkbox_field(:reviewed,
                     label: reviewed_text,
                     label_class: label_class_value,
                     # d-inline breaks the custom-control's absolutely
                     # positioned input (needs a block-ish containing
                     # block).
                     wrap_class: "d-inline-block",
                     id: checkbox_id,
                     class: "mx-3",
                     data: checkbox_data)
    end
  end

  def around_template
    div(class: class_names("d-inline", stretched_link_class),
        data: outer_data,
        id: "#{@selector}_toggle_#{model.observation_id}") do
      super
    end
  end

  protected

  def form_action
    observation_view_path(id: model.observation_id)
  end

  private

  def reviewed_text
    model.reviewed ? :marked_as_reviewed.l : :mark_as_reviewed.l
  end

  # The "_lb" suffix keeps this id distinct from lightGallery's clone
  # of it in `.lg-sub-html` -- lightgallery_controller.js strips the
  # suffix off the clone, so each copy's id stays unique and the
  # label's native for= association keeps working for both.
  def checkbox_id
    "#{@selector}_#{model.observation_id}_lb"
  end

  def label_class_value
    classes = ["caption-reviewed-link", @label_class]
    classes.compact_blank.join(" ").split.reject { |c| c == "stretched-link" }.
      join(" ")
  end

  def stretched?
    @label_class.split.include?("stretched-link")
  end

  def stretched_link_class
    "stretched-link" if stretched?
  end

  def outer_data
    data = { controller: "reviewed-toggle" }
    data[:action] = "click->reviewed-toggle#toggleCheckbox" if stretched?
    data
  end

  def checkbox_data
    { reviewed_toggle_target: "toggle",
      action: "reviewed-toggle#submitForm" }
  end
end
