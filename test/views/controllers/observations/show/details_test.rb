# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::DetailsTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_panel_id
    html = render(panel_with(@obs))

    assert_html(html, "#observation_details")
  end

  # "Shared with" badges: a second .panel-body (with border-bottom to
  # separate it from the main details body) when the obs has any
  # external_link (own or sibling) or an eligible site to add one,
  # none at all otherwise. ExternalLinksTest covers the component's
  # own content in isolation; this covers Details' wiring.
  def test_renders_external_links_body_for_obs_with_external_link
    obs = observations(:imported_inat_obs)

    html = render(panel_with(obs))

    assert_html(html, "#observation_details > .panel-body.border-bottom " \
                      "#observation_external_links")
  end

  # Badges are informational, not gated on being logged in -- an
  # anonymous viewer should still see that the obs was shared on
  # another site.
  def test_renders_external_links_body_for_logged_out_viewer
    obs = observations(:imported_inat_obs)

    html = render(panel_with(obs, nil))

    assert_html(html, "#observation_details > .panel-body.border-bottom " \
                      "#observation_external_links")
  end

  def test_does_not_render_external_links_body_when_nothing_to_show
    assert_empty(@obs.external_links)

    html = render(panel_with(@obs))

    assert_no_html(html, ".border-bottom")
    assert_no_html(html, "#observation_external_links")
  end

  # --- Collector / Entered by (#4211) ---

  def test_who_collector_is_creator_no_entered_by
    @obs.collector = @obs.user.unique_text_name
    @obs.collector_user_id = @obs.user_id

    html = render(panel_with(@obs))
    text = who_text(html)

    assert_includes(text, :COLLECTOR.l)
    assert_html(html,
                "#observation_who a[href='#{routes.user_path(@obs.user_id)}']")
    assert_not_includes(text, :ENTERED_BY.l)
  end

  def test_who_free_text_collector_shows_entered_by
    @obs.collector = "Jane Forager"
    @obs.collector_user_id = nil

    text = who_text(render(panel_with(@obs)))

    assert_includes(text, "Jane Forager")
    assert_includes(text, :ENTERED_BY.l)
  end

  def test_who_collector_user_links_and_entered_by
    # A collector who is not the obs owner (detailed_unknown_obs is mary's)
    collector = users(:katrina)
    @obs.collector_user = collector
    @obs.collector = collector.unique_text_name

    html = render(panel_with(@obs))

    assert_html(
      html, "#observation_who a[href='#{routes.user_path(collector.id)}']"
    )
    assert_includes(who_text(html), :ENTERED_BY.l)
  end

  def test_who_plain_text_when_logged_out
    @obs.collector = @obs.user.unique_text_name
    @obs.collector_user_id = @obs.user_id

    text = who_text(render(panel_with(@obs, nil)))

    assert_includes(text, @obs.user.unique_text_name)
  end

  def test_who_collector_unrecorded_suppresses_collector_line
    obs = observations(:minimal_unknown_obs)
    assert(obs.field_slip_id.present?, "fixture should have a field slip")
    obs.collector = nil
    obs.collector_user_id = nil

    text = who_text(render(panel_with(obs)))

    assert_not_includes(text, :COLLECTOR.l)
    assert_includes(text, :ENTERED_BY.l)
    assert_includes(text, obs.user.unique_text_name)
  end

  def test_who_send_question_link_when_allowed
    obs = observations(:owner_accepts_general_questions)
    viewer = users(:rolf)
    assert_not_equal(obs.user, viewer)

    html = render(panel_with(obs, viewer))

    # The "[" ... "]" send-question modal link rides the who line.
    assert_html(html, "#observation_who a[data-controller='modal-toggle']")
  end

  private

  def who_text(html)
    Nokogiri::HTML.fragment(html).at_css("#observation_who").text
  end

  def panel_with(obs, user = @user)
    Views::Controllers::Observations::Show::Details.new(
      obs: obs, user: user, sites: [], siblings: []
    )
  end
end
