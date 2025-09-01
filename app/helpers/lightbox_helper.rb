# frozen_string_literal: true

# special markup for the lightbox
module LightboxHelper
  # this link needs to contain all the data for the lightbox image
  def lightbox_link(user, lightbox_data)
    return unless lightbox_data

    icon = tag.i("", class: "glyphicon glyphicon-fullscreen")
    caption = lightbox_caption_html(user, lightbox_data)

    link_to(icon, lightbox_data[:url],
            class: "theater-btn",
            data: { sub_html: caption })
  end

  # everything in the caption
  def lightbox_caption_html(user, lightbox_data)
    return unless lightbox_data

    obs = lightbox_data[:obs]
    html = []
    if obs.is_a?(Observation)
      html += lightbox_obs_caption(user, obs, lightbox_data[:identify])
    elsif lightbox_data[:image]&.notes.present?
      html << lightbox_image_caption(lightbox_data[:image])
    end
    html << caption_image_links(lightbox_data[:image] ||
                                lightbox_data[:image_id])
    safe_join(html)
  end

  # observation part of the caption. returns an array of html strings (to join)
  # template local assign "caption" skips the obs relations (projects, etc)
  def lightbox_obs_caption(user, obs, identify)
    html = []

    html << caption_identify_ui(obs:) if identify
    html << caption_obs_title(user:, obs:, identify:)
    html << observation_details_when_where_who(obs:, user:)
    html << caption_truncated_notes(obs:)
    html
  end

  # This is the same caption that goes after the copyright info,
  # but we are skipping that here because it is slow as hell
  # (requires extra joins all over the place, as far afield as projects,
  # on every page where an image appears!)
  def lightbox_image_caption(image)
    tag.div(image.notes.tl.truncate_html(300), class: "image-notes")
  end

  # This gets removed on successful propose
  def caption_identify_ui(obs:)
    tag.div(class: "obs-identify mb-3", id: "observation_identify_#{obs.id}") do
      [
        propose_naming_link(
          obs.id, context: "lightgallery",
                  btn_class: "btn btn-primary d-inline-block"
        ),
        tag.span("&nbsp;".html_safe, class: "mx-2"),
        mark_as_reviewed_toggle(obs.id)
      ].safe_join
    end
  end

  # This is different from observation_show_title, more like matrix_box title
  def caption_obs_title(user:, obs:, identify:)
    btn_style = identify ? "text-bold" : "btn btn-primary"
    text = caption_obs_title_text(identify)
    tag.h4(
      id: "observation_what_#{obs.id}", class: "obs-what",
      data: { controller: "section-update", section_update_user_value: user.id }
    ) do
      [
        text,
        link_to(obs.id, obs.show_link_args,
                class: "#{btn_style} mr-3",
                id: "caption_obs_link_#{obs.id}"),
        obs.user_format_name(user).t.small_author
      ].compact_blank!.safe_join(" ")
    end
  end

  def caption_obs_title_text(identify)
    if identify
      tag.span("#{:OBSERVATION.l}: ", class: "font-weight-normal")
    else
      ""
    end
  end

  # Doing this here because truncating the output of observation_details_notes
  # produces unsafe html warning. Allows getting rid of line break after NOTES.
  def caption_truncated_notes(obs:)
    return "" unless obs.notes?

    notes = obs.notes_show_formatted.truncate(150, separator: " ").
            sub(/^\A/, "#{:NOTES.t}: ").wring_out_textile.tpl

    tag.div(class: "obs-notes", id: "observation_#{obs.id}_notes") do
      Textile.clear_textile_cache
      Textile.register_name(obs.name)
      tag.div(notes)
    end
  end

  # links relating to the image object, pre-joined as a div
  # pass an image instance if possible, to ensure access to fallback image.url
  def caption_image_links(image_or_image_id)
    links = []
    links << original_image_link(image_or_image_id, "lightbox_link")
    links << " | "
    links << image_exif_link(image_or_image_id, "lightbox_link")
    tag.p(class: "caption-image-links my-3") do
      safe_join(links)
    end
  end
end
