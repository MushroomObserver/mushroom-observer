# frozen_string_literal: true

require("test_helper")

class ObservationFormTest < ComponentTestCase
  def test_new_form_posts_to_observations
    user = users(:rolf)
    obs = Observation.new(when: Time.zone.today)

    html = render_form(observation: obs, user: user, mode: :create)

    # Should post to /observations (no query params on initial load)
    assert_html(html, "form[action='/observations'][method='post']")
  end

  def test_form_includes_approval_params_when_present
    user = users(:rolf)
    obs = Observation.new(when: Time.zone.today)

    html = render_form(
      observation: obs,
      user: user,
      mode: :create,
      given_name: "Agaricus",
      place_name: "California"
    )

    # Form action should include approval query params
    assert_html(html, "form[action*='approved_name=Agaricus']")
    assert_html(html, "form[action*='approved_where=California']")
  end

  private

  def render_form(observation:, user:, mode: :create, given_name: nil,
                  place_name: nil)
    render(Components::ObservationForm.new(
             observation,
             mode: mode,
             user: user,
             given_name: given_name,
             place_name: place_name,
             good_images: [],
             exif_data: {},
             projects: [],
             project_checks: {},
             lists: [],
             list_checks: {},
             error_checked_projects: [],
             suspect_checked_projects: []
           ))
  end
end
