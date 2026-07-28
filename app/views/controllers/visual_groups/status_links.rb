# frozen_string_literal: true

# Per-image status-buttons block for the visual-group image matrix
# (`needs review | include | exclude` trio + image id link). Extracted
# as its own Phlex view so the matrix grid AND the turbo-stream
# response from `visual_groups/images#update` (the click on one of
# the status links re-renders just that image's block) can both
# render it.
module Views::Controllers::VisualGroups
  class StatusLinks < Views::Base
    prop :visual_group, VisualGroup
    prop :image_id, Integer
    # Booleans only — `nil` means no VisualGroupImage exists (needs
    # review), `true` means included, `false` means excluded.
    prop :status, _Nilable(_Boolean), default: nil

    def view_template
      div(class: "status_buttons text-center small",
          id: "visual_group_status_links_#{@image_id}") do
        render_status_link_trio
        br
        render_image_id_line
        br
        # The `data_container` hidden span lets older inherited
        # image-matrix JS read the image id off the DOM.
        span(class: "hidden data_container", data: { id: @image_id })
      end
    end

    private

    def render_status_link_trio
      [nil, true, false].each_with_index do |link, idx|
        plain("|") if idx.positive?
        render_status_link(link)
      end
    end

    # One status link: bold if it's the current status (a non-clickable
    # marker), otherwise a `Button::Patch` that flips this image's
    # status to the link value.
    def render_status_link(link)
      link_text = status_text(link)
      state_text = status_text(@status)
      if link_text == state_text
        b { plain(link_text) }
      else
        render_status_patch_button(link, link_text)
      end
    end

    def render_status_patch_button(link, link_text)
      Button(
        type: :patch,
        variant: :strip,
        name: link_text,
        target: visual_group_image_path(
          id: @image_id, visual_group_id: @visual_group.id,
          status: link
        ),
        title: link_text,
        data: { turbo: true }
      )
    end

    def render_image_id_line
      plain("#{:image_reuse_id.t}:")
      whitespace
      Link(type: :get, name: @image_id, target: image_path(id: @image_id))
    end

    def status_text(status)
      return :visual_group_needs_review.t if status.nil?
      return :visual_group_include.t if status && status != 0

      :visual_group_exclude.t
    end
  end
end
