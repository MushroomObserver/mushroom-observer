# frozen_string_literal: true

module ImageHelper
  # Draw an image with all the fixin's. Takes either an Image instance or an id.
  #
  # Note: this is NOT rendering a partial because nested partials have been
  # demonstrated to be VERY slow in loops or collections.
  #
  # Uses ImagePresenter to assemble data.
  #
  #   link::             Hash of { controller: xxx, action: xxx, etc. }
  #   size::             Size to show, default is thumbnail.
  #   votes::            Show vote buttons?
  #   original::         Show original file name?
  #   theater_on_click:: Should theater mode be opened when image clicked?
  #   html_options::     Additional HTML attributes to add to <img> tag.
  #   notes::            Show image notes??
  #
  # USE: interactive_image(
  #   image,
  #   args = {
  #     notes: "",
  #     extra_classes: ""
  #   }
  # )
  def interactive_image(image, **args)
    presenter = ImagePresenter.new(image, args.except(:image))
    set_width = presenter.width.present? ? "width: #{presenter.width}px;" : ""

    [
      tag.div(class: "image-sizer position-relative mx-auto",
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
          lightbox_link(presenter.lightbox_data),
          image_vote_section_html(presenter.image, presenter.votes)
        ].safe_join
      end,
      image_owner_original_name(presenter.image, presenter.original)
    ].safe_join
  end

  # Needs object for copyright info
  def image_info(image, object, original: false)
    notes = []
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
    tag.div(image.license.copyright_text(image.year, holder),
            class: "small")
  end

  def show_image_copyright?(image, object)
    object.type_tag != :observation ||
      (object.type_tag == :observation &&
       image.copyright_holder != object.user.legal_name)
  end

  def show_best_image(obs)
    return unless obs&.thumb_image

    interactive_image(obs.thumb_image,
                      link: observation_path(id: obs.id),
                      size: :small,
                      votes: true) + image_copyright(obs.thumb_image, obs)
  end

  def original_image_link(image_id, classes)
    link_to(:image_show_original.t, Image.url(:original, image_id),
            { class: classes, target: "_blank", rel: "noopener" })
  end

  def image_exif_link(image_id, classes)
    link_to(:image_show_exif.t, exif_image_path(image_id),
            { class: classes, remote: true, onclick: "MOEvents.whirly();" })
  end

  # NOTE: `stretched_link` might be a link to #show_obs or #show_image,
  # but it may also be a button/input (with params[:img_id]) sending to
  # #reuse_image or #remove_image ...or any other clickable element. Elements
  # use .ab-fab instead of .stretched-link to keep .theater-btn clickable
  def image_stretched_link(path, link_method)
    case link_method
    when :get
      link_with_query("", path, class: stretched_link_classes)
    when :post
      post_button(name: "", path: path, class: stretched_link_classes)
    when :put
      put_button(name: "", path: path, class: stretched_link_classes)
    when :patch
      patch_button(name: "", path: path, class: stretched_link_classes)
    when :delete
      destroy_button(name: "", target: path, class: stretched_link_classes)
    when :remote
      link_with_query("", path, class: stretched_link_classes, remote: true)
    end
  end

  def stretched_link_classes
    "image-link ab-fab stretched-link"
  end

  def visual_group_status_link(visual_group, image_id, state, link)
    link_text = visual_group_status_text(link)
    state_text = visual_group_status_text(state)
    return tag.b(link_text) if link_text == state_text

    put_button(name: link_text,
               path: image_vote_path(image_id: image_id, vote: 1),
               title: link_text,
               data: { role: "visual_group_status",
                       imgid: image_id,
                       vgid: visual_group.id,
                       status: link })
  end

  # This is now a helper to avoid nested partials in loops - AN 2023
  # called in interactive_image above
  def image_vote_section_html(image, votes)
    return "" unless votes && image && User.current

    tag.div(class: "vote-section") do
      image_vote_meter_and_links(image)
    end
  end

  # called in votes update.js.erb
  def image_vote_meter_and_links(image)
    vote_pct = if image.vote_cache
                 ((image.vote_cache / Image.all_votes.length) * 100).floor
               else
                 0
               end

    [
      image_vote_meter(image, vote_pct),
      image_vote_buttons(image, vote_pct)
    ].safe_join
  end

  def image_vote_meter(image, vote_percentage)
    return "" unless vote_percentage

    tag.div(class: "vote-meter progress",
            title: "#{image.num_votes} #{:Votes.t}") do
      tag.div("", class: "progress-bar", id: "vote_meter_bar_#{image.id}",
                  role: "progressbar", style: "width: #{vote_percentage}%")
    end
  end

  def image_vote_buttons(image, vote_percentage)
    tag.div(class: "vote-buttons mt-2") do
      tag.div(class: "image-vote-links", id: "image_vote_links_#{image.id}") do
        [
          tag.div(class: "text-center small") do
            [
              user_vote_link(image),
              image_vote_links(image)
            ].safe_join
          end,
          tag.span(class: "hidden data_container",
                   data: { id: image.id, percentage: vote_percentage.to_s,
                           role: "image_vote_percentage" })
        ].safe_join
      end
    end
  end

  def user_vote_link(image)
    user = User.current
    return "" unless user && image.users_vote(user).present?

    image_vote_link(image, 0) + "&nbsp;".html_safe
  end

  def image_vote_links(image)
    Image.all_votes.map do |vote|
      image_vote_link(image, vote)
    end.safe_join("|")
  end

  # Create an image link vote, where vote param is vote number ie: 3
  # Returns a form input button if the user has NOT voted this way
  # JS is listening to any element with [data-role="image_vote"],
  # Even though this is not an <a> tag, but an <input>, it's ok.
  def image_vote_link(image, vote)
    current_vote = image.users_vote(User.current)
    vote_text = if vote.zero?
                  image_vote_none.html_safe
                else
                  image_vote_as_short_string(vote)
                end

    if current_vote == vote
      return tag.span(image_vote_as_short_string(vote),
                      class: "image-vote")
    end

    put_button(name: vote_text, remote: true,
               class: "image-vote-link",
               path: image_vote_path(image_id: image.id, value: vote),
               title: image_vote_as_help_string(vote),
               data: { role: "image_vote", image_id: image.id, value: vote })
  end

  # image vote lookup used in show_image
  def find_list_of_votes(image)
    image.image_votes.sort_by do |v|
      (v.anonymous ? :anonymous.l : v.user.unique_text_name).downcase
    rescue StandardError
      "?"
    end
  end

  def carousel_item(image, default_image, object, **args)
    # Caption needs object for copyright info
    presenter_args = args.merge({ size: :large, fit: :contain, original: true })
    presenter = ImagePresenter.new(image, presenter_args)
    active = image == default_image ? "active" : ""

    tag.div(class: class_names("carousel-item", active)) do
      [
        image_tag(presenter.img_src, presenter.options_lazy),
        image_stretched_link(presenter.image_link, presenter.image_link_method),
        lightbox_link(presenter.lightbox_data),
        carousel_caption(presenter, object)
      ].safe_join
    end
  end

  def carousel_caption(presenter, object)
    classes = "carousel-caption d-flex flex-column justify-content-center"
    caption = if (info = image_info(image, object,
                                    original: presenter.original)).present?
                tag.div(info, class: "image-info d-none d-md-block")
              else
                ""
              end

    tag.div(class: classes) do
      [
        image_vote_section_html(presenter.votes, presenter.image),
        caption
      ].safe_join
    end
  end

  def carousel_thumbnail(image, **args)
    presenter_args = args.merge({ fit: :contain })
    presenter = ImagePresenter.new(image, presenter_args)

    image_tag(presenter.img_src, presenter.options_lazy)
  end
end
