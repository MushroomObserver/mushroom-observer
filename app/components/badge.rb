# frozen_string_literal: true

# Single entry-point dispatcher for Bootstrap `.badge` components.
# Pass `type:` to route to the matching subclass.
#
#   Badge(type: :id, object: @project, size: :sm)
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

  # Bootstrap's theme-color keys -- each has a native `.badge-#{color}`
  # class (see _variables.scss's $theme-colors).
  COLORS = [:primary, :secondary, :success, :info, :warning, :danger,
            :light, :dark].freeze

  def self.size_class(size)
    "badge-#{size}"
  end

  def self.new(**kwargs, &block)
    type_sym = kwargs[:type]&.to_sym
    if (klass_name = DISPATCH[type_sym])
      kwargs.delete(:type)
      return const_get(klass_name).new(**kwargs, &block)
    end

    # Reached a second time, on the way back in through a subclass's
    # inherited `self.new` -- `:type` is already deleted by then, so
    # this only raises when a caller's `type:` didn't match.
    if kwargs.key?(:type)
      raise(ArgumentError.new(
              "Unknown Badge type: #{kwargs[:type].inspect}. " \
              "Valid types: #{DISPATCH.keys.join(", ")}."
            ))
    end

    super
  end

  # Background/text color, via Bootstrap's native `.badge-#{color}`
  # classes -- nil means no color class (the caller's CSS decides).
  prop :variant, _Nilable(_Union(*COLORS)), default: nil
end
