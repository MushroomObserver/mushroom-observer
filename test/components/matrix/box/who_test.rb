# frozen_string_literal: true

require("test_helper")

class MatrixBoxWhoTest < ComponentTestCase
  def setup
    super
    # detailed_unknown_obs is mary's.
    @obs = observations(:detailed_unknown_obs)
  end

  def test_collector_user_links_to_collector
    @obs.collector_user = users(:katrina)

    html = render_who

    collector_path = routes.user_path(@obs.collector_user_id)
    assert_html(html, ".rss-who a[href='#{collector_path}']")
    assert_no_html(html, "a[href='#{routes.user_path(@obs.user_id)}']")
  end

  def test_inat_login_links_to_inat_profile
    @obs.assign_attributes(collector: "outdoor_dad", collector_user_id: nil,
                           reflected_at: Time.zone.now)

    html = render_who

    assert_html(html,
                ".rss-who a[href='#{Inat::Constants::SITE}" \
                "/people/outdoor_dad'][target='_blank']",
                text: "outdoor_dad")
  end

  def test_free_text_collector_is_plain
    @obs.assign_attributes(collector: "Jane Forager", collector_user_id: nil)

    html = render_who

    assert_html(html, ".rss-who", text: "Jane Forager")
    assert_no_html(html, ".rss-who a")
  end

  def test_no_collector_falls_back_to_entering_user
    @obs.assign_attributes(collector: nil, collector_user_id: nil)

    html = render_who

    assert_html(html, ".rss-who a[href='#{routes.user_path(@obs.user_id)}']")
  end

  private

  def render_who
    render(Components::Matrix::Box::Who.new(obs: @obs))
  end
end
