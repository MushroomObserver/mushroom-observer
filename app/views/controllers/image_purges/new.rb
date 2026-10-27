# frozen_string_literal: true

# What deleting a holder's images removes, with the button that starts
# it. Shared by the profile's Danger Zone and the admins' excluded iNat
# users page (see ImagePurgeActions).
module Views::Controllers::ImagePurges
  class New < Views::FullPageBase
    prop :plan, ::ImagePurge::Plan
    prop :holder, String
    prop :purge_path, String
    prop :return_path, String

    def view_template
      add_page_title(:image_purge_title.l(holder: @holder))
      @image_count = @plan.image_count
      @observation_count = @plan.native_observation_count
      p { plain(:image_purge_explanation.l) }
      render_counts
      render_buttons
    end

    private

    def render_counts
      ul(id: "image_purge_counts") do
        li { plain(:image_purge_image_count.l(count: @image_count)) }
        li do
          plain(:image_purge_observation_count.l(count: @observation_count))
        end
        li do
          plain(:image_purge_placeholder_count.l(
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
        name: :image_purge_confirm.l, form: { class: "d-inline-block" },
        confirm: :image_purge_confirm_message.l(
          observations: @observation_count, images: @image_count
        )
      )
    end
  end
end
