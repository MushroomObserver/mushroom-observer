# frozen_string_literal: true

require("test_helper")

# `Components::InlineModLinks` — polymorphic `[ edit | destroy ]`
# group for observation-show sub-panel records. Tests cover one
# target type per polymorphism branch.
class Components::InlineModLinksTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:minimal_unknown_obs)
  end

  def test_no_render_when_user_cannot_edit
    stranger = users(:lone_wolf)
    cn = collection_numbers(:detailed_unknown_coll_num_one)

    html = render(Components::InlineModLinks.new(
                    target: cn, observation: @obs, user: stranger
                  ))

    assert_no_html(html, "span.ml-2")
    assert_equal("", html.strip)
  end

  def test_collection_number_remove_link
    cn = collection_numbers(:detailed_unknown_coll_num_one)
    obs = cn.observations.first

    html = render(Components::InlineModLinks.new(
                    target: cn, observation: obs, user: cn.user
                  ))

    assert_includes(html, "[")
    assert_includes(html, "|")
    assert_includes(html, "]")
    # Edit → ModalLink, modal_identifier carries the record's id
    assert_html(html,
                "a[data-modal='modal_collection_number_#{cn.id}']")
    # Destroy → detach-from-obs path (record path + observation_id qs)
    expected_path = routes.collection_number_path(
      cn.id, observation_id: obs.id
    )
    assert_html(html, "form[action='#{expected_path}'][method='post']")
    assert_html(html, "form input[name='_method'][value='delete']",
                visible: :all)
    assert_html(html, "button.remove_collection_number_link_#{cn.id}")
  end

  def test_sequence_real_destroy_with_back_redirect
    seq = sequences(:local_sequence)
    obs = seq.observation

    html = render(Components::InlineModLinks.new(
                    target: seq, observation: obs, user: seq.user
                  ))

    assert_html(html,
                "a[data-modal='modal_sequence_#{seq.id}']")
    # `back: observation_path(obs)` is encoded as a query parameter
    expected_path = routes.sequence_path(
      id: seq.id, back: routes.observation_path(obs)
    )
    assert_html(html, "form[action='#{expected_path}']")
    assert_html(html, "button.destroy_sequence_link_#{seq.id}")
  end

  def test_external_link_real_destroy
    link = external_links(:coprinus_comatus_obs_inaturalist_link)
    obs = link.observation

    html = render(Components::InlineModLinks.new(
                    target: link, observation: obs, user: link.user
                  ))

    assert_html(html,
                "a[data-modal='modal_external_link_#{link.id}']")
    assert_html(html, "button.destroy_external_link_link_#{link.id}")
  end

  def test_name_description_uses_icon_link_edit
    desc = name_descriptions(:peltigera_user_desc)

    html = render(Components::InlineModLinks.new(
                    target: desc, user: desc.user
                  ))

    # NameDescription edit is an IconLink, NOT a ModalLink
    assert_html(html, "a.edit_name_description_link_#{desc.id}")
    assert_no_html(html, "[data-modal]")
  end

  def test_indent_false_skips_ml2_wrapper
    cn = collection_numbers(:detailed_unknown_coll_num_one)
    obs = cn.observations.first

    html = render(Components::InlineModLinks.new(
                    target: cn, observation: obs, user: cn.user,
                    indent: false
                  ))

    assert_no_html(html, "span.ml-2")
    # Still bracketed
    assert_includes(html, "[")
  end

  def test_extras_rendered_before_edit_destroy
    seq = sequences(:deposited_sequence)
    obs = seq.observation
    extra_html = '<a href="/archive">archive</a>'.html_safe

    html = render(Components::InlineModLinks.new(
                    target: seq, observation: obs, user: seq.user,
                    extras: [extra_html]
                  ))

    # Three items → two `|` separators
    assert_equal(2, html.scan("|").size)
    assert_html(html, "a[href='/archive']")
  end
end
