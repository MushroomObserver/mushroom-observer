# frozen_string_literal: true

# Per-matrix-box carousel slide. Subclass of
# `Components::Carousel::Item` (the shared image-slide DOM) with
# defaults tuned for the per-box context: `:medium` (640px) instead
# of `:large` (960px) so an N-box index doesn't ship N·image-bytes
# at full resolution, and `original: false` so the lightbox is the
# explicit path to the full-size view.
class Components::Matrix::Carousel::Item < Components::Carousel::Item
  def initialize(**props)
    props[:size] ||= :medium
    props[:original] = false unless props.key?(:original)
    super
  end
end
