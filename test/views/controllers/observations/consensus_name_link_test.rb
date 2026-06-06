# frozen_string_literal: true

require("test_helper")

# Pins the rendered markup of the obs-show title zone — the
# `ConsensusNameLink` Phlex view that replaced the legacy
# `ObservationsHelper#obs_title_consensus_name_link` chain.
#
# Covers four orthogonal modes:
#
# - logged-in vs logged-out viewer (logged-out emits no `<a>` —
#   just the textile-only display name with small-author
#   authority)
# - current consensus name vs deprecated name with a preferred
#   synonym
# - viewer has owner-id preference (`view_owner_id`) on vs off
# - observation's owner-preferred name differs from the consensus
#   vs matches it
#
# The four-mode matrix is what controls whether `(Site ID)` and/or
# `(<preferred synonym>)` decorations append to the consensus
# link.
module Views::Controllers::Observations
  class ConsensusNameLinkTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
    end

    # ---- current consensus name -----------------------------------

    def test_current_name_logged_in_renders_consensus_link_only
      obs = observations(:minimal_unknown_obs)

      html = render(ConsensusNameLink.new(observation: obs, user: @user))

      assert_html(html, "a.obs_consensus_naming_link_#{obs.name.id}")
      assert_html(html, "a[href='#{routes.name_path(id: obs.name.id)}']")
      # No deprecated-synonym fork, no `(Site ID)` flag (no owner
      # preference here).
      assert_no_html(html, "a.obs_consensus_deprecated_synonym_link_" \
                           "#{obs.name.id}")
      assert_no_html(html, "span.small.text-nowrap")
    end

    def test_current_name_logged_out_renders_textile_name_only
      obs = observations(:minimal_unknown_obs)

      html = render(ConsensusNameLink.new(observation: obs, user: nil))

      # No `<a>` — just the textile-rendered display name.
      assert_no_html(html, "a")
      assert_includes(html, obs.name.user_display_name_brief_authors(nil).t)
    end

    # ---- deprecated consensus name --------------------------------

    def test_deprecated_name_logged_in_renders_link_flag_and_synonym
      obs = deprecated_obs
      preferred = obs.name.best_preferred_synonym

      html = render(ConsensusNameLink.new(observation: obs, user: @user))

      assert_html(html,
                  "a.obs_consensus_deprecated_synonym_link_#{obs.name.id}")
      assert_html(html, "span.small.text-nowrap",
                  text: :show_observation_site_id.t.as_displayed)
      assert_html(html,
                  "span.smaller a.obs_preferred_synonym_link_#{preferred.id}")
    end

    def test_deprecated_name_logged_out_renders_textile_only_chain
      obs = deprecated_obs
      preferred = obs.name.best_preferred_synonym

      html = render(ConsensusNameLink.new(observation: obs, user: nil))

      # No `<a>` tags at all logged-out — just textile-rendered
      # name + flag + textile-rendered preferred synonym.
      assert_no_html(html, "a")
      assert_html(html, "span.small.text-nowrap",
                  text: :show_observation_site_id.t.as_displayed)
      assert_includes(html, preferred.user_display_name_without_authors(nil).t)
    end

    # ---- owner-preferred name ------------------------------------

    def test_owner_preference_with_view_opt_in_appends_site_id_flag
      @user.update!(view_owner_id: true)
      obs = observations(:owner_only_favorite_ne_consensus)

      html = render(ConsensusNameLink.new(observation: obs, user: @user))

      assert_html(html, "a.obs_consensus_naming_link_#{obs.name.id}")
      assert_html(html, "span.small.text-nowrap",
                  text: :show_observation_site_id.t.as_displayed)
    end

    def test_owner_preference_without_view_opt_in_omits_flag
      @user.update!(view_owner_id: false)
      obs = observations(:owner_only_favorite_ne_consensus)

      html = render(ConsensusNameLink.new(observation: obs, user: @user))

      assert_html(html, "a.obs_consensus_naming_link_#{obs.name.id}")
      assert_no_html(html, "span.small.text-nowrap")
    end

    def test_owner_preference_with_view_opt_in_logged_out_omits_flag
      # Logged-out viewer can't have `view_owner_id` true (no user
      # at all) — the flag stays off regardless of the obs's
      # owner-preference state.
      obs = observations(:owner_only_favorite_ne_consensus)

      html = render(ConsensusNameLink.new(observation: obs, user: nil))

      assert_no_html(html, "a")
      assert_no_html(html, "span.small.text-nowrap")
    end

    private

    def deprecated_obs
      @deprecated_obs ||= begin
                            deprecated = names(:lactarius_alpigenes)
                            assert(deprecated.deprecated, "fixture sanity")
                            assert_not_nil(deprecated.best_preferred_synonym,
                                           "fixture sanity")
                            ::Observation.create!(
                              name: deprecated, user: @user, when: Time.current,
                              where: "Albion, Mendocino Co., California, USA"
                            )
                          end
    end
  end
end
