# frozen_string_literal: true

# Gather details for items in matrix-style ndex pages.
class ThumbnailPresenter < BasePresenter
  attr_accessor \
    :image,            # image instance or id
    :proportion,       # sizer proportion, to size img correctly pre-lazyload
    :width,            # image container width (to be removed soon)
    :img_lazy_tag,     # thumbnail image tag with placeholder (src lazy-loaded)
    :img_tag,          # thumbnail image tag with real src (when no lazy-load)
    :stretched_link,   # image overlay stretched-link (may be link/button/form)
    :lightbox_link,    # contains data passed to lightbox (incl. caption)
    :vote_section,     # show votes? boolean
    :image_filename    # original image filename (maybe none)

  def initialize(image, view, args = {})
    super

    # TODO: pass a matrix_box arg so we know whether to constrain width or not.

    # Sometimes it's prohibitive to do the extra join to images table,
    # so we only have image_id. It's still possible to render the image with
    # nothing but the image_id. (But not votes, original name, etc.)
    image, image_id = image.is_a?(Image) ? [image, image.id] : [nil, image]

    default_args = {
      size: :small,
      notes: "",
      data: {},
      data_sizes: {},
      extra_classes: false,
      obs_data: {}, # used in lightbox caption
      identify: false,
      image_link: h.image_path(image_id), # to ImagesController#show
      link_method: :get,
      votes: true,
      is_set: true
    }
    args = default_args.merge(args)
    img_urls = Image.all_urls(image_id)

    args_to_presenter(image, img_urls, args)
    sizing_info_to_presenter(image, args)
    lightbox_args_to_presenter(image_id, img_urls, args)
  end

  def args_to_presenter(image, img_urls, args)
    # Store these urls once, since they are computed
    img_src = img_urls[args[:size]]
    # img_srcset = thumbnail_srcset(img_urls[:small], img_urls[:medium],
    #                               img_urls[:large], img_urls[:huge])
    # img_sizes = args[:data_sizes] || thumbnail_srcset_sizes
    img_class = "img-fluid ab-fab object-fit-cover"
    img_class += " #{args[:extra_classes]}" if args[:extra_classes]

    # <img> data attributes. Account for possible data-confirm, etc
    img_data = {
      src: img_src
      #   srcset: img_srcset,
      #   sizes: img_sizes
    }.merge(args[:data])

    # <img> attributes
    html_options_lazy = {
      alt: args[:notes],
      class: "#{img_class} lazy",
      data: img_data
    }

    html_options_noscript = {
      alt: args[:notes],
      class: "#{img_class} img-noscript"
      #   srcset: img_srcset,
      #   sizes: img_sizes
    }

    self.image = image || nil
    self.img_tag_lazy = h.image_tag("placeholder.svg", html_options_lazy)
    self.img_tag = h.image_tag(img_src, html_options_noscript)
    self.stretched_link = image_link_html(args[:image_link], args[:link_method])
    self.vote_section = vote_section_html(args, image)
    self.image_filename = image_orig_name(args, image)
  end

  def sizing_info_to_presenter(image, args)
    # For lazy load content pre-sizing: set img width and height, using
    # `style= "padding-bottom: proportion%;"`
    # NOTE: requires image, or defaults to 1:1. Be sure it works in all cases
    img_width = image&.width ? BigDecimal(image&.width) : 100
    img_height = image&.height ? BigDecimal(image&.height) : 100
    img_proportion = BigDecimal(img_height / img_width)
    # Limit proportion 2:1 h/w for thumbnail
    # img_proportion = "200" if img_proportion.to_i > 200 # default for tall

    # Constrain width to currently expected dimensions for img size (not layout)
    # NOTE: can get rid of self.width if switching to full-width images
    size = Image.all_sizes_index[args[:size]]
    container_width = img_width > img_height ? size : size / img_proportion

    self.proportion = (img_proportion * 100).to_f.truncate(1)
    self.width = container_width.to_f.truncate(0)
  end

  def lightbox_args_to_presenter(image_id, img_urls, args)
    # The src size appearing in the lightbox is a user pref
    lb_size = User.current&.image_size&.to_sym || :huge
    lb_url = img_urls[lb_size]
    lb_id = args[:is_set] ? "observation-set" : SecureRandom.uuid
    lb_caption = lightbox_caption_html(image_id,
                                       args[:obs_data], args[:identify])

    self.lightbox_link = lb_link(lb_url, lb_id, lb_caption)
  end

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

  # NOTE: `stretched_link` might be a link to #show_obs or #show_image,
  # but it may also be a button/input (with params[:img_id]) sending to
  # #reuse_image or #remove_image ...or any other clickable element. Elements
  # use .ab-fab instead of .stretched-link to keep .theater-btn clickable
  def image_link_html(path, link_method)
    case link_method
    when :get
      h.link_with_query("", path, class: image_link_classes)
    when :post
      h.post_button(name: "", path: path, class: image_link_classes)
    when :put
      h.put_button(name: "", path: path, class: image_link_classes)
    when :patch
      h.patch_button(name: "", path: path, class: image_link_classes)
    when :delete
      h.destroy_button(name: "", target: path, class: image_link_classes)
    when :remote
      h.link_with_query("", path, class: image_link_classes, remote: true)
    end
  end

  def image_link_classes
    "image-link stretched-link"
  end

  def lightbox_caption_html(image_id, obs_data, identify)
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

  def caption_obs_title(obs_data)
    h.content_tag(:h4, h.show_obs_title(obs: obs_data[:obs]),
                  class: "obs-what", id: "observation_what_#{obs_data[:id]}")
  end

  def caption_image_links(image_id)
    links = []
    links << h.original_image_link(image_id, "lightbox_link")
    links << " | "
    links << h.image_exif_link(image_id, "lightbox_link")
    h.content_tag(:div, class: "caption-image-links my-3") do
      h.safe_join(links)
    end
  end

  def lb_link(lb_url, lb_id, lb_caption)
    icon = h.content_tag(:i, "", class: "glyphicon glyphicon-fullscreen")
    h.link_to(icon, lb_url,
              class: "theater-btn",
              data: { lightbox: lb_id, title: lb_caption })
  end

  def vote_section_html(args, image)
    return "" unless args[:votes] && image && User.current

    h.content_tag(:div, "", class: "vote-section") do
      h.render(partial: "shared/image_vote_links",
               locals: { image: image })
    end
  end

  def image_orig_name(args, image)
    return "" unless image && show_original_name(args, image)

    h.content_tag(:div, image.original_name, class: "mt-3")
  end

  def show_original_name(args, image)
    args[:original] && image &&
      image.original_name.present? &&
      (h.check_permission(image) ||
       image.user &&
       image.user.keep_filenames == "keep_and_show")
  end
end
