# frozen_string_literal: true

# Bound form for "attach an existing image by ID" used on the image
# reuse pages of `Observations::ImagesController#reuse`,
# `Account::Profile::ImagesController#reuse`, and
# `GlossaryTerms::ImagesController#reuse`. One `img_id` field. The
# "include other users' images" toggle is a sibling, `ReuseToggle`,
# rendered into the pagination row's sorter slot by each action
# view -- see that class for why it isn't rendered from here. The
# surrounding image matrix lives outside this form and POSTs
# directly via per-thumbnail links (`Components::InteractiveImage`).
#
# The `target` is the domain object whose images are being chosen
# for — `Observation`, `User` (profile), or `GlossaryTerm`. The
# Component derives the submit URL from the target's class via
# `form_action`; the 3 caller action templates just pass their
# subject and don't have to know any routing details.
#
# @example
#   ImageFragment(type: :reuse_form, target: @observation,
#                 all_users: @all_users)
class Components::ImageFragment::ReuseForm < Components::ApplicationForm
  CONTROLLERS = {
    ::Observation => "/observations/images",
    ::User => "/account/profile/images",
    ::GlossaryTerm => "/glossary_terms/images"
  }.freeze

  prop :target, _Union(::Observation, ::User, ::GlossaryTerm)
  prop :all_users, _Boolean, default: false

  def initialize(**)
    super(FormObject::ImageReuse.new, **)
  end

  def form_action
    url_for(controller: target_controller, action: :attach,
            id: @target.id)
  end

  def view_template
    Container(width: :text) do
      render_id_field_row
      Help(class: "form-group", content: :image_reuse_id_help.tp)
    end
  end

  private

  def target_controller
    CONTROLLERS.fetch(@target.class)
  end

  def render_id_field_row
    div(class: "form-group form-inline mt-3") do
      text_field(:img_id, label: :image_reuse_id,
                          inline: true, size: 8, wrap_class: "mb-0",
                          data: { autofocus: "true" })
      submit(:image_reuse_reuse.l, as: :button,
                                   name: "commit", class: "ml-3")
    end
  end
end
