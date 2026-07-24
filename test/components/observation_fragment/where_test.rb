# frozen_string_literal: true

require("test_helper")

class ObservationFragmentWhereTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  def test_renders_collection_location_label
    obs = observations(:coprinus_comatus_obs)
    obs.update(is_collection_location: true)

    html = render_where(obs)

    assert_includes(where_text(html), :show_observation_collection_location.t)
  end

  def test_renders_seen_at_label_when_not_collection_location
    obs = observations(:coprinus_comatus_obs)
    obs.update(is_collection_location: false)

    html = render_where(obs)

    assert_includes(where_text(html), :show_observation_seen_at.t)
  end

  def test_renders_location_link_when_logged_in
    obs = observations(:coprinus_comatus_obs)

    html = render_where(obs)

    assert_html(html, "li.obs-where a")
  end

  def test_renders_plain_text_when_logged_out
    obs = observations(:coprinus_comatus_obs)

    html = render_where(obs, user: nil)

    assert_includes(where_text(html), obs.where)
    assert_no_html(html, "li.obs-where a")
  end

  def test_renders_vague_location_notice
    obs = observations(:coprinus_comatus_obs)
    obs.update(location: locations(:burbank))
    obs.location.stub(:vague?, true) do
      html = render_where(obs, user: users(:mary))

      assert_includes(where_text(html), :show_observation_vague_location.l)
      assert_not_includes(
        where_text(html), :show_observation_improve_location.l
      )
    end
  end

  def test_renders_improve_hint_for_owner
    obs = observations(:coprinus_comatus_obs)
    obs.update(location: locations(:burbank))
    obs.location.stub(:vague?, true) do
      html = render_where(obs, user: obs.user)

      assert_includes(where_text(html), :show_observation_improve_location.l)
    end
  end

  def test_no_vague_notice_when_location_not_vague
    obs = observations(:coprinus_comatus_obs)
    obs.update(location: locations(:burbank))
    obs.location.stub(:vague?, false) do
      html = render_where(obs)

      assert_not_includes(where_text(html), :show_observation_vague_location.l)
    end
  end

  private

  def where_text(html)
    Nokogiri::HTML.fragment(html).text
  end

  def render_where(obs, user: @user)
    render(Components::ObservationFragment::Where.new(obs: obs, user: user))
  end
end
