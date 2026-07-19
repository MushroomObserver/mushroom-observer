# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::SpeciesListsPanelTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_no_species_lists_renders_panel_chrome_only
    obs = observations(:imageless_unvouchered_obs)
    assert(obs.species_lists.none?,
           "Need obs fixture obs without species lists")
    html = render(panel_with(obs))

    assert_html(html, "#observation_species_lists")
    assert_no_html(html, "ul",
                   "Expected no list when obs has no species_lists")
  end

  def test_no_species_lists_and_no_owned_lists_renders_nothing
    obs = observations(:imageless_unvouchered_obs)
    user = users(:dick)
    assert(obs.species_lists.none?,
           "Need obs fixture obs without species lists")
    assert(user.species_list_ids.none?,
           "Need user fixture who owns no species lists")

    html = render(
      Views::Controllers::Observations::Show::SpeciesListsPanel.new(
        obs: obs, user: user
      )
    )

    assert_equal("", html)
  end

  def test_no_species_lists_but_user_owns_lists_renders_add_link
    obs = observations(:imageless_unvouchered_obs)
    user = users(:mary)
    assert(obs.species_lists.none?,
           "Need obs fixture obs without species lists")
    assert(user.species_list_ids.any?,
           "Need user fixture who owns at least one species list")

    html = render(
      Views::Controllers::Observations::Show::SpeciesListsPanel.new(
        obs: obs, user: user
      )
    )

    assert_html(
      html,
      "a[href='#{routes.edit_observation_species_lists_path(obs.id)}']",
      text: :show_observation_add_to_species_list.l
    )
    assert_no_html(html, "ul")
  end

  def test_species_lists_renders_bare_heading_and_manage_link
    html = render(panel_with(@obs))

    assert_html(html, "a[href='#{routes.species_list_path(
      @obs.species_lists.first.id
    )}']")
    assert_html(
      html,
      "a[href='#{routes.edit_observation_species_lists_path(@obs.id)}']"
    )
  end

  def test_remove_button_is_icon_only
    stub_admin_mode!
    spl = @obs.species_lists.first
    assert_not_nil(spl, "Need obs fixture with at least one species_list")

    html = render(panel_with(@obs))

    form_selector = "form[action='#{routes.observation_species_list_path(
      id: @obs.id, species_list_id: spl.id, commit: "remove"
    )}']"
    assert_html(html, "#{form_selector} button span.glyphicon-remove-circle")
    assert_html(html, "#{form_selector} button span.sr-only",
                text: :remove.ti)
  end

  private

  def routes
    Rails.application.routes.url_helpers
  end

  def panel_with(obs)
    Views::Controllers::Observations::Show::SpeciesListsPanel.new(
      obs: obs, user: @user
    )
  end
end
