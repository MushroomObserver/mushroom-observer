# frozen_string_literal: true

# Lightbox caption component for building the HTML caption shown in the
# lightbox.
#
# Handles two types of captions:
# 1. Observation captions - full details with when/where/who and naming
# 2. Image captions - just the image notes
#
# Both types include image links (original, EXIF) at the bottom.
#
# @example With observation
#   ImageFragment(type: :lightbox_caption, user: @user, image: @image,
#                 image_id: @image.id, obs: @observation, identify: true)
#
# @example With observation_view from controller (turbo stream)
#   ImageFragment(type: :lightbox_caption, user: @user, obs: @observation,
#                 identify: true, observation_view: @observation_view)
#
# @example With image only
#   ImageFragment(type: :lightbox_caption, user: @user, image: @image,
#                 image_id: @image.id)
class Components::ImageFragment::LightboxCaption < Components::Base
  prop :user, _Nilable(::User)
  prop :image, _Nilable(::Image), default: nil
  prop :image_id, _Nilable(Integer), default: nil
  prop :obs, _Union(::Observation, Hash), default: -> { {} }
  prop :identify, _Boolean, default: false
  prop :observation_view, _Nilable(::ObservationView), default: nil
  # Propagated from the parent `BaseImage` (carousel /
  # interactive-image). When the parent disables votes -- e.g. the
  # profile-images reuse page passes `votes: false` because it
  # doesn't pre-load `:image_votes` -- the lightbox caption must also
  # skip the vote section. Otherwise `VoteInterface` calls
  # `Image#users_vote(@user)` and triggers a Bullet N+1.
  prop :votes, _Boolean, default: true

  def view_template
    render_vote_section

    if @obs.is_a?(::Observation)
      render_obs_caption_parts
    elsif @image&.notes.present?
      render_image_caption
    end

    render_image_links
  end

  private

  def render_obs_caption_parts
    render_identify_ui if @identify
    render_obs_title
    render_obs_when_where_who
  end

  def render_identify_ui
    div(class: "obs-identify mb-3", id: "observation_identify_#{@obs.id}") do
      render_propose_naming_modal
      render_reviewed_toggle if @observation_view
    end
  end

  def render_propose_naming_modal
    Button(
      type: :modal,
      name: :create_naming.t,
      target: new_observation_naming_path(
        observation_id: @obs.id, context: "lightgallery"
      ),
      modal_id: "obs_#{@obs.id}_naming",
      variant: :primary,
      class: "d-inline-block propose-naming-link"
    )
  end

  def render_reviewed_toggle
    span(class: "mx-2") { whitespace }
    ObservationFragment(type: :mark_as_reviewed_toggle,
                        observation_view: @observation_view)
  end

  def render_obs_title
    fragment("obs_title") do
      ObservationFragment(type: :lightbox_title,
                          obs: @obs, user: @user, identify: @identify)
    end
  end

  def render_obs_when_where_who
    ul(class: "list-unstyled mb-0") do
      ObservationFragment(type: :when, obs: @obs)
      ObservationFragment(type: :where, obs: @obs, user: @user)
      ObservationFragment(type: :where_gps, obs: @obs, user: @user)
      ObservationFragment(type: :who, obs: @obs, user: @user)
    end
  end

  def render_image_caption
    div(class: "image-notes") { @image.notes.tl.truncate_html(300) }
  end

  # `context: :lightbox` -- plain always-visible styling (no
  # `.image-sizer` hover ancestor here to reveal a `:overlay`), and
  # every id this emits gets prefixed so it can't collide with the
  # in-page vote section that's also live in the DOM once the
  # lightbox is open. See `Components::ImageFragment::VoteInterface`.
  def render_vote_section
    return unless @votes && @user && @image

    ImageFragment(type: :vote_interface, user: @user, image: @image,
                  votes: true, context: :lightbox)
  end

  def render_image_links
    image_for_links = @image || @image_id

    p(class: "caption-image-links my-3") do
      render_original_image_link(image_for_links)
      plain(" | ")
      render_image_exif_link(image_for_links)
    end
  end

  def render_original_image_link(image_or_image_id)
    if image_or_image_id.is_a?(::Image)
      ImageFragment(type: :original_link,
                    image: image_or_image_id, link_class: "lightbox_link")
    else
      ImageFragment(type: :original_link,
                    image_id: image_or_image_id, link_class: "lightbox_link")
    end
  end

  def render_image_exif_link(image_or_image_id)
    image_id = if image_or_image_id.is_a?(::Image)
                 image_or_image_id.id
               else
                 image_or_image_id
               end

    ImageFragment(type: :exif_link,
                  image_id: image_id, link_class: "lightbox_link")
  end
end
