# frozen_string_literal: true

# special markup for the lightbox
module LightboxHelper
  # this link needs to contain all the data for the lightbox image
  def lightbox_link(lightbox_data)
    icon = icon("fa-solid", "expand")
    caption = lightbox_caption_html(lightbox_data)

    link_to(icon, lightbox_data[:url],
            class: "theater-btn",
            data: { lightbox: lightbox_data[:id], title: caption })
  end

  # everything in the caption
  def lightbox_caption_html(lightbox_data)
    obs_data = lightbox_data[:obs_data]
    html = []
    if obs_data[:id].present?
      html = lightbox_obs_caption(html, obs_data, lightbox_data[:identify])
    end
    html << caption_image_links(lightbox_data[:image_id])
    safe_join(html)
  end

  # observation part of the caption. returns an array of html strings (to join)
  # template local assign "caption" skips the obs relations (projects, etc)
  def lightbox_obs_caption(html, obs_data, identify)
    if identify ||
       (obs_data[:obs].vote_cache.present? && obs_data[:obs].vote_cache <= 0)
      html << propose_naming_link(obs_data[:id], context: "lightbox")
      html << content_tag(:span, "&nbsp;".html_safe, class: "mx-2")
      html << mark_as_reviewed_toggle(obs_data[:id], "btn-primary")
    end
    html << caption_obs_title(obs_data)
    html << render(partial: "observations/show/observation",
                   locals: { obs: obs_data[:obs], caption: true })
  end

  def caption_obs_title(obs_data)
    content_tag(:h4, show_obs_title(obs: obs_data[:obs]),
                class: "obs-what", id: "observation_what_#{obs_data[:id]}")
  end

  # links relating to the image object, pre-joined as a div
  def caption_image_links(image_id)
    links = []
    links << original_image_link(image_id, "lightbox_link")
    links << " | "
    links << image_exif_link(image_id, "lightbox_link")
    content_tag(:div, class: "caption-image-links my-3") do
      safe_join(links)
    end
  end
end
