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
              size: :small,
              votes: true) + image_copyright(obs.thumb_image)
  end

  # Grab the copyright_text for an Image.
  def image_copyright(image)
    link = if image.copyright_holder == image.user.legal_name
             user_link(image.user)
           else
             image.copyright_holder.to_s.t
           end
    content_tag(:div, image.license.copyright_text(image.year, link),
                class: "mt-2 small")
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

  def image_original_name(original, image)
    return "" unless image && show_original_name(original, image)

    content_tag(:div, image.original_name, class: "mt-3")
  end

  def show_original_name(original, image)
    original && image &&
      image.original_name.present? &&
      (check_permission(image) ||
       image.user &&
       image.user.keep_filenames == "keep_and_show")
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
