# frozen_string_literal: true

require("test_helper")

# Collector / Entered-by identity lines (#4211), shared by the obs show
# Details panel and the lightbox caption. Details/Caption tests cover
# their wrapper wiring; branch coverage of the line contents lives here.
class ObservationWhoTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_collector_is_creator_no_entered_by
    @obs.collector = @obs.user.unique_text_name
    @obs.collector_user_id = @obs.user_id

    html = render_who(@obs)
    text = who_text(html)

    assert_includes(text, :collector.ti)
    assert_html(html, "a[href='#{routes.user_path(@obs.user_id)}']")
    assert_not_includes(text, :entered_by.ti)
  end

  def test_free_text_collector_shows_entered_by
    @obs.collector = "Jane Forager"
    @obs.collector_user_id = nil

    text = who_text(render_who(@obs))

    assert_includes(text, "Jane Forager")
    assert_includes(text, :entered_by.ti)
  end

  def test_collector_user_links_and_entered_by
    # A collector who is not the obs owner (detailed_unknown_obs is
    # mary's).
    collector = users(:katrina)
    @obs.collector_user = collector
    @obs.collector = collector.unique_text_name

    html = render_who(@obs)

    assert_html(html, "a[href='#{routes.user_path(collector.id)}']")
    assert_includes(who_text(html), :entered_by.ti)
  end

  def test_plain_text_when_logged_out
    @obs.collector = @obs.user.unique_text_name
    @obs.collector_user_id = @obs.user_id

    html = render_who(@obs, user: nil)

    assert_includes(who_text(html), @obs.user.unique_text_name)
    assert_no_html(html, "a")
  end

  def test_collector_unrecorded_suppresses_collector_line
    obs = observations(:minimal_unknown_obs)
    assert(obs.field_slip_id.present?, "fixture should have a field slip")
    obs.collector = nil
    obs.collector_user_id = nil

    text = who_text(render_who(obs))

    assert_not_includes(text, :collector.ti)
    assert_includes(text, :entered_by.ti)
    assert_includes(text, obs.user.unique_text_name)
  end

  def test_send_question_link_when_allowed
    obs = observations(:owner_accepts_general_questions)
    assert_not_equal(obs.user, @user)

    html = render_who(obs)

    assert_html(html, "a[data-controller='modal-toggle']" \
                      "[href='#{routes.new_question_for_observation_path(
                        obs.id
                      )}']")
  end

  def test_no_send_question_link_for_own_observation
    obs = observations(:owner_accepts_general_questions)

    html = render_who(obs, user: obs.user)

    assert_no_html(html, "a[data-controller='modal-toggle']")
  end

  private

  def who_text(html)
    Nokogiri::HTML.fragment(html).text
  end

  def render_who(obs, user: @user)
    render(Components::ObservationWho.new(obs: obs, user: user))
  end
end
