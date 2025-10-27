# frozen_string_literal: true

module ImagesHelper
  # Draw an image with all the fixin's. Takes either an Image instance or an id.
  #
  # TODO: Make this a component. This should probably not be a partial: using
  # nested partials has been demonstrated to be VERY slow in loops or
  # collections. (Caching helps though).
  #
  # Uses ImagePresenter to assemble data.

  #   size::             Size to show, default is thumbnail.
  #   votes::            Show vote buttons?
  #   id_prefix::        Prefix for HTML ID of wrapping div.image-sizer
  #   image_link::       Override where the image stretched link goes
  #   original::         Show original file name?
  #   is_set::           Image is part of a set of images for lightbox
  #   extra_classes::    Additions to default <img> tag classes
  #   html_options::     Additional HTML attributes to add to <img> tag.
  #   full_width::       Do not set a width attribute on the <img> tag
  #   notes::            Show image notes??
  #
  # USE: interactive_image(user, image, args = { notes: "", extra_classes: "" })
  def interactive_image(user, image, **args)
    # Caption needs object for copyright info
    presenter = ImagePresenter.new(user, image, args)
    set_width = presenter.width.present? ? "width: #{presenter.width}px;" : ""

    [
      tag.div(id: presenter.html_id,
              class: "image-sizer position-relative mx-auto",
              style: set_width.to_s) do
        [
          tag.div(class: "image-lazy-sizer overflow-hidden",
                  style: "padding-bottom: #{presenter.proportion}%;") do
            [
              image_tag("placeholder.svg", presenter.options_lazy),
              tag.noscript do
                image_tag(presenter.img_src, presenter.options_noscript)
              end
            ].safe_join
          end,
          image_stretched_link(presenter.image_link,
                               presenter.image_link_method),
          lightbox_link(user, presenter.lightbox_data),
          image_vote_section_html(user, presenter.image, presenter.votes)
        ].safe_join
      end,
      image_owner_original_name(presenter.image, presenter.original)
    ].safe_join
  end

  # Args for the InteractiveImage component on Images#show
  def image_show_args
    { size: :huge,
      image_link: "#",
      img_class: "huge-image",
      votes: false }
  end

  # Needs object for copyright info
  def image_info(image, object, original: false)
    notes = []
    # XXX Consider dropping this from indexes.
    notes << tag.div(image_owner_original_name(image, original),
                     class: "image-original-name")
    notes << tag.div(image_copyright(image, object), class: "image-copyright")
    if image.notes.present?
      notes << tag.div(image.notes.tl.truncate_html(300),
                       class: "image-notes")
    end
    notes.compact_blank.safe_join
  end

  def image_owner_original_name(image, original)
    return "" unless image && show_original_name?(image, original)

    tag.div(image.original_name)
  end

  def show_original_name?(image, original)
    original && image &&
      image.original_name.present? &&
      (check_permission(image) ||
       image.user &&
       image.user.keep_filenames == "keep_and_show")
  end

  # Grab the copyright_text for an Image.
  def image_copyright(image, object = image)
    return "" unless image && show_image_copyright?(image, object)

    holder = if image.copyright_holder == image.user.legal_name
               user_link(image.user)
             else
               image.copyright_holder.to_s.t
             end
    tag.div(image.license&.copyright_text(image.year, holder),
            class: "small")
  end

  def show_image_copyright?(image, object)
    object.type_tag != :observation ||
      (object.type_tag == :observation &&
       image.copyright_holder != object.user&.legal_name)
  end

  # pass an image instance if possible, to ensure access to fallback image.url
  def original_image_link(image_or_image_id, classes)
    id = if image_or_image_id.is_a?(Image)
           image_or_image_id.id
         else
           image_or_image_id
         end
    link_to(
      :image_show_original.t,
      "/images/#{id}/original",
      {
        class: classes,
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
      }
    )
  end

  def image_exif_link(image_or_image_id, classes)
    image_id = if image_or_image_id.is_a?(Image)
                 image_or_image_id.id
               else
                 image_or_image_id
               end
    modal_link_to("image_exif_#{image_id}", :image_show_exif.t,
                  exif_image_path(id: image_id), { class: classes })
  end

  # NOTE: `stretched_link` might be a link to #show_obs or #show_image,
  # but it may also be a button/input (with params[:img_id]) sending to
  # #reuse_image or #remove_image ...or any other clickable element. Elements
  # use .ab-fab instead of .stretched-link to keep .theater-btn clickable
  def image_stretched_link(path, link_method)
    case link_method
    when :get
      link_to("", path, class: stretched_link_classes)
    when :post
      post_button(name: "", path: path, class: stretched_link_classes)
    when :put
      put_button(name: "", path: path, class: stretched_link_classes)
    when :patch
      patch_button(name: "", path: path, class: stretched_link_classes)
    when :delete
      destroy_button(name: "", target: path, class: stretched_link_classes)
    end
  end

  def stretched_link_classes
    "image-link ab-fab stretched-link"
  end

  # This is now a helper to avoid nested partials in loops - AN 2023
  # called in interactive_image above
  def image_vote_section_html(user, image, votes)
    return "" unless votes && image

    tag.div(class: "vote-section require-user",
            id: "image_vote_#{image.id}") do
      image_vote_meter_and_links(user, image)
    end
  end

  # called in votes update.erb
  def image_vote_meter_and_links(user, image)
    vote_pct = if image.vote_cache
                 ((image.vote_cache / Image.all_votes.length) * 100).floor
               else
                 0
               end

    [
      image_vote_meter(image, vote_pct),
      image_vote_buttons(user, image, vote_pct)
    ].safe_join
  end

  def image_vote_meter(image, vote_percentage)
    return "" unless vote_percentage

    tag.div(class: "vote-meter progress",
            title: "#{image.num_votes} #{:Votes.t}") do
      tag.div("", class: "progress-bar", id: "vote_meter_bar_#{image.id}",
                  style: "width: #{vote_percentage}%")
    end
  end

  def image_vote_buttons(user, image, vote_percentage)
    tag.div(class: "vote-buttons mt-2") do
      tag.div(class: "image-vote-links", id: "image_vote_links_#{image.id}") do
        [
          tag.div(class: "text-center small") do
            [
              user_vote_link(user, image),
              image_vote_links(user, image)
            ].safe_join
          end,
          tag.span(class: "hidden data_container",
                   data: { id: image.id, percentage: vote_percentage.to_s })
        ].safe_join
      end
    end
  end

  def user_vote_link(user, image)
    return "" unless user && image.users_vote(user).present?

    image_vote_link(user, image, 0) + "&nbsp;".html_safe
  end

  def image_vote_links(user, image)
    Image.all_votes.map do |vote|
      image_vote_link(user, image, vote)
    end.safe_join("|")
  end

  # Create an image link vote, where vote param is vote number ie: 3
  # Returns a form input button if the user has NOT voted this way
  # JS is listening to any element with [data-role="image_vote"],
  # Even though this is not an <a> tag, but an <input>, it's ok.
  def image_vote_link(user, image, vote)
    current_vote = image.users_vote(user)
    vote_text = if vote.zero?
                  "(x)"
                else
                  image_vote_as_short_string(vote)
                end

    if current_vote == vote
      return tag.span(image_vote_as_short_string(vote),
                      class: "image-vote")
    end

    put_button(name: vote_text, # form data-turbo: true already there
               class: "image-vote-link",
               path: image_vote_path(image_id: image.id, value: vote),
               title: image_vote_as_help_string(vote),
               data: { image_id: image.id, value: vote })
  end

  # image vote lookup used in show_image
  def find_list_of_votes(image)
    image.image_votes.sort_by do |v|
      (v.anonymous ? :anonymous.l : v.user.unique_text_name).downcase
    rescue StandardError
      "?"
    end
  end
end
