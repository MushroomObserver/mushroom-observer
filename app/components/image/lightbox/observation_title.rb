# frozen_string_literal: true

# Lightbox caption observation title component.
#
# Renders the observation title heading used in lightbox captions
# and turbo stream updates. This component displays the observation ID
# as a link along with the author attribution.
#
# @example Basic usage
#   render LightboxObservationTitle.new(obs: @observation, user: @user)
#
# @example With identify mode (shows "OBSERVATION:" label)
#   render LightboxObservationTitle.new(
#     obs: @observation,
#     user: @user,
#     identify: true
#   )
class Components::Image::Lightbox::ObservationTitle < Components::Base
  prop :obs, Observation
  prop :user, _Nilable(User), default: nil
  prop :identify, _Boolean, default: false

  def view_template
    h4(**title_attributes) do
      render_label if @identify
      whitespace
      render_link
      whitespace
      @obs.format_name(@user).t.small_author
    end
  end

  private

  def title_attributes
    {
      id: "observation_what_#{@obs.id}",
      class: "obs-what",
      data: {
        controller: "section-update",
        section_update_user_value: @user&.id
      }
    }
  end

  def render_label
    span(class: "font-weight-normal") { "#{:observation.ti}: " }
  end

  def render_link
    if @identify
      a(href: url_for(@obs.show_link_args),
        class: "text-bold mr-3",
        id: "caption_obs_link_#{@obs.id}") { @obs.id }
    else
      Button(
        type: :get,
        name: @obs.id.to_s,
        target: url_for(@obs.show_link_args),
        variant: :primary,
        id: "caption_obs_link_#{@obs.id}",
        class: "mr-3"
      )
    end
  end
end
