# frozen_string_literal: true

# Single entry-point dispatcher for shared, `Observation`-domain-specific
# display fragments with callers in more than one namespace (a View and
# a Component, or Components in different subtrees) — too specific to be
# a generic UI primitive, but not scoped to one controller either. See
# ".claude/rules/phlex_reference.md" for the general pattern.
#
#   ObservationFragment(type: :who, obs: @obs, user: @user)
class Components::ObservationFragment < Components::Base
  DISPATCH = {
    lightbox_title: :LightboxTitle,
    mark_as_reviewed_toggle: :MarkAsReviewedToggle,
    when: :When,
    where: :Where,
    where_gps: :WhereGps,
    who: :Who
  }.freeze

  def self.new(**kwargs, &block)
    type_sym = kwargs[:type]&.to_sym
    if (klass_name = DISPATCH[type_sym])
      kwargs.delete(:type)
      return const_get(klass_name).new(**kwargs, &block)
    end

    raise(ArgumentError.new(
            "Unknown ObservationFragment type: #{kwargs[:type].inspect}. " \
            "Valid types: #{DISPATCH.keys.join(", ")}."
          ))
  end
end
