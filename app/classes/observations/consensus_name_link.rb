# frozen_string_literal: true

# The "name portion" of an observation's page title — produces
# the consensus-name link, plus any decorations needed when the
# name is deprecated (an `(Observation Site ID)` flag and the
# preferred-synonym link) or when an owner-preferred name exists
# (the same site-id flag, used to differentiate which line is
# which).
#
# Used by `Header::TitleHelper#observation_show_title` for the
# obs page title; via that for the obs-show and suggestions
# pages.
#
# Extracted from `ObservationsHelper` —
# `obs_title_consensus_name_link` +
# `obs_title_with_preferred_synonym_link` +
# `obs_title_name_link` + `obs_title_preferred_synonym` +
# `obs_consensus_id_flag` (the whole title-builder chain).
class Observations::ConsensusNameLink
  class << self
    def for(name:, user:, show_owner_naming: nil)
      new(name: name, user: user,
          show_owner_naming: show_owner_naming).call
    end
  end

  def initialize(name:, user:, show_owner_naming: nil)
    @name = name
    @user = user
    @show_owner_naming = show_owner_naming
  end

  def call
    if @name.deprecated && preferred_synonym
      with_preferred_synonym_link
    else
      name_link
    end
  end

  private

  def preferred_synonym
    @preferred_synonym ||= @name.best_preferred_synonym.presence
  end

  # Deprecated-name branch: render `<deprecated_name> (Site ID)
  # (<preferred_synonym>)`. Logged-out users get the textile-only
  # forms; logged-in users get clickable `<a>` links via the
  # `DisplayName*Link` POROs.
  def with_preferred_synonym_link
    parts = @user ? logged_in_synonym_parts : logged_out_synonym_parts
    parts.safe_join(" ")
  end

  def logged_in_synonym_parts
    [
      ::Observations::DisplayNameBriefAuthorsLink.for(
        user: @user, name: @name,
        class: "obs_consensus_deprecated_synonym_link_#{@name.id}"
      ),
      site_id_flag,
      preferred_synonym_span
    ]
  end

  def logged_out_synonym_parts
    [
      @name.user_display_name_brief_authors(@user).t.small_author,
      site_id_flag,
      preferred_synonym.user_display_name_without_authors(@user).t
    ]
  end

  def preferred_synonym_span
    ::ApplicationController.helpers.tag.span(class: "smaller") do
      [
        "(",
        ::Observations::DisplayNameWithoutAuthorsLink.for(
          user: @user, name: preferred_synonym,
          class: "obs_preferred_synonym_link_#{preferred_synonym.id}"
        ),
        ")"
      ].safe_join
    end
  end

  # Non-deprecated branch: just the consensus name link, plus a
  # site-id flag iff the owner preferred a different name (so the
  # viewer can tell which line is the site consensus vs the owner
  # preference).
  def name_link
    parts = [name_link_text]
    parts << site_id_flag if @show_owner_naming
    parts.safe_join(" ")
  end

  def name_link_text
    if @user
      ::Observations::DisplayNameBriefAuthorsLink.for(
        user: @user, name: @name,
        class: "obs_consensus_naming_link_#{@name.id}"
      )
    else
      @name.user_display_name_brief_authors(@user).t.small_author
    end
  end

  # The "(Site ID)" decoration that differentiates a consensus
  # name from an adjacent owner-preferred name.
  def site_id_flag
    ::ApplicationController.helpers.tag.span(
      "(#{:show_observation_site_id.t})", class: "small text-nowrap"
    )
  end
end
