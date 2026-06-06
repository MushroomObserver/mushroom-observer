# frozen_string_literal: true

require("test_helper")
require("rails")

# One-off parity check: the pre-refactor obs-title helper chain
# (now deleted) versus the new `ConsensusNameLink` Phlex view.
# Restores the legacy helper module from git via a hand-rolled
# stub so we don't depend on the deleted source file. Delete this
# test file once the refactor lands and CI is green.
module Views::Controllers::Observations
  class ObsTitleParityTest < ComponentTestCase
    # Verbatim copy of the pre-refactor `ObservationsHelper`
    # methods that built the obs title — just the ones the title
    # chain reached for. (`Observations::OwnerNamingLine` /
    # `ConsensusNameLink` POROs were intermediate steps; the
    # parity here is against the original ERB-era helper code.)
    # Don't `include Rails.application.routes.url_helpers` — that
    # leaks `test_*_url` methods into the test class and trips
    # MiniTest into running them. Use the helpers proxy instead.
    module Legacy
      include ActionView::Helpers::UrlHelper
      include ActionView::Helpers::TagHelper

      def name_path(id:)
        ::Rails.application.routes.url_helpers.name_path(id: id)
      end

      def obs_title_consensus_name_link(name:, user:, show_owner_naming: nil)
        if name.deprecated &&
           (prefer_name = name.best_preferred_synonym).present?
          obs_title_with_preferred_synonym_link(name, prefer_name, user)
        else
          obs_title_name_link(name, show_owner_naming, user)
        end
      end

      def obs_title_with_preferred_synonym_link(name, prefer_name, user)
        if user
          [
            link_to_display_name_brief_authors(
              user, name,
              class: "obs_consensus_deprecated_synonym_link_#{name.id}"
            ),
            obs_consensus_id_flag,
            obs_title_preferred_synonym(user, prefer_name)
          ]
        else
          [
            name.user_display_name_brief_authors(user).t.small_author,
            obs_consensus_id_flag,
            prefer_name.user_display_name_without_authors(user).t
          ]
        end.safe_join(" ")
      end

      def obs_title_preferred_synonym(user, prefer_name)
        tag.span(class: "smaller") do
          [
            "(",
            link_to_display_name_without_authors(
              user, prefer_name,
              class: "obs_preferred_synonym_link_#{prefer_name.id}"
            ),
            ")"
          ].safe_join
        end
      end

      def obs_title_name_link(name, show_owner_naming, user)
        text = [
          if user
            link_to_display_name_brief_authors(
              user, name, class: "obs_consensus_naming_link_#{name.id}"
            )
          else
            name.user_display_name_brief_authors(user).t.small_author
          end
        ]
        text << obs_consensus_id_flag if show_owner_naming
        text.safe_join(" ")
      end

      def obs_consensus_id_flag
        tag.span("(#{:show_observation_site_id.t})",
                 class: "small text-nowrap")
      end

      def link_to_display_name_brief_authors(user, name, **)
        link_to(name.user_display_name_brief_authors(user).t.small_author,
                name_path(id: name.id), **)
      end

      def link_to_display_name_without_authors(user, name, **)
        link_to(name.user_display_name_without_authors(user).t,
                name_path(id: name.id), **)
      end
    end

    include Legacy

    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
    end

    # ---- ConsensusNameLink: current (non-deprecated) name ----------

    def test_current_name_logged_in_matches_legacy
      obs = observations(:minimal_unknown_obs)
      assert_titles_match(obs, user: @user)
    end

    def test_current_name_logged_out_matches_legacy
      # No `<a>` is rendered logged-out — just the textile-only
      # display name with small-author authority.
      obs = observations(:minimal_unknown_obs)
      assert_titles_match(obs, user: nil)
    end

    # ---- ConsensusNameLink: deprecated name -----------------------

    def test_deprecated_name_logged_in_matches_legacy
      obs = deprecated_obs
      assert_titles_match(obs, user: @user)
    end

    def test_deprecated_name_logged_out_matches_legacy
      obs = deprecated_obs
      assert_titles_match(obs, user: nil)
    end

    # ---- ConsensusNameLink: owner-preferred name --------------------

    def test_owner_preferred_with_view_opt_in_matches_legacy
      @user.update!(view_owner_id: true)
      obs = observations(:owner_only_favorite_ne_consensus)
      assert_titles_match(obs, user: @user)
    end

    def test_owner_preferred_without_view_opt_in_matches_legacy
      @user.update!(view_owner_id: false)
      obs = observations(:owner_only_favorite_ne_consensus)
      assert_titles_match(obs, user: @user)
    end

    # ---- OwnerNamingLine -------------------------------------------

    # Phlex `OwnerNamingLine` preserves the `<a class="..."
    # href="...">` attributes on the owner-link — legacy ran the
    # rendered link through textile's sanitizer (`.t` on the
    # `<a>` tag), which silently stripped `class` and `href`.
    # That was a long-standing legacy bug; matching it here would
    # be a regression. We pin the Phlex output to the
    # functionally-correct shape (link + `(Owner Preference)`)
    # instead of bug-compat.
    def test_owner_naming_line_renders_link_when_visible
      @user.update!(view_owner_id: true)
      obs = observations(:owner_only_favorite_ne_consensus)
      owner = ::Observation::NamingConsensus.new(obs).owner_preference

      html = render(OwnerNamingLine.new(observation: obs, user: @user))

      assert_html(html, "a.obs_owner_naming_link_#{owner.id}")
      assert_html(html,
                  "a[href='#{routes.name_path(id: owner.id)}']")
      assert_includes(html, :show_observation_owner_id.l)
    end

    def test_owner_naming_line_blank_when_opted_out
      @user.update!(view_owner_id: false)
      obs = observations(:owner_only_favorite_ne_consensus)
      phlex = render(OwnerNamingLine.new(observation: obs, user: @user))
      assert_equal("", phlex.strip)
    end

    def test_owner_naming_line_blank_when_logged_out
      obs = observations(:owner_only_favorite_ne_consensus)
      phlex = render(OwnerNamingLine.new(observation: obs, user: nil))
      assert_equal("", phlex.strip)
    end

    private

    def deprecated_obs
      @deprecated_obs ||= begin
                            deprecated = names(:lactarius_alpigenes)
                            ::Observation.create!(
                              name: deprecated, user: @user, when: Time.current,
                              where: "Albion, Mendocino Co., California, USA"
                            )
                          end
    end

    # Compare new `ConsensusNameLink` output to the legacy
    # `obs_title_consensus_name_link` chain. Computes the
    # legacy's `show_owner_naming` flag the same way the
    # legacy `Header::TitleHelper` did.
    def assert_titles_match(obs, user:)
      phlex = render(ConsensusNameLink.new(observation: obs, user: user))
      consensus = ::Observation::NamingConsensus.new(obs)
      owner = consensus.owner_preference
      flag = if user&.view_owner_id && owner &&
                owner.id != obs.name.id
               "x"
             end
      legacy = obs_title_consensus_name_link(
        name: obs.name, user: user, show_owner_naming: flag
      )
      assert_html_element_equivalent(
        "<div>#{legacy}</div>", "<div>#{phlex}</div>",
        selector: "div", label: "obs_title_#{obs.id}_user_#{user&.id || "nil"}"
      )
    end
  end
end
