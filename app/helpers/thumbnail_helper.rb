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
    # image, image_id = image.is_a?(Image) ? [image, image.id] : [nil, image]

    # these defaults could be passed instead
    responsive = true,
    notes = "",

    # size_url   = Image.url(size, image_id)
    thumb_url  = Image.url(:thumbnail, image_id)
    small_url  = Image.url(:small, image_id)
    medium_url = Image.url(:medium, image_id)
    large_url  = Image.url(:large, image_id)
    huge_url   = Image.url(:huge, image_id)
    full_url   = Image.url(:full_size, image_id)
    orig_url   = Image.url(:original, image_id)

    # For lazy load content sizing: set img width and height, or proportional padding-bottom
    img_width = image.width ? BigDecimal(image.width) : 100
    img_height = image.height ? BigDecimal(image.height) : 100
    img_proportion = "%.1f" % ( BigDecimal( img_height / img_width ) * 100 )

    img_class = "img-fluid w-100 lazyload position-absolute object-fit-cover #{img_class}" if responsive
    img_class = "img-unresponsive lazyload #{img_class}" if !responsive

    # Rails has trouble parsing this if we don't put it together as a string
    # data_srcset = "#{small_url} 320w, #{medium_url} 640w, #{large_url} 960w".html_safe
    data_srcset = [
      "#{small_url} 320w",
      "#{medium_url} 640w",
      "#{large_url} 960w",
      "#{huge_url} 1280w"
    ].join(",")

    data_sizes = [
      "(max-width: 575px) 100vw",
      "(max-width: 991px) 50vw",
      "(min-width: 992px) 30vw"
    ].join(",") if responsive

    data_sizes = [
      "(max-width: 575px) 100vw",
      "(max-width: 991px) 75vw",
      "(min-width: 992px) 50vw"
    ].join(",") if !responsive

    data = {
      toggle: "tooltip",
      placement: "bottom",
      src: small_url,
      srcset: data_srcset,
      sizes: data_sizes
    }

    html_options = {
      alt: notes,
      class: img_class,
      data: data
    }

    locals = {
      image: image,
      thumb_url: thumb_url,
      large_url: large_url,
      orig_url: orig_url,
      link: Image.show_link_args(image_id),
      size: :small,
      img_proportion: img_proportion,
      votes: true,
      original: false,
      responsive: responsive,
      theater_on_click: false,
      html_options: html_options,
      notes: notes
    }.merge(args)
    render(partial: "images/image_thumbnail", locals: locals)
  end

  def show_best_image(obs)
    if obs&.thumb_image
      thumbnail(obs.thumb_image,
                link: obs.show_link_args,
                size: :thumbnail,
                votes: true,
                responsive: false) + image_copyright(obs.thumb_image)
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
    # return a link if the user has NOT voted this way
    link = link_to(vote_text,
                   { controller: :images,
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
