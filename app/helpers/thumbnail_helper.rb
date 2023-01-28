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
      destroy_button(name: "", target: link,
                     class: "image-link ab-fab")
    end
  end

  def image_caption_html(orig_url, image_id, obs_data = {})
    capture do
      concat(render(partial: "shared/lightbox/original_and_exif_links",
                    locals: { orig_url: orig_url, image_id: image_id }))

      if obs_data[:id].present?
        # url = observation_namings_path(observation_id: obs_data[:id],
        #                                approved_name: nil)
        concat(render(partial: "observations/show/observation",
                      locals: { observation: obs_data[:obs] }))
        # render(partial: "observations/namings/form",
        #        locals: { action: :create, url: url, show_reasons: true })
      end
    end
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
