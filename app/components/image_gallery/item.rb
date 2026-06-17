# frozen_string_literal: true

# Show-page image-gallery slide. Subclass of
# `Components::Carousel::Item` (the shared image-slide DOM) with
# defaults tuned for the full-resolution Panel view: `:large` + lazy
# `:original` full-size for the lightbox link, `carousel-image`
# extra-class for slide-specific CSS, `:contain` fit.
class Components::ImageGallery::Item < Components::Carousel::Item
  def initialize(**props)
    props[:size] ||= :large
    props[:original] = true unless props.key?(:original)
    super
  end
end
