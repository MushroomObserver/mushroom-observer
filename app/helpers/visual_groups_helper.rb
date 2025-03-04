# frozen_string_literal: true

# helpers which create html for visual groups
module VisualGroupsHelper
  def visual_group_status_links(visual_group:, image_id:, status:)
    tag.div(
      class: "status_buttons text-center small",
      id: "visual_group_status_links_#{image_id}"
    ) do
      [
        [nil, true, false].map do |link|
          visual_group_status_link(visual_group, image_id, status, link)
        end.safe_join("|"),
        [
          "#{:image_reuse_id.t}:",
          link_to(image_id, image_path(id: image_id))
        ].safe_join(" "),
        tag.span("", class: "hidden data_container", data: { id: image_id })
      ].safe_join(safe_br)
    end
  end

  def visual_group_status_link(visual_group, image_id, state, link)
    link_text = visual_group_status_text(link)
    state_text = visual_group_status_text(state)
    return tag.b(link_text) if link_text == state_text

    patch_button(name: link_text,
                 path: visual_group_image_path(
                   id: image_id, visual_group_id: visual_group.id, status: link
                 ),
                 title: link_text,
                 data: { turbo: true })
  end

  # Determine the right string for visual group status from booleans
  # indicating if the image needs review (no VisualGroupImage exists),
  # is marked as included or not.
  def visual_group_status_text(status)
    return :visual_group_needs_review.t if status.nil?
    return :visual_group_include.t if status && (status != 0)

    :visual_group_exclude.t
  end
end
