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

  #   # Sometimes it's prohibitive to do the extra join to images table,
  #   # so we only have image_id. It's still possible to render the image with
  #   # nothing but the image_id. (But not votes, original name, etc.)
  #   image, image_id = image.is_a?(Image) ? [image, image.id] : [nil, image]

  #   args[:size] ||= "small"
  #   args[:data] ||= {}
  #   args[:data_sizes] ||= {}
  #   args[:obs_data] ||= {}
  #   args[:identify] ||= false
  #   args[:link] ||= image_path(image_id)
  #   args[:link_method] ||= :get
  #   args[:votes] ||= true

  #   img_class = "img-fluid lazy #{args[:extra_classes]}"
  #   img_urls = thumbnail_urls(image_id)
  #   img_src = img_urls[args[:size]]
  #   img_srcset = thumbnail_srcset(img_urls[:small], img_urls[:medium],
  #                                 img_urls[:large], img_urls[:huge])
  #   img_sizes = args[:data_sizes] || thumbnail_srcset_sizes

  #   # <img> data attributes. Account for possible data-confirm, etc
  #   img_data = {
  #     src: img_urls[:small],
  #     srcset: img_srcset,
  #     sizes: img_sizes
  #   }.merge(args[:data])

  #   # <img> attributes
  #   html_options = {
  #     alt: args[:notes],
  #     class: img_class,
  #     data: img_data
  #   }

  #   img_tag = image_tag(img_src, html_options)
  #   # The stretched-link (link/button/form) covering the image
  #   img_link = image_link_html(args[:link], args[:link_method])

  #   show_original_name = args[:original] && image &&
  #                        image.original_name.present? &&
  #                        (check_permission(image) ||
  #                         image.user &&
  #                         image.user.keep_filenames == "keep_and_show")
  #   img_filename = if show_original_name
  #                    content_tag(:div,
  #                                image.original_name)
  #                  else
  #                    ""
  #                  end

  #   # The size src appearing in the lightbox is a user pref
  #   lb_size = User.current&.image_size || "huge"
  #   lb_url = img_urls[lb_size]
  #   lb_id = args[:is_set] ? "observation-set" : SecureRandom.uuid
  #   lb_caption = image_caption_html(image_id, args[:obs_data], args[:identify])
  #   lightbox_link = link_to("", lb_url,
  #                           class: "glyphicon glyphicon-fullscreen theater-btn",
  #                           data: { lightbox: lb_id, title: lb_caption })

  #   locals = {
  #     image: image,
  #     img_tag: img_tag,
  #     img_link: img_link,
  #     lightbox_link: lightbox_link,
  #     votes: args[:votes],
  #     img_filename: img_filename
  #   }
  #   render(partial: "shared/image_thumbnail", locals: args)
  # end

  def thumbnail(image, args)
    render(partial: "shared/image_thumbnail",
           locals: args.merge({ image: image }))
  end

  # def thumbnail_urls(image_id)
  #   {
  #     "small" => Image.url(:small, image_id),
  #     "medium" => Image.url(:medium, image_id),
  #     "large" => Image.url(:large, image_id),
  #     "huge" => Image.url(:huge, image_id),
  #     "full_size" => Image.url(:full_size, image_id)
  #   }
  # end

  # def lightbox_url(image_id)
  #   lb_size = User.current&.image_size || "huge"
  #   thumbnail_urls(image_id)[lb_size]
  # end

  # def thumbnail_srcset(small_url, medium_url, large_url, huge_url)
  #   [
  #     "#{small_url} 320w",
  #     "#{medium_url} 640w",
  #     "#{large_url} 960w",
  #     "#{huge_url} 1280w"
  #   ].join(",")
  # end

  # def thumbnail_srcset_sizes
  #   [
  #     "(max-width: 575px) 100vw",
  #     "(max-width: 991px) 50vw",
  #     "(min-width: 992px) 30vw"
  #   ].join(",")
  # end

  def show_best_image(obs)
    return unless obs&.thumb_image

    thumbnail(obs.thumb_image,
              link: observation_path(id: obs.id),
              size: :thumbnail,
              votes: true) + image_copyright(obs.thumb_image)
  end

  # NOTE: The local var `link` might be to #show_image as you'd expect,
  # or it may be a GET with params[:img_id] to the actions for #reuse_image
  # or #remove_image ...or any other link.
  # These use .ab-fab instead of .stretched-link so .theater-btn is clickable
  # def image_link_html(link = "", link_method = :get)
  #   case link_method
  #   when :get
  #     link_with_query("", link, class: "image-link ab-fab")
  #   when :post
  #     post_button(name: "", path: link, class: "image-link ab-fab")
  #   when :put
  #     put_button(name: "", path: link, class: "image-link ab-fab")
  #   when :patch
  #     patch_button(name: "", path: link, class: "image-link ab-fab")
  #   when :delete
  #     destroy_button(name: "", target: link, class: "image-link ab-fab")
  #   when :remote
  #     link_with_query("", link, class: "image-link ab-fab", remote: true)
  #   end
  # end

  # def image_caption_html(image_id, obs_data, identify)
  #   html = []
  #   if obs_data[:id].present?
  #     html = image_observation_caption(html, obs_data, identify)
  #   end
  #   html << caption_image_links(image_id)
  #   safe_join(html)
  # end

  # def image_observation_caption(html, obs_data, identify)
  #   if identify ||
  #      (obs_data[:obs].vote_cache.present? && obs_data[:obs].vote_cache <= 0)
  #     html << propose_naming_link(obs_data[:id])
  #     html << content_tag(:span, "&nbsp;".html_safe, class: "mx-2")
  #     html << mark_as_reviewed_toggle(obs_data[:id])
  #   end
  #   html << caption_obs_title(obs_data)
  #   html << render(partial: "observations/show/observation",
  #                  locals: { observation: obs_data[:obs] })
  # end

  # def caption_image_links(image_id)
  #   orig_url = Image.url(:original, image_id)
  #   links = []
  #   links << original_image_link(orig_url)
  #   links << " | "
  #   links << image_exif_link(image_id)
  #   safe_join(links)
  # end

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

  # def caption_obs_title(obs_data)
  #   content_tag(:h4, show_obs_title(obs: obs_data[:obs]),
  #               class: "obs-what", id: "observation_what_#{obs_data[:id]}")
  # end

  # def original_image_link(orig_url)
  #   link_to(:image_show_original.t, orig_url,
  #           { class: "lightbox_link", target: "_blank", rel: "noopener" })
  # end

  # def image_exif_link(image_id)
  #   content_tag(:button, :image_show_exif.t,
  #               { class: "btn btn-link px-0 lightbox_link",
  #                 data: {
  #                   toggle: "modal",
  #                   target: "#image_exif_modal",
  #                   image: image_id
  #                 } })
  # end

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
    return content_tag(:b, link_text) if link_text == state_text

    put_button(name: link_text,
               path: image_vote_path(id: image_id, vote: 1),
               title: link_text,
               data: { role: "visual_group_status",
                       imgid: image_id,
                       vgid: visual_group.id,
                       status: link })
  end
end
