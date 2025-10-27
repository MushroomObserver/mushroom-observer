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
#   render LightboxCaption.new(
#     user: @user,
#     image: @image,
#     image_id: @image.id,
#     obs: @observation,
#     identify: true
#   )
#
# @example With image only
#   render LightboxCaption.new(
#     user: @user,
#     image: @image,
#     image_id: @image.id
#   )
class Components::LightboxCaption < Components::Base
  include Phlex::Rails::Helpers::LinkTo

  prop :user, _Nilable(User)
  prop :image, _Nilable(Image), default: nil
  prop :image_id, _Nilable(Integer), default: nil
  prop :obs, _Union(Observation, Hash), default: -> { {} }
  prop :identify, _Boolean, default: false

  def view_template
    if obs.is_a?(Observation)
      render_obs_caption_parts
    elsif image&.notes.present?
      render_image_caption
    end

    render_image_links
  end

  private

  def render_obs_caption_parts
    render_identify_ui if identify
    render_obs_title
    render_obs_when_where_who
    render_truncated_notes
  end

  def render_identify_ui
    div(class: "obs-identify mb-3", id: "observation_identify_#{obs.id}") do
      unsafe_raw(
        helpers.propose_naming_link(
          obs.id,
          context: "lightgallery",
          btn_class: "btn btn-primary d-inline-block"
        )
      )
      span("&nbsp;".html_safe, class: "mx-2")
      unsafe_raw(helpers.mark_as_reviewed_toggle(obs.id))
    end
  end

  def render_obs_title
    h4(obs_title_attributes) do
      render_obs_title_content
    end
  end

  def obs_title_attributes
    {
      id: "observation_what_#{obs.id}",
      class: "obs-what",
      data: {
        controller: "section-update",
        section_update_user_value: user&.id
      }
    }
  end

  def render_obs_title_content
    render_obs_label if identify
    whitespace
    render_obs_link
    whitespace
    plain(obs.user_format_name(user).t.small_author)
  end

  def render_obs_label
    span("#{:OBSERVATION.l}: ", class: "font-weight-normal")
  end

  def render_obs_link
    btn_style = identify ? "text-bold" : "btn btn-primary"

    a(
      obs.id,
      href: helpers.url_for(obs.show_link_args),
      class: "#{btn_style} mr-3",
      id: "caption_obs_link_#{obs.id}"
    )
  end

  def render_obs_when_where_who
    render_obs_when
    render_obs_where
    render_obs_where_gps
    render_obs_who
  end

  def render_obs_when
    p(class: "obs-when", id: "observation_when") do
      plain("#{:WHEN.t}: ")
      b(obs.when.web_date)
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
    if obs.is_collection_location
      :show_observation_collection_location.t
    else
      :show_observation_seen_at.t
    end
  end

  def render_obs_location
    if user
      unsafe_raw(helpers.location_link(obs.where, obs.location, nil, true))
    else
      plain(obs.where)
    end
  end

  def render_vague_notice_if_needed
    return unless obs.location&.vague?

    whitespace
    render_vague_notice
  end

  def render_vague_notice
    title = :show_observation_vague_location.l
    title += " #{:show_observation_improve_location.l}" if user == obs.user

    p(class: "ml-3") do
      em(title)
    end
  end

  def render_obs_where_gps
    return unless obs.lat && user

    p(class: "obs-where-gps", id: "observation_where_gps") do
      render_gps_link if obs.reveal_location?(user)
      i("(#{:show_observation_gps_hidden.t})") if obs.gps_hidden
    end
  end

  def render_gps_link
    link_text = [
      obs.display_lat_lng.t,
      obs.display_alt.t,
      "[#{:click_for_map.t}]"
    ].join(" ")
    a(link_text, href: helpers.map_observation_path(id: obs.id))
  end

  def render_obs_who
    obs_user = obs.user

    p(class: "obs-who", id: "observation_who") do
      plain("#{:WHO.t}: ")
      render_obs_user(obs_user)
      render_contact_link(obs_user) if show_contact_link?(obs_user)
    end
  end

  def render_obs_user(obs_user)
    if user
      unsafe_raw(helpers.user_link(obs_user))
    else
      plain(obs_user.unique_text_name)
    end
  end

  def show_contact_link?(obs_user)
    user && obs_user != user && !obs_user&.no_emails &&
      obs_user&.email_general_question
  end

  def render_contact_link(_obs_user)
    plain(" [")
    unsafe_raw(
      helpers.modal_link_to(
        "observation_email",
        *helpers.send_observer_question_tab(obs)
      )
    )
    plain("]")
  end

  def render_truncated_notes
    return unless obs.notes?

    div(class: "obs-notes", id: "observation_#{obs.id}_notes") do
      prepare_textile_cache
      unsafe_raw(formatted_truncated_notes)
    end
  end

  def prepare_textile_cache
    Textile.clear_textile_cache
    Textile.register_name(obs.name)
  end

  def formatted_truncated_notes
    obs.notes_show_formatted.truncate(150, separator: " ").
      sub(/\A/, "#{:NOTES.t}: ").wring_out_textile.tpl
  end

  def render_image_caption
    div(class: "image-notes") do
      unsafe_raw(image.notes.tl.truncate_html(300))
    end
  end

  def render_image_links
    image_for_links = image || image_id

    p(class: "caption-image-links my-3") do
      render_original_image_link(image_for_links)
      plain(" | ")
      render_image_exif_link(image_for_links)
    end
  end

  def render_original_image_link(image_or_image_id)
    id = if image_or_image_id.is_a?(Image)
           image_or_image_id.id
         else
           image_or_image_id
         end

    a(
      :image_show_original.t,
      href: "/images/#{id}/original",
      class: "lightbox_link",
      target: "_blank",
      rel: "noopener",
      data: {
        controller: "image-loader",
        action: "click->image-loader#load",
        "image-loader-target": "link",
        "loading-text": :image_show_original_loading.t,
        "maxed-out-text": :image_show_original_maxed_out.t,
        "error-text": :image_show_original_error.t
      }
    )
  end

  def render_image_exif_link(image_or_image_id)
    image_id = if image_or_image_id.is_a?(Image)
                 image_or_image_id.id
               else
                 image_or_image_id
               end

    unsafe_raw(
      helpers.modal_link_to(
        "image_exif_#{image_id}",
        :image_show_exif.t,
        helpers.exif_image_path(id: image_id),
        { class: "lightbox_link" }
      )
    )
  end

  def helpers
    @helpers ||= ApplicationController.helpers
  end
end
