# frozen_string_literal: true

module ThumbnailHelper
  # Draw a thumbnail image.  It takes either an Image instance or an id.
  #
  #   link::             Hash of { controller: xxx, action: xxx, etc. }
  #   size::             Size to show, default is thumbnail.
  #   votes::            Show vote buttons?
  #   original::         Show original file name?
  #   responsive::       Force image to fit into container.
  #   theater_on_click:: Should theater mode be opened when image clicked?
  #   html_options::     Additional HTML attributes to add to <img> tag.
  #   notes::            Show image notes??
  #
  def thumbnail(image, args = {})
    image_id = image.is_a?(Integer) ? image : image.id
    locals = {
      image: image,
      link: show_image_path(image_id),
      size: :small,
      votes: true,
      original: false,
      responsive: true,
      theater_on_click: false,
      html_options: {},
      notes: ""
    }.merge(args)
    render(partial: "shared/image_thumbnail", locals: locals)
  end

  def show_best_image(obs)
    return unless obs&.thumb_image

    thumbnail(obs.thumb_image,
              link: observation_path(id: obs.id),
              size: :thumbnail,
              votes: true,
              responsive: false) + image_copyright(obs.thumb_image)
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

    # return a link if the user has NOT voted this way
    # FIXME: JS is prolly checking a[data-role="image_vote"],
    # but this is not an anchor tag now, it's an input.
    # Also be sure inputs can have titles
    put_button(name: vote_text,
               path: image_vote_path(id: image.id, vote: vote),
               title: image_vote_as_help_string(vote),
               data: { role: "image_vote", id: image.id, val: vote })
  end

  def visual_group_status_link(visual_group, image_id, state, link)
    link_text = visual_group_status_text(link)
    state_text = visual_group_status_text(state)
    return content_tag(:span, link_text) if link_text == state_text

    # FIXME: JS is prolly checking a[data-role="visual_group_status"],
    # but this is not an anchor tag now, it's an input.
    put_button(name: link_text,
               path: image_vote_path(id: image_id, vote: 1),
               title: link_text,
               data: { role: "visual_group_status",
                       imgid: image_id,
                       vgid: visual_group.id,
                       status: link })
  end
end
