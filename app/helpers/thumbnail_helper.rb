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
  # def thumbnail(
  #   image,
  #   args = {
  #     notes: "",
  #     extra_classes: ""
  #   }
  # )
  def thumbnail(image, args)
    render(partial: "shared/image_thumbnail",
           locals: args.merge({ image: image }))
  end

  def show_best_image(obs)
    return unless obs&.thumb_image

    thumbnail(obs.thumb_image,
              link: observation_path(id: obs.id),
              size: :thumbnail,
              votes: true) + image_copyright(obs.thumb_image)
  end

  def propose_naming_link(id, btn_class = "btn-primary my-3")
    render(partial: "observations/namings/propose_button",
           locals: { obs_id: id, text: :create_naming.t,
                     btn_class: "#{btn_class} d-inline-block" },
           layout: false)
  end

  # NOTE: There are potentially two of these toggles for the same obs, on
  # the obs_needing_ids index. Ideally, they'd be in sync. In reality, only
  # the matrix_box (page) checkbox will update if the (lightbox) caption
  # checkbox changes. Updating the lightbox checkbox to stay sync with the page
  # is harder because the caption is not created. Updating it would only work
  # with some additions to the lightbox JS, to keep track of the checked
  # state on show, and cost an extra db lookup. Not worth it, IMO.
  # - Nimmo 20230215
  def mark_as_reviewed_toggle(id, selector = "caption_reviewed",
                              label_class = "")
    render(partial: "observation_views/mark_as_reviewed",
           locals: { id: id, selector: selector, label_class: label_class },
           layout: false)
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
  # Returns a form input button if the user has NOT voted this way
  # JS is listening to any element with [data-role="image_vote"],
  # Even though this is not an <a> tag, but an <input>, it's ok.
  def image_vote_link(image, vote)
    current_vote = image.users_vote(@user)
    vote_text = vote.zero? ? "(x)" : image_vote_as_short_string(vote)

    if current_vote == vote
      return content_tag(:span, image_vote_as_short_string(vote))
    end

    put_button(name: vote_text, remote: true,
               path: image_vote_path(image_id: image.id, value: vote),
               title: image_vote_as_help_string(vote),
               data: { role: "image_vote", image_id: image.id, value: vote })
  end

  def visual_group_status_link(visual_group, image_id, state, link)
    link_text = visual_group_status_text(link)
    state_text = visual_group_status_text(state)
    return content_tag(:b, link_text) if link_text == state_text

    put_button(name: link_text,
               path: image_vote_path(image_id: image_id, vote: 1),
               title: link_text,
               data: { role: "visual_group_status",
                       imgid: image_id,
                       vgid: visual_group.id,
                       status: link })
  end
end
