# frozen_string_literal: true

require("test_helper")

# `Components::SiblingMarker` — the footnote number saying which
# occurrence member a comment or photo came from (#5718).
class Components::SiblingMarkerTest < ComponentTestCase
  def test_linked_marker_points_at_its_observation
    obs = observations(:detailed_unknown_obs)

    html = render_marker(number: 2, observation_id: obs.id)

    path = routes.permanent_observation_path(obs.id)
    assert_html(html, "a[href='#{path}'] .sibling-marker", text: "2")
    assert_html(
      html,
      "[title='#{:show_observation_sibling_marker.l(id: obs.id)}']"
    )
  end

  def test_plain_marker_has_no_link
    html = render_marker(number: 1, observation_id: nil)

    assert_html(html, ".sibling-marker", text: "1")
    assert_no_html(html, "a",
                   "A marker with no observation has nothing to link")
  end

  # The Matching Observations panel row already links to the member,
  # so its marker is deliberately plain even though the id is known.
  def test_link_false_suppresses_the_link
    obs = observations(:detailed_unknown_obs)

    html = render_marker(number: 3, observation_id: obs.id, link: false)

    assert_html(html, ".sibling-marker", text: "3")
    assert_no_html(html, "a", "link: false should render no link")
  end

  # Callers pass spacing and Stimulus hooks through, so the
  # catch-all has to reach the rendered element.
  def test_caller_attributes_reach_the_element
    html = render_marker(number: 1, observation_id: nil,
                         data: { role: "marker" })

    assert_html(html, "[data-role='marker']", text: "1")
  end

  # An outlined badge vanishes into a photograph, so the carousel
  # overlay fills instead.
  def test_solid_variant_swaps_the_outline
    solid = render_marker(number: 1, observation_id: nil,
                          variant: :solid)
    outlined = render_marker(number: 1, observation_id: nil)

    assert_html(solid, ".sibling-marker-solid", text: "1")
    assert_no_html(solid, ".badge-outline",
                   "Solid and outline are alternatives")
    assert_html(outlined, ".badge-outline", text: "1")
  end

  # Bootstrap's carousel handler cancels a click that reaches it, so a
  # badge inside an indicator keeps the click to itself.
  def test_isolate_click_wires_the_stimulus_action
    obs = observations(:detailed_unknown_obs)

    isolated = render_marker(number: 1, observation_id: obs.id,
                             isolate_click: true)
    plain = render_marker(number: 1, observation_id: obs.id)

    assert_html(isolated,
                "a[data-controller='links'][data-action='click->links#follow']")
    assert_no_html(plain, "a[data-action]",
                   "Only a badge inside a carousel needs the action")
  end

  private

  def render_marker(number:, observation_id:, **attrs)
    render(Components::SiblingMarker.new(
             number: number, observation_id: observation_id, **attrs
           ))
  end
end
