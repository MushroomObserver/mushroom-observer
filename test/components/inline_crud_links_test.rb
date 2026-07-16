# frozen_string_literal: true

require("test_helper")

# `Components::InlineCRUDLinks` — polymorphic `[ edit | destroy ]` /
# `[ + ]` group for observation-show sub-panel records. Keyed on
# presence/absence of `target:`. Tests cover one target type per
# polymorphism branch, plus the add-link mode.
class InlineCRUDLinksTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:minimal_unknown_obs)
  end

  def test_no_render_when_user_cannot_edit
    stranger = users(:lone_wolf)
    cn = collection_numbers(:detailed_unknown_coll_num_one)

    html = render(Components::InlineCRUDLinks.new(
                    target: cn, observation: @obs, user: stranger
                  ))

    assert_no_html(html, "span.text-nowrap")
    assert_equal("", html.strip)
  end

  def test_collection_number_remove_link
    cn = collection_numbers(:detailed_unknown_coll_num_one)
    obs = cn.observations.first

    html = render(Components::InlineCRUDLinks.new(
                    target: cn, observation: obs, user: cn.user
                  ))

    # Edit → ModalLink, modal_identifier carries the record's id
    assert_html(html,
                "a.inline-icon-link" \
                "[data-modal='modal_collection_number_#{cn.id}']")
    # Destroy → detach-from-obs path (record path + observation_id qs)
    expected_path = routes.collection_number_path(
      cn.id, observation_id: obs.id
    )
    assert_html(html, "form[action='#{expected_path}'][method='post']")
    assert_html(html, "form input[name='_method'][value='delete']",
                visible: :all)
    assert_html(html,
                "button.inline-icon-link" \
                ".remove_collection_number_link_#{cn.id}")
  end

  def test_sequence_real_destroy_with_back_redirect
    seq = sequences(:local_sequence)
    obs = seq.observation

    # No `observation:` -- Sequence derives it from `@target.observation`.
    html = render(Components::InlineCRUDLinks.new(
                    target: seq, user: seq.user
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

    # No `observation:` -- ExternalLink's handlers never read it.
    html = render(Components::InlineCRUDLinks.new(
                    target: link, user: link.user
                  ))

    assert_html(html,
                "a[data-modal='modal_external_link_#{link.id}']")
    assert_html(html, "button.destroy_external_link_link_#{link.id}")
  end

  def test_herbarium_record_remove_link
    record = herbarium_records(:coprinus_comatus_rolf_spec)
    obs = record.observations.first

    html = render(Components::InlineCRUDLinks.new(
                    target: record, observation: obs, user: record.user
                  ))

    assert_html(html,
                "a[data-modal='modal_herbarium_record_#{record.id}']")
    expected_path = routes.herbarium_record_path(
      record.id, observation_id: obs.id
    )
    assert_html(html, "form[action='#{expected_path}'][method='post']")
    assert_html(html, "button.remove_herbarium_record_link_#{record.id}")
  end

  def test_naming_edit_and_destroy_links
    naming = namings(:detailed_unknown_naming)

    html = render(Components::InlineCRUDLinks.new(
                    target: naming, user: naming.user
                  ))

    assert_html(html, "a[data-modal='modal_obs_#{naming.observation_id}" \
                      "_naming_#{naming.id}']")
    expected_path = routes.observation_naming_path(
      observation_id: naming.observation_id, id: naming.id
    )
    assert_html(html, "form[action='#{expected_path}']")
    assert_html(html, "button.destroy_naming_link_#{naming.id}")
  end

  def test_comment_edit_and_destroy_links
    comment = comments(:minimal_unknown_obs_comment_1)

    html = render(Components::InlineCRUDLinks.new(
                    target: comment, user: comment.user
                  ))

    assert_html(html, "a[data-modal='modal_comment_#{comment.id}']")
    expected_path = routes.comment_path(comment.id)
    assert_html(html, "form[action='#{expected_path}']")
  end

  def test_name_description_uses_icon_link_edit
    desc = name_descriptions(:peltigera_user_desc)

    html = render(Components::InlineCRUDLinks.new(
                    target: desc, user: desc.user
                  ))

    # NameDescription edit is an IconLink, NOT a ModalLink
    assert_html(html, "a.edit_name_description_link_#{desc.id}")
    assert_no_html(html, "[data-modal]")
  end

  def test_extras_rendered_before_edit_destroy
    seq = sequences(:deposited_sequence)
    extra_html = '<a href="/archive">archive</a>'.html_safe

    html = render(Components::InlineCRUDLinks.new(
                    target: seq, user: seq.user, extras: [extra_html]
                  ))

    assert_html(html, "a[href='/archive']")
    assert_html(html,
                "a.inline-icon-link[data-modal='modal_sequence_#{seq.id}']")
    assert_html(html, "button.inline-icon-link.destroy_sequence_link_#{seq.id}")
    # Extras render before edit/destroy: archive link's position in
    # the raw HTML precedes the modal-edit link's position.
    assert_operator(html.index("/archive"), :<,
                    html.index("modal_sequence_#{seq.id}"))
  end

  # ----- add-link mode (target: absent) ---------------------------

  def test_add_link_mode_renders_icon_only_add_link
    obs = observations(:detailed_unknown_obs)
    tab = ::Tab::CollectionNumber::New.new(observation: obs)

    html = render(Components::InlineCRUDLinks.new(
                    modal_id: "collection_number", tab: tab
                  ))

    assert_html(html, "a[data-modal='modal_collection_number'] " \
                      "span.glyphicon-plus")
    assert_html(html, "a span.sr-only", text: tab.title)
  end
end
