# frozen_string_literal: true

# buttons (forms) for observation identify UI
module IdentifyHelper
  def propose_naming_link(id, btn_class: "btn-primary my-3", context: "",
                          text: :create_naming.t)
    render(partial: "observations/namings/propose_button",
           locals: {
             obs_id: id,
             text: text,
             btn_class: "#{btn_class} d-inline-block",
             context: context
           },
           layout: false)
  end

  # NOTE: There are potentially two of these toggles for the same obs, on
  # the obs_needing_ids index. Ideally, they'd be in sync. In reality, only
  # the matrix_box (page) checkbox will update if the (lightbox) caption
  # checkbox changes. Updating the lightbox checkbox to stay sync with the page
  # is harder because the caption is not created. Updating it would only work
  # with some additions to the lightbox JS, to keep track of the checked
  # state on show, and cost an extra db lookup. Not worth it, IMO.
  # - Nimmo 20230215
  def mark_as_reviewed_toggle(id, label_class = "",
                              selector = "caption_reviewed")
    render(partial: "observation_views/mark_as_reviewed",
           locals: { id: id, selector: selector, label_class: label_class },
           layout: false)
  end
end
