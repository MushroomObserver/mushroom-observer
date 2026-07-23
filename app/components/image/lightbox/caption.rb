# frozen_string_literal: true

# Lightbox caption component for building the HTML caption shown in the
# lightbox.
#
# Handles two types of captions:
# 1. Observation captions - full details with when/where/who, notes, and naming
# 2. Image captions - just the image notes
#
# Both types include image links (original, EXIF) at the bottom.
#
# @example With observation
#   render(Components::Image::Lightbox::Caption.new(
#     user: @user,
#     image: @image,
#     image_id: @image.id,
#     obs: @observation,
#     identify: true
#   ))
#
# @example With observation_view from controller (turbo stream)
#   render(Components::Image::Lightbox::Caption.new(
#     user: @user,
#     obs: @observation,
#     identify: true,
#     observation_view: @observation_view
#   ))
#
# @example With image only
#   render(Components::Image::Lightbox::Caption.new(
#     user: @user,
#     image: @image,
#     image_id: @image.id
#   ))
class Components::Image::Lightbox::Caption < Components::Base
  prop :user, _Nilable(User)
  prop :image, _Nilable(::Image), default: nil
  prop :image_id, _Nilable(Integer), default: nil
  prop :obs, _Union(Observation, Hash), default: -> { {} }
  prop :identify, _Boolean, default: false
  prop :observation_view, _Nilable(ObservationView), default: nil

  def view_template
    if @obs.is_a?(Observation)
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
    render_truncated_notes
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
    render(Components::Image::MarkAsReviewedToggle.new(
             observation_view: @observation_view
           ))
  end

  def render_obs_title
    fragment("obs_title") do
      render(Components::Image::Lightbox::ObservationTitle.new(
               obs: @obs,
               user: @user,
               identify: @identify
             ))
    end
  end

  def render_obs_when_where_who
    render_obs_when
    render_obs_where
    render_obs_where_gps
    render_obs_who
  end

  def render_obs_when
    p(class: "obs-when", id: "observation_when") do
      plain("#{:when.ti}: ")
      b { @obs.when.web_date }
    end
  end

  def render_obs_where
    p(class: "obs-where", id: "observation_where") do
      plain("#{obs_where_label}: ")
      render_obs_location
      render_vague_notice_if_needed
    end
  end

  def obs_where_label
    if @obs.is_collection_location
      :show_observation_collection_location.t
    else
      :show_observation_seen_at.t
    end
  end

  def render_obs_location
    if @user
      Link(type: :location, where: @obs.where,
           location: @obs.location, click: true)
    else
      plain(@obs.where)
    end
  end

  def render_vague_notice_if_needed
    return unless @obs.location&.vague?

    title = :show_observation_vague_location.l
    title += " #{:show_observation_improve_location.l}" if @user == @obs.user

    whitespace
    p(class: "ml-3") do
      em { title }
    end
  end

  def render_obs_where_gps
    return unless @obs.lat && @user

    p(class: "obs-where-gps", id: "observation_where_gps") do
      render_gps_link if @obs.reveal_location?(@user)
      i { "(#{:show_observation_gps_hidden.l})" } if @obs.gps_hidden
    end
  end

  def render_gps_link
    parts = [display_lat_lng(@obs.lat, @obs.lng).t, display_alt(@obs.alt).t]
    trusted_html(parts.compact_blank.join(" "))
    render_gps_map_link
  end

  def render_gps_map_link
    InlineLinkBlock(items: [gps_map_icon])
  end

  def gps_map_icon
    Components::Link::Icon.new(
      content: :click_for_map.l,
      path: map_observation_path(id: @obs.id),
      icon: :place,
      class: Components::InlineLinkBlock.item_class
    )
  end

  def render_obs_who
    p(class: "obs-who", id: "observation_who") do
      ObservationWho(obs: @obs, user: @user)
    end
  end

  def render_truncated_notes
    return unless @obs.notes?

    prepare_textile_cache
    div(class: "obs-notes", id: "observation_#{@obs.id}_notes") do
      formatted_truncated_notes
    end
  end

  # ApplicationController's per-request reset only covers the FIRST
  # render on a request. This component renders once per observation
  # on a matrix/index page (Matrix::Box -> Image::Interactive ->
  # lightbox_caption_html -> this), so without an explicit clear here,
  # one observation's genus abbreviation leaks into the next
  # observation's textile rendering within the same page load.
  def prepare_textile_cache
    Textile.clear_textile_cache
    Textile.register_name(@obs.name)
  end

  def formatted_truncated_notes
    @obs.notes_show_formatted.truncate(150, separator: " ").
      sub(/\A/, "#{:notes.ti}: ").wring_out_textile.tpl
  end

  def render_image_caption
    div(class: "image-notes") { @image.notes.tl.truncate_html(300) }
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
      render(Components::Image::OriginalLink.new(
               image: image_or_image_id,
               link_class: "lightbox_link"
             ))
    else
      render(Components::Image::OriginalLink.new(
               image_id: image_or_image_id,
               link_class: "lightbox_link"
             ))
    end
  end

  def render_image_exif_link(image_or_image_id)
    image_id = if image_or_image_id.is_a?(::Image)
                 image_or_image_id.id
               else
                 image_or_image_id
               end

    render(Components::Image::EXIFLink.new(
             image_id: image_id, link_class: "lightbox_link"
           ))
  end
end
