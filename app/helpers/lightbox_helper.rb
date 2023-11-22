# frozen_string_literal: true

# special markup for the lightbox
module LightboxHelper
  # this link needs to contain all the data for the lightbox image
  def lightbox_link(lightbox_data)
    icon = tag.i("", class: "glyphicon glyphicon-fullscreen")
    caption = lightbox_caption_html(lightbox_data)

    link_to(icon, lightbox_data[:url],
            class: "theater-btn",
            data: { sub_html: caption })
  end

  # everything in the caption
  def lightbox_caption_html(lightbox_data)
    obs_data = lightbox_data[:obs_data]
    html = []
    if obs_data[:id].present?
      html += lightbox_obs_caption(obs_data, lightbox_data[:identify])
    end
    html << caption_image_links(lightbox_data[:image] ||
                                lightbox_data[:image_id])
    safe_join(html)
  end

  # observation part of the caption. returns an array of html strings (to join)
  # template local assign "caption" skips the obs relations (projects, etc)
  def lightbox_obs_caption(obs_data, identify)
    html = []
    if identify
      html << propose_naming_link(obs_data[:id], context: "lightbox")
      html << content_tag(:span, "&nbsp;".html_safe, class: "mx-2")
      html << mark_as_reviewed_toggle(obs_data[:id])
    end
    html << caption_obs_title(obs_data)
    html << observation_details_when_where_who(obs: obs_data[:obs])
    html << caption_truncated_notes(obs: obs_data[:obs])
    html
  end

  # This is different from show_obs_title, it's more like the matrix_box title
  def caption_obs_title(obs_data)
    tag.h4(class: "obs-what", id: "observation_what_#{obs_data[:id]}") do
      [
        link_to(obs_data[:id], add_query_param(obs_data[:obs].show_link_args),
                class: "btn btn-primary mr-3",
                id: "caption_obs_link_#{obs_data[:id]}"),
        obs_data[:obs].format_name.t.small_author
      ].safe_join(" ")
    end
  end

  def caption_truncated_notes(obs:)
    return "" unless obs.notes?

    tag.div(class: "obs-notes", id: "observation_#{obs.id}_notes") do
      Textile.clear_textile_cache
      Textile.register_name(obs.name)
      tag.div(obs.notes_show_formatted.truncate(150, separator: " ").
                  sub(/^\A/, "#{:NOTES.t}: ").tpl)
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
