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
# Used by `Views::FullPageBase#add_owner_naming(observation:,
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

      # Render the link inline (not via `DisplayNameBriefAuthorsLink`)
      # because the owner-naming line wants the author text at the
      # same size as the species name — the obs-show title chain
      # uses `.small_author` for the author bit, but on this line
      # the legacy behavior (matched on production) keeps everything
      # at the normal size.
      Link(type: :get, name: owner_name.text_name,
           target: name_path(id: owner_name.id),
           class: "obs_owner_naming_link_#{owner_name.id}") do
        trusted_html(owner_name.display_name_brief_authors(@user).t)
      end
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
