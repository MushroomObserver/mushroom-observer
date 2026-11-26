# frozen_string_literal: true

# Single entry-point dispatcher for Bootstrap `.badge` components.
# Pass `variant:` to route to the matching subclass.
#
#   Badge(variant: :id, object: @project, size: :sm)
class Components::Badge < Components::Base
  DISPATCH = { count: :Count, id: :ID,
               sibling_marker: :SiblingMarker,
               collapse_toggle: :CollapseToggle }.freeze

  # Shared by any Badge variant rendering a `.badge-id`-sized badge
  # (Badge::ID, Badge::CollapseToggle) -- `.badge-id` itself has no
  # inherent font-size, so callers state a size explicitly:
  #   :xl -- project/species-list table row title badges
  #   :lg -- copy-to-clipboard external-site record id, Matching
  #          Observations panel row ids
  #   :md -- grid box title and other index-row id badges
  #   :sm -- sitting next to a large page-title heading
  # Each maps regularly to "badge-#{size}" -- no irregular Bootstrap
  # naming to account for here (unlike Button::Styling's BTN_SIZES).
  SIZES = [:xl, :lg, :md, :sm].freeze

  def self.size_class(size)
    "badge-#{size}"
  end

  def self.new(**kwargs, &block)
    variant_sym = kwargs[:variant]&.to_sym
    if (klass_name = DISPATCH[variant_sym])
      kwargs.delete(:variant)
      return const_get(klass_name).new(**kwargs, &block)
    end

    # Reached a second time, on the way back in through a subclass's
    # inherited `self.new` -- `:variant` is already deleted by then,
    # so this only raises when a caller's `variant:` didn't match.
    if kwargs.key?(:variant)
      raise(ArgumentError.new(
              "Unknown Badge variant: #{kwargs[:variant].inspect}. " \
              "Valid variants: #{DISPATCH.keys.join(", ")}."
            ))
    end

    super
  end
end
