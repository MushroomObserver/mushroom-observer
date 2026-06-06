# frozen_string_literal: true

# The observer's-preferred-naming title line. Renders nothing
# when the line shouldn't be shown:
#
# - viewer didn't opt in to seeing owner IDs
#   (`user.view_owner_id` is false), or
# - the observation's owner hasn't proposed a different name
#   than the current consensus, or
# - there's no viewer at all.
#
# Used by `Header::TitleHelper#add_owner_naming(observation:,
# user:)` (rendered into `content_for(:owner_naming)`), and
# consulted by `ConsensusNameLink` to decide whether to append a
# `(Site ID)` flag to the consensus name.
module Views::Controllers::Observations
  class OwnerNamingLine < Views::Base
    # Convenience: matches `visible?` without instantiating
    # boilerplate at the callsite.
    def self.visible_for?(observation:, user:)
      new(observation: observation, user: user).visible?
    end

    prop :observation, ::Observation
    prop :user, _Nilable(::User), default: nil

    def view_template
      return unless visible?

      render(DisplayNameBriefAuthorsLink.new(
               name: owner_name, user: @user,
               class: "obs_owner_naming_link_#{owner_name.id}"
             ))
      whitespace
      plain("(#{:show_observation_owner_id.l})")
    end

    def visible?
      @user&.view_owner_id && owner_name &&
        owner_name.id != @observation.name.id
    end

    private

    def owner_name
      @owner_name ||= ::Observation::NamingConsensus.new(@observation).
                      owner_preference
    end
  end
end
