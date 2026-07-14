# frozen_string_literal: true

# Bound form for "attach an existing image by ID" used on the image
# reuse pages of `Observations::ImagesController#reuse`,
# `Account::Profile::ImagesController#reuse`, and
# `GlossaryTerms::ImagesController#reuse`. One `img_id` field plus
# a "show all users' images / show only mine" toggle link beneath.
# The surrounding image matrix lives outside this form and POSTs
# directly via per-thumbnail links (`Components::Image::Interactive`).
#
# The `target` is the domain object whose images are being chosen
# for — `Observation`, `User` (profile), or `GlossaryTerm`. The
# Component derives the submit URL from the target's class via
# `form_action`; the 3 caller action templates just pass their
# subject and don't have to know any routing details.
#
# @example
#   render(Components::Image::ReuseForm.new(
#            target: @observation, all_users: @all_users
#          ))
class Components::Image::ReuseForm < Components::ApplicationForm
  CONTROLLERS = {
    ::Observation => "/observations/images",
    ::User => "/account/profile/images",
    ::GlossaryTerm => "/glossary_terms/images"
  }.freeze

  def initialize(target:, all_users: false)
    @target = target
    @all_users = all_users
    super(FormObject::ImageReuse.new)
  end

  def form_action
    url_for(controller: target_controller, action: :attach,
            id: @target.id)
  end

  def view_template
    Container(width: :text) do
      render_id_field_row
      Help(class: "form-group", content: :image_reuse_id_help.tp)
      render_toggle_link
    end
  end

  private

  def target_controller
    CONTROLLERS.fetch(@target.class)
  end

  def render_id_field_row
    div(class: "form-group form-inline") do
      text_field(:img_id, label: "#{:image_reuse_id.t}:",
                          inline: true, size: 8,
                          data: { autofocus: "true" })
      submit(:image_reuse_reuse.l, as: :button,
                                   name: "commit", class: "ml-3")
    end
  end

  def render_toggle_link
    div(class: "form-group mt-3") do
      Button(type: :get, target: toggle_url,
             name: toggle_label)
    end
  end

  def toggle_label
    @all_users ? :image_reuse_just_yours.t : :image_reuse_all_users.t
  end

  def toggle_url
    url_for(controller: target_controller, action: :reuse,
            id: @target.id,
            all_users: @all_users ? 0 : 1)
  end
end
