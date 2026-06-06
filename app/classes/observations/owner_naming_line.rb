# frozen_string_literal: true

# The observer's-preferred-naming title line. Returns an
# html-safe string suitable for `add_owner_naming(...)`, or
# `nil` when the line shouldn't be shown:
#
# - viewer didn't opt in to seeing owner IDs
#   (`user.view_owner_id` is false), or
# - the observation's owner hasn't proposed a different name
#   than the current consensus, or
# - there's no viewer at all.
#
# Used by `Views::Controllers::Observations::Show` and
# `Views::Controllers::Observations::Namings::Suggestions::Show`
# (the AI-suggestions page). Extracted from
# `ObservationsHelper#owner_naming_line` so both views share
# one definition.
class Observations::OwnerNamingLine
  class << self
    def for(observation:, user:)
      new(observation: observation, user: user).call
    end
  end

  def initialize(observation:, user:)
    @observation = observation
    @user = user
  end

  def call
    return unless visible?

    [link.t, "(#{:show_observation_owner_id.l})"].safe_join(" ")
  end

  private

  def visible?
    @user&.view_owner_id && owner_name &&
      owner_name.id != @observation.name.id
  end

  def owner_name
    @owner_name ||= ::Observation::NamingConsensus.new(@observation).
                    owner_preference
  end

  def link
    ::Observations::DisplayNameBriefAuthorsLink.for(
      user: @user, name: owner_name,
      class: "obs_owner_naming_link_#{owner_name.id}"
    )
  end
end
