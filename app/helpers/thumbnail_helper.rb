# frozen_string_literal: true

module ThumbnailHelper
  # Draw a thumbnail image.  It takes either an Image instance or an id.
  #
  #   link::             Hash of { controller: xxx, action: xxx, etc. }
  #   size::             Size to show, default is thumbnail.
  #   votes::            Show vote buttons?
  #   original::         Show original file name?
  #   theater_on_click:: Should theater mode be opened when image clicked?
  #   html_options::     Additional HTML attributes to add to <img> tag.
  #   notes::            Show image notes??
  #
  def thumbnail(image, args = {})
    image_id = image.is_a?(Integer) ? image : image.id
    locals = {
      image: image,
      link: image_path(image_id),
      link_method: :get,
      size: :small,
      votes: true,
      original: false,
      theater_on_click: false,
      html_options: {}, # we don't want to always pass class: "img-fluid"
      extra_classes: "",
      notes: "",
      link_type: :target,
      obs_data: {}
    }.merge(args)
    render(partial: "shared/image_thumbnail", locals: locals)
  end

  def show_best_image(obs)
    return unless obs&.thumb_image

    thumbnail(obs.thumb_image,
              link: observation_path(id: obs.id),
              size: :thumbnail,
              votes: true) + image_copyright(obs.thumb_image)
  end

  # NOTE: The local var `link` might be to #show_image as you'd expect,
  # or it may be a GET with params[:img_id] to the actions for #reuse_image
  # or #remove_image ...or any other link. Firing a POST to those actions
  # might require printing a Rails post_button and putting something like
  # Bootstrap's .stretched-link class on the generated form input.
  # However, the whole reuse_image page is currently a form - refactor?
  def image_link_html(link = "", link_method = :get)
    case link_method
    when :get
      link_with_query("", link, class: "image-link ab-fab")
    when :post
      post_button(name: "", path: link, class: "image-link ab-fab")
    when :put
      put_button(name: "", path: link, class: "image-link ab-fab")
    when :patch
      patch_button(name: "", path: link, class: "image-link ab-fab")
    when :delete
      destroy_button(name: "", target: link, class: "image-link ab-fab")
    when :remote
      link_with_query("", link, class: "image-link ab-fab", remote: true)
    end
  end

  def image_caption_html(image_id, obs_data, link_type)
    html = []
    if obs_data[:id].present?
      html = image_observation_data(html, obs_data, link_type)
    end
    html << caption_image_links(image_id)
    safe_join(html)
  end

  def image_observation_data(html, obs_data, link_type)
    if link_type == :naming ||
       (obs_data[:obs].vote_cache.present? && obs_data[:obs].vote_cache <= 0)
      html << caption_propose_naming_link(obs_data[:id])
      html << content_tag(:div, "", class: "mx-4 d-inline-block")
      html << caption_mark_as_reviewed_toggle(obs_data[:id])
    end
    html << caption_obs_title(obs_data)
    html << render(partial: "observations/show/observation",
                   locals: { observation: obs_data[:obs] })
  end

  def caption_image_links(image_id)
    orig_url = Image.url(:original, image_id)
    links = []
    links << original_image_link(orig_url)
    links << " | "
    links << image_exif_link(image_id)
    safe_join(links)
  end

  def caption_propose_naming_link(id, btn_class = "btn-primary my-3")
    link_to(
      :create_naming.t,
      new_observation_naming_path(observation_id: id,
                                  q: get_query_param),
      { class: "btn #{btn_class} d-inline-block",
        remote: true }
    )
  end

  # NOTE: There are potentially two of these toggles for the same obs, on
  # the obs_needing_ids index. Ideally, they'd be in sync. In reality:
  # Only the matrix_box checkbox will update if the caption checkbox changes.
  # But updating the caption checkbox in sync with the matrix box checkbox
  # is blocked because the caption is not created. Updating it would only work
  # with some additions to the lightbox JS, to keep track of the checked
  # state on show, and cost an extra db lookup. Not worth it, IMO.
  # - Nimmo 20230215
  def caption_mark_as_reviewed_toggle(id, selector = "caption_reviewed",
                                      label_class = "")
    form_with(url: observation_view_path(id: id),
              class: "d-inline-block",
              method: :put, local: false) do |f|
      content_tag(:div, class: "d-inline form-group form-inline") do
        f.label("#{selector}_#{id}", class: label_class) do
          concat(:mark_as_reviewed.t)
          concat(
            f.check_box(
              :reviewed,
              { checked: "1", class: "mx-3", id: "#{selector}_#{id}",
                onchange: "Rails.fire(this.closest('form'), 'submit')" }
            )
          )
        end
      end
    end
  end

  def caption_obs_title(obs_data)
    content_tag(:h4, show_obs_title(obs: obs_data[:obs]),
                class: "obs-what", id: "observation_what_#{obs_data[:id]}")
  end

  def original_image_link(orig_url)
    link_to(:image_show_original.t, orig_url,
            { class: "lightbox_link", target: "_blank", rel: "noopener" })
  end

  def image_exif_link(image_id)
    content_tag(:button, :image_show_exif.t,
                { class: "btn btn-link px-0 lightbox_link",
                  data: {
                    toggle: "modal",
                    target: "#image_exif_modal",
                    image: image_id
                  } })
  end

  # Grab the copyright_text for an Image.
  def image_copyright(image)
    link = if image.copyright_holder == image.user.legal_name
             user_link(image.user)
           else
             image.copyright_holder.to_s.t
           end
    image.license.copyright_text(image.year, link)
  end

  # Create an image link vote, where vote param is vote number ie: 3
  def image_vote_link(image, vote)
    current_vote = image.users_vote(@user)
    vote_text = vote.zero? ? "(x)" : image_vote_as_short_string(vote)
    if current_vote == vote
      return content_tag(:span, image_vote_as_short_string(vote))
    end

    # return a form input button if the user has NOT voted this way
    # NOTE: JS is checking any element with [data-role="image_vote"],
    # Even though this is not an <a> tag, it's an <input>, it's ok.
    put_button(name: vote_text,
               path: image_vote_path(id: image.id, vote: vote),
               title: image_vote_as_help_string(vote),
               data: { role: "image_vote", id: image.id, val: vote })
  end

  def visual_group_status_link(visual_group, image_id, state, link)
    link_text = visual_group_status_text(link)
    state_text = visual_group_status_text(state)
    return content_tag(:span, link_text) if link_text == state_text

    put_button(name: link_text,
               path: image_vote_path(id: image_id, vote: 1),
               title: link_text,
               data: { role: "visual_group_status",
                       imgid: image_id,
                       vgid: visual_group.id,
                       status: link })
  end
end
