# frozen_string_literal: true

# Abstract base class for image components.
#
# This component replaces the ImagePresenter class, handling all image
# presentation logic internally through Literal properties and methods.
#
# Provides shared functionality for rendering images with:
# - Lazy loading with aspect ratio preservation
# - Lightbox support
# - Vote sections
# - Stretched links (GET, POST, PUT, PATCH, DELETE)
# - Original filename display
# - Image sizing calculations
#
# Subclasses should implement view_template to define their specific rendering.
class Components::BaseImage < Components::Base
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::LinkTo

  # Type definitions
  Size = _Union(*Image::ALL_SIZES)
  Verb = _Union(:get, :post, :put, :patch, :delete)
  Fit = _Union(:cover, :contain)

  # Core properties
  prop :user, _Nilable(User)
  prop :image, _Union(Image, Integer, nil) do |value|
    case value
    when Image, Integer then value
    when String then value.to_i
    end
  end

  # Display options
  prop :size, Size, default: :small
  prop :votes, _Boolean, default: true
  prop :original, _Boolean, default: false
  prop :is_set, _Boolean, default: true
  prop :full_width, _Boolean, default: false
  prop :notes, String, default: ""
  prop :extra_classes, String, default: ""
  prop :id_prefix, String, default: "interactive_image"

  # Link configuration
  prop :image_link, _Nilable(String), default: nil
  prop :link_method, Verb, default: :get

  # Image fitting and data
  prop :fit, Fit, default: :cover
  prop :data, Hash, default: -> { {} }
  prop :data_sizes, Hash, default: -> { {} }

  # Lightbox and observation context
  prop :obs, _Union(Observation, Hash), default: -> { {} }
  prop :identify, _Boolean, default: false

  # Upload mode (no real image instance)
  prop :upload, _Boolean, default: false

  # This should be implemented by subclasses
  def view_template
    raise(NotImplementedError.new("Subclasses must implement view_template"))
  end

  protected

  # Extract image instance and ID from the image prop
  def extract_image_and_id
    if image.is_a?(Image)
      [image, image.id]
    else
      [nil, image]
    end
  end

  # Build all rendering data needed for image display
  def build_render_data(img_instance, img_id)
    img_urls = fetch_image_urls(img_instance, img_id)
    sizing = calculate_sizing(img_instance)

    {
      img_src: img_urls[size] || "",
      img_class: build_image_classes,
      img_data: build_data_attributes(img_urls),
      img_id: img_id,
      html_id: "#{id_prefix}_#{img_id}",
      proportion: sizing[:proportion],
      width: sizing[:width],
      image_link: image_link || image_path(id: img_id),
      lightbox_data: build_lightbox_data(img_instance, img_id, img_urls)
    }
  end

  def fetch_image_urls(img_instance, img_id)
    return {} if upload

    img_instance&.all_urls || Image.all_urls(img_id)
  end

  def build_image_classes
    class_names("img-fluid ab-fab object-fit-#{fit}", extra_classes)
  end

  def build_data_attributes(img_urls)
    { src: img_urls[size] || "" }.merge(data)
  end

  # Calculate image sizing for lazy load aspect ratio
  def calculate_sizing(img_instance)
    return { proportion: 100, width: false } unless img_instance

    proportion = calculate_proportion(img_instance)
    width_value = calculate_width(img_instance, proportion[:ratio])

    {
      proportion: proportion[:padding],
      width: width_value
    }
  end

  def calculate_proportion(img_instance)
    img_width = BigDecimal(img_instance.width || 100)
    img_height = BigDecimal(img_instance.height || 100)
    img_proportion = img_height / img_width
    img_padding = (img_proportion * 100).to_f.truncate(1)

    # Limit proportion 1.3:1 h/w for thumbnail
    img_padding = "133.33" if img_padding.to_i > 133

    { padding: img_padding, ratio: img_proportion }
  end

  def calculate_width(img_instance, img_proportion)
    return false if full_width

    img_width = BigDecimal(img_instance.width || 100)
    img_height = BigDecimal(img_instance.height || 100)
    size_index = Image::ALL_SIZES_INDEX[size]

    container_width = if img_width > img_height
                        size_index
                      else
                        size_index / img_proportion
                      end
    container_width.to_f.truncate(0)
  end

  # Build lightbox data hash
  def build_lightbox_data(img_instance, img_id, img_urls)
    return nil unless img_instance

    lb_size = user&.image_size&.to_sym || :huge

    {
      url: img_urls[lb_size],
      id: is_set ? "observation-set" : SecureRandom.uuid,
      image: img_instance,
      image_id: img_id,
      obs: obs,
      identify: identify
    }
  end

  # Render lightbox link button
  def render_lightbox_link(lightbox_data)
    return unless lightbox_data

    icon = i(class: "glyphicon glyphicon-fullscreen")
    caption = lightbox_caption_html(lightbox_data)

    a(
      href: lightbox_data[:url],
      class: "theater-btn",
      data: { sub_html: caption }
    ) { icon }
  end

  # Build lightbox caption HTML using LightboxCaption component
  def lightbox_caption_html(lightbox_data)
    return unless lightbox_data

    render(LightboxCaption.new(
             user: user,
             image: lightbox_data[:image],
             image_id: lightbox_data[:image_id],
             obs: lightbox_data[:obs],
             identify: lightbox_data[:identify]
           ))
  end

  # Render vote section for an image using ImageVoteSection component
  def render_image_vote_section(img_instance)
    return unless votes && img_instance

    render(ImageVoteSection.new(user: user, image: img_instance, votes: votes))
  end

  # Render original filename if applicable
  def render_original_filename(img_instance)
    return unless show_original_name?(img_instance)

    div(img_instance.original_name)
  end

  # Check if original filename should be shown
  def show_original_name?(img)
    return false unless original && img && img.original_name.present?

    helpers.permission?(img) ||
      (img.user && img.user.keep_filenames == "keep_and_show")
  end

  # Render stretched link based on link method
  def render_stretched_link(path, method = link_method)
    case method
    when :get
      a(href: path, class: stretched_link_classes)
    when :post, :put, :patch, :delete
      # These require button_to which generates a form with CSRF protection
      unsafe_raw(
        helpers.button_to(
          path,
          method: method,
          class: stretched_link_classes,
          form: { data: { turbo: true } }
        ) { "" }
      )
    end
  end

  # CSS classes for stretched links
  def stretched_link_classes
    "image-link ab-fab stretched-link"
  end

  # Helper to build CSS class names
  def class_names(*classes)
    ActionController::Base.helpers.class_names(*classes)
  end

  # Helper to get safe_join from helpers
  def safe_join(array, separator = nil)
    ApplicationController.helpers.safe_join(array, separator)
  end

  # Access to Rails helpers
  def helpers
    @helpers ||= ApplicationController.helpers
  end
end
