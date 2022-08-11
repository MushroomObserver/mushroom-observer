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
      link: Image.show_link_args(image_id),
      size: :small,
      votes: true,
      original: false,
      responsive: true,
      theater_on_click: false,
      html_options: {},
      notes: ""
    }.merge(args)
    render(partial: "image/image_thumbnail", locals: locals)
  end

  def show_best_image(obs)
    return unless obs&.thumb_image

    thumbnail(obs.thumb_image,
              link: obs.show_link_args,
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
    # return a link if the user has NOT voted this way
    link = link_to(vote_text,
                   { controller: :image,
                     action: :show_image,
                     id: image.id,
                     vote: vote },
                   title: image_vote_as_help_string(vote),
                   data: { role: "image_vote", id: image.id, val: vote })
    if current_vote == vote
      link = content_tag(:span, image_vote_as_short_string(vote))
    end
    link
  end
end
