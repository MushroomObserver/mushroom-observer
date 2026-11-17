# frozen_string_literal: true

# Single entry-point dispatcher for Bootstrap `.badge` components.
# Pass `variant:` to route to the matching subclass.
#
#   Badge(variant: :sibling_marker, number: 2, observation_id: 663635)
class Components::Badge < Components::Base
  DISPATCH = { sibling_marker: :SiblingMarker }.freeze

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
