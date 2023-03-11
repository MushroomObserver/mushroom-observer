# frozen_string_literal: true

# Gather details for items in matrix-style ndex pages.
class ThumbnailPresenter < BasePresenter
  attr_accessor \
    :image,             # image instance or id
    :img_src,           # img src for noscript image
    :proportion,        # sizer proportion, to size img correctly pre-lazyload
    :width,             # image container width (to be removed soon)
    :options_lazy,      # html_options for placeholder (src lazy-loaded)
    :options_noscript,  # html_options for noscript (when no lazy-load)
    :image_link,        # image stretched-link url (may be link/button/form)
    :image_link_method, # needed for helper
    :lightbox_data,     # contains data passed to lightbox (incl. caption)
    :votes,             # show votes? boolean
    :original           # show original image filename? (boolean)

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
      original: false,
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
    self.img_src = img_src
    self.options_lazy = html_options_lazy
    self.options_noscript = html_options_noscript
    self.image_link = args[:image_link]
    self.image_link_method = args[:link_method]
    self.votes = args[:votes]
    self.original = args[:original]
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

    self.lightbox_data = {
      url: img_urls[lb_size],
      id: args[:is_set] ? "observation-set" : SecureRandom.uuid,
      image_id: image_id,
      obs_data: args[:obs_data],
      identify: args[:identify]
    }
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
end
