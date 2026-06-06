# frozen_string_literal: true

# The "name portion" of an observation's page title — produces
# the consensus-name link, plus any decorations needed when the
# name is deprecated (a `(Site ID)` flag and the
# preferred-synonym link) or when an owner-preferred name will
# be shown elsewhere on the page (the same site-id flag, used
# to differentiate which line is which).
#
# Used by `Header::TitleHelper#observation_page_title` for the
# obs page title; via that for the obs-show and suggestions
# pages.
module Views::Controllers::Observations
  class ConsensusNameLink < Views::Base
    prop :observation, ::Observation
    prop :user, _Nilable(::User), default: nil

    def view_template
      if name.deprecated && preferred_synonym
        render_with_preferred_synonym
      else
        render_name_link
      end
    end

    private

    def name
      @observation.name
    end

    def preferred_synonym
      @preferred_synonym ||= name.best_preferred_synonym.presence
    end

    # Same condition `OwnerNamingLine` checks before rendering
    # itself elsewhere on the page — if it will show, append a
    # `(Site ID)` flag here so the two lines are distinguishable.
    def show_owner_naming?
      OwnerNamingLine.visible_for?(observation: @observation, user: @user)
    end

    # Deprecated-name branch: `<deprecated_name> (Site ID)
    # (<preferred_synonym>)`. Logged-out users get the
    # textile-only forms; logged-in users get clickable `<a>`
    # links.
    def render_with_preferred_synonym
      if @user
        render_deprecated_link
        whitespace
        render_site_id_flag
        whitespace
        render_preferred_synonym_span
      else
        render_logged_out_deprecated
      end
    end

    def render_deprecated_link
      render(DisplayNameBriefAuthorsLink.new(
               name: name, user: @user,
               class: "obs_consensus_deprecated_synonym_link_#{name.id}"
             ))
    end

    def render_preferred_synonym_span
      # `obs-preferred-synonym` is the contract class — tests assert
      # presence/absence via it. `smaller` is cosmetic.
      span(class: "smaller obs-preferred-synonym") do
        plain("(")
        render(DisplayNameWithoutAuthorsLink.new(
                 name: preferred_synonym, user: @user,
                 class: "obs_preferred_synonym_link_#{preferred_synonym.id}"
               ))
        plain(")")
      end
    end

    def render_logged_out_deprecated
      trusted_html(name.user_display_name_brief_authors(@user).
                   t.small_author)
      whitespace
      render_site_id_flag
      whitespace
      trusted_html(preferred_synonym.user_display_name_without_authors(@user).t)
    end

    # Non-deprecated branch: just the consensus name link, plus a
    # site-id flag iff the owner preferred a different name.
    def render_name_link
      if @user
        render(DisplayNameBriefAuthorsLink.new(
                 name: name, user: @user,
                 class: "obs_consensus_naming_link_#{name.id}"
               ))
      else
        trusted_html(name.user_display_name_brief_authors(@user).
                     t.small_author)
      end
      return unless show_owner_naming?

      whitespace
      render_site_id_flag
    end

    # The "(Site ID)" decoration that differentiates a consensus
    # name from an adjacent owner-preferred name. `obs-site-id-flag`
    # is the contract class for tests; `small text-nowrap` is
    # cosmetic.
    def render_site_id_flag
      span(class: "small text-nowrap obs-site-id-flag") do
        plain("(#{:show_observation_site_id.t})")
      end
    end
  end
end
