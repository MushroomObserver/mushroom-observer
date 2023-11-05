# frozen_string_literal: true

# buttons (forms) for observation identify UI
module IdentifyHelper
  def propose_naming_link(id, btn_class: "btn-primary my-3",
                          context: "namings_table",
                          text: :create_naming.t)
    modal_link_to(
      "naming", text,
      new_observation_naming_path(
        observation_id: id, q: get_query_param, context: context
      ),
      { class: "btn #{btn_class} d-inline-block propose-naming-button",
        # remote: true, onclick: "MOEvents.whirly();",
        id: "propose_naming_button_#{id}" }
    )
  end

  # NOTE: There are potentially two of these toggles for the same obs, on
  # the obs_needing_ids index. Ideally, they'd be in sync. In reality, only
  # the matrix_box (page) checkbox will update if the (lightbox) caption
  # checkbox changes. Updating the lightbox checkbox to stay sync with the page
  # is harder because the caption is not created. Updating it would only work
  # with some additions to the lightbox JS, to keep track of the checked
  # state on show, and cost an extra db lookup. Not worth it, IMO.
  # - Nimmo 20230215
  def mark_as_reviewed_toggle(id, selector = "caption_reviewed",
                              label_class = "", reviewed = 0)
    turbo_frame_tag("#{selector}_toggle_#{id}") do
      form_with(url: observation_view_path(id: id),
                class: "d-inline-block", method: :put,
                data: { turbo: true }) do |f|
        tag.div(class: "d-inline form-group form-inline") do
          f.label("#{selector}_#{id}",
                  class: "caption-reviewed-link #{label_class}") do
            concat(reviewed ? :marked_as_reviewed.t : :mark_as_reviewed.t)
            concat(
              f.check_box(
                :reviewed,
                { checked: "1", class: "mx-3", id: "#{selector}_#{id}",
                  onchange: "Rails.fire(this.closest('form'), 'submit')" }
              )
            )
          end
        end
      end
    end
  end
end
