# frozen_string_literal: true

# What deleting a holder's content removes, with the button that starts
# it. Shared by the profile's Danger Zone and the admins' excluded iNat
# users page (see ContentPurgeActions).
module Views::Controllers::ContentPurges
  class New < Views::FullPageBase
    prop :plan, ::ContentPurge::Plan
    prop :holder, String
    prop :purge_path, String
    prop :return_path, String

    def view_template
      add_page_title(:content_purge_title.l(holder: @holder))
      @image_count = @plan.image_count
      @observation_count = @plan.native_observation_count
      p { plain(:content_purge_explanation.l) }
      render_counts
      render_buttons
    end

    private

    def render_counts
      ul(id: "content_purge_counts") do
        li { plain(:content_purge_image_count.l(count: @image_count)) }
        li do
          plain(:content_purge_observation_count.l(count: @observation_count))
        end
        li do
          plain(:content_purge_placeholder_count.l(
                  count: @plan.placeholder_observations.count
                ))
        end
      end
    end

    def render_buttons
      div(class: "mt-3") do
        render_confirm_button if @image_count.positive?
        Link(type: :get, name: :cancel.ti, target: @return_path,
             class: "ml-3")
      end
    end

    def render_confirm_button
      Button(
        type: :post, target: @purge_path, variant: :danger,
        name: :content_purge_confirm.l, form: { class: "d-inline-block" },
        confirm: :content_purge_confirm_message.l(
          observations: @observation_count, images: @image_count
        )
      )
    end
  end
end
