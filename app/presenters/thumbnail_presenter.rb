# frozen_string_literal: true

# Gather details for items in matrix-style ndex pages.
class ThumbnailPresenter
  attr_accessor \
    :image,         # image instance or id
    :img_tag,       # thumbnail image tag
    :img_link_html, # stretched-link (link/button/form)
    :lightbox_link, # what the lightbox link passes to lightbox (incl. caption)
    :votes,         # show votes? boolean
    :img_filename   # original image filename (maybe none)

  def initialize(image, view, args = {})
    # Sometimes it's prohibitive to do the extra join to images table,
    # so we only have image_id. It's still possible to render the image with
    # nothing but the image_id. (But not votes, original name, etc.)
    image, image_id = image.is_a?(Image) ? [image, image.id] : [nil, image]

    # make view methods available to presenter methods
    @view = view

    default_args = {
      size: :small,
      notes: "",
      data: {},
      data_sizes: {},
      extra_classes: "",
      obs_data: {}, # used in lightbox caption
      identify: false,
      link: h.image_path(image_id),
      link_method: :get,
      votes: true
    }
    args = default_args.merge(args)

    args_to_presenter(image, image_id, args)
  end

  # h is a convention for view_context
  def h
    @view
  end

  def args_to_presenter(image, image_id, args)
    # Store these urls once]
    img_urls = thumbnail_urls(image_id)
    img_src = img_urls[args[:size]]
    img_srcset = thumbnail_srcset(img_urls[:small], img_urls[:medium],
                                  img_urls[:large], img_urls[:huge])
    img_sizes = args[:data_sizes] || thumbnail_srcset_sizes
    img_class = "img-fluid lazy #{args[:extra_classes]}"

    # <img> data attributes. Account for possible data-confirm, etc
    img_data = {
      src: img_urls[:small],
      srcset: img_srcset,
      sizes: img_sizes
    }.merge(args[:data])

    # <img> attributes
    html_options = {
      alt: args[:notes],
      class: img_class,
      data: img_data
    }

    # The size src appearing in the lightbox is a user pref
    lb_size = User.current&.image_size || "huge"
    lb_url = img_urls[lb_size]
    lb_id = args[:is_set] ? "observation-set" : SecureRandom.uuid
    lb_caption = image_caption_html(image_id, args[:obs_data], args[:identify])

    self.image = image || nil
    self.img_tag = h.image_tag(img_src, html_options)
    self.img_link_html = image_link_html(args[:link], args[:link_method])
    self.lightbox_link = lb_link(lb_url, lb_id, lb_caption)
    self.votes = args[:votes]
    self.img_filename = img_orig_name(args, image)
  end

  # get these once, since it's computed
  def thumbnail_urls(image_id)
    {
      small: Image.url(:small, image_id),
      medium: Image.url(:medium, image_id),
      large: Image.url(:large, image_id),
      huge: Image.url(:huge, image_id),
      full_size: Image.url(:full_size, image_id)
    }
  end

  def thumbnail_srcset(small_url, medium_url, large_url, huge_url)
    [
      "#{small_url} 320w",
      "#{medium_url} 640w",
      "#{large_url} 960w",
      "#{huge_url} 1280w"
    ].join(",")
  end

  def thumbnail_srcset_sizes
    [
      "(max-width: 575px) 100vw",
      "(max-width: 991px) 50vw",
      "(min-width: 992px) 30vw"
    ].join(",")
  end

  # NOTE: The local var `link` might be to #show_image as you'd expect,
  # or it may be a GET with params[:img_id] to the actions for #reuse_image
  # or #remove_image ...or any other link.
  # These use .ab-fab instead of .stretched-link so .theater-btn is clickable
  def image_link_html(link, link_method)
    case link_method
    when :get
      h.link_with_query("", link, class: "image-link ab-fab")
    when :post
      h.post_button(name: "", path: link, class: "image-link ab-fab")
    when :put
      h.put_button(name: "", path: link, class: "image-link ab-fab")
    when :patch
      h.patch_button(name: "", path: link, class: "image-link ab-fab")
    when :delete
      h.destroy_button(name: "", target: link, class: "image-link ab-fab")
    when :remote
      h.link_with_query("", link, class: "image-link ab-fab", remote: true)
    end
  end

  def image_caption_html(image_id, obs_data, identify)
    html = []
    if obs_data[:id].present?
      html = image_observation_caption(html, obs_data, identify)
    end
    html << caption_image_links(image_id)
    h.safe_join(html)
  end

  def image_observation_caption(html, obs_data, identify)
    if identify ||
       (obs_data[:obs].vote_cache.present? && obs_data[:obs].vote_cache <= 0)
      html << h.propose_naming_link(obs_data[:id])
      html << h.content_tag(:span, "&nbsp;".html_safe, class: "mx-2")
      html << h.mark_as_reviewed_toggle(obs_data[:id])
    end
    html << caption_obs_title(obs_data)
    html << h.render(partial: "observations/show/observation",
                     locals: { observation: obs_data[:obs] })
  end

  def caption_image_links(image_id)
    orig_url = Image.url(:original, image_id)
    links = []
    links << original_image_link(orig_url)
    links << " | "
    links << image_exif_link(image_id)
    h.safe_join(links)
  end

  def caption_obs_title(obs_data)
    h.content_tag(:h4, h.show_obs_title(obs: obs_data[:obs]),
                  class: "obs-what", id: "observation_what_#{obs_data[:id]}")
  end

  def original_image_link(orig_url)
    h.link_to(:image_show_original.t, orig_url,
              { class: "lightbox_link", target: "_blank", rel: "noopener" })
  end

  def image_exif_link(image_id)
    h.content_tag(:button, :image_show_exif.t,
                  { class: "btn btn-link px-0 lightbox_link",
                    data: {
                      toggle: "modal",
                      target: "#image_exif_modal",
                      image: image_id
                    } })
  end

  def lb_link(lb_url, lb_id, lb_caption)
    h.link_to("", lb_url,
              class: "glyphicon glyphicon-fullscreen theater-btn",
              data: { lightbox: lb_id, title: lb_caption })
  end

  def img_orig_name(args, image)
    if show_original_name(args, image)
      h.content_tag(:div, image.original_name)
    else
      ""
    end
  end

  def show_original_name(args, image)
    args[:original] && image &&
      image.original_name.present? &&
      (h.check_permission(image) ||
       image.user &&
       image.user.keep_filenames == "keep_and_show")
  end
end
