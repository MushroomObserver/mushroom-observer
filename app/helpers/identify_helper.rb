# frozen_string_literal: true

# buttons (forms) for observation identify UI
module IdentifyHelper
  # NOTE: There are potentially two of these toggles for the same obs, on
  # the obs_needing_ids index. Ideally, they'd be in sync. In reality, only
  # the matrix_box (page) checkbox will update if the (lightbox) caption
  # checkbox changes. Updating the lightbox checkbox to stay sync with the page
  # is harder because the caption is not created. Updating it would only work
  # with some additions to the lightbox JS, to keep track of the checked
  # state on show, and cost an extra db lookup. Not worth it, IMO.
  # - Nimmo 20230215
  # https://stackoverflow.com/questions/68624668/how-can-i-submit-a-form-on-input-change-with-turbo-streams
  def mark_as_reviewed_toggle(obs_id, selector = "caption_reviewed",
                              label_class = "", reviewed = nil)
    reviewed_text = reviewed ? :marked_as_reviewed.l : :mark_as_reviewed.l

    tag.div(class: "d-inline", id: "#{selector}_toggle_#{obs_id}") do
      form_with(url: observation_view_path(id: obs_id),
                class: "d-inline-block", method: :put,
                data: { turbo: true, controller: "reviewed-toggle" }) do |f|
        tag.div(class: "d-inline form-group form-inline") do
          f.label("#{selector}_#{obs_id}",
                  class: "caption-reviewed-link #{label_class}") do
            concat(reviewed_text)
            concat(
              f.check_box(
                :reviewed,
                { checked: reviewed, class: "mx-3", id: "#{selector}_#{obs_id}",
                  data: { reviewed_toggle_target: "toggle",
                          action: "reviewed-toggle#submitForm" } }
              )
            )
          end
        end
      end
    end
  end
end
