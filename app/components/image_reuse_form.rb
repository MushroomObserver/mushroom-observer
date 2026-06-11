# frozen_string_literal: true

# Bound form for "attach an existing image by ID" used on the image
# reuse pages of `Observations::ImagesController#reuse`,
# `Account::Profile::ImagesController#reuse`, and
# `GlossaryTerms::ImagesController#reuse`. Carries one field
# (`img_id`) plus a "show all users' images / show only mine" toggle
# link beneath. The surrounding image matrix lives outside this form
# and POSTs directly via per-thumbnail links.
#
# @example
#   render(Components::ImageReuseForm.new(
#            form_action: { controller: "observations/images",
#                           action: :attach,
#                           observation_id: @observation.id },
#            all_users: @all_users
#          ))
class Components::ImageReuseForm < Components::ApplicationForm
  def initialize(form_action:, all_users: false)
    @form_action_url = form_action
    @all_users = all_users
    super(FormObject::ImageReuse.new)
  end

  def form_action
    url_for(@form_action_url)
  end

  def view_template
    div(class: "container-text") do
      render_id_field_row
      div(class: "help-block form-group") do
        trusted_html(:image_reuse_id_help.tp)
      end
      render_toggle_link
    end
  end

  private

  def render_id_field_row
    div(class: "form-group form-inline") do
      text_field(:img_id, label: "#{:image_reuse_id.t}:",
                          inline: true, size: 8,
                          data: { autofocus: "true" })
      input(type: "submit", name: "commit",
            value: :image_reuse_reuse.l,
            class: "btn btn-default ml-3")
    end
  end

  def render_toggle_link
    div(class: "form-group mt-3") do
      link_to(toggle_label,
              @form_action_url.merge(action: :reuse,
                                     all_users: @all_users ? 0 : 1),
              class: "btn btn-default")
    end
  end

  def toggle_label
    @all_users ? :image_reuse_just_yours.t : :image_reuse_all_users.t
  end
end
