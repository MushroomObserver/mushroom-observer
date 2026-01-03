# frozen_string_literal: true

require "test_helper"

class HerbariumFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @herbarium = Herbarium.new
  end

  def test_new_form
    html = render_form(model: @herbarium)

    # Form fields
    assert_html(html, "input[name='herbarium[name]']")
    assert_html(html, "input[name='herbarium[email]']")
    assert_html(html, "textarea[name='herbarium[mailing_address]']")
    assert_html(html, "textarea[name='herbarium[description]']")
    assert_html(html, "input[name='herbarium[code]']")

    # Location autocompleter with map outlet wiring
    assert_html(html, "#herbarium_location_autocompleter")
    assert_html(html, "input[name='herbarium[place_name]']")
    assert_html(html, "#herbarium_location_autocompleter",
                attribute: { "data-controller" => "autocompleter--location",
                             "data-type" => "location",
                             "data-autocompleter--location-map-outlet" =>
                               "#herbarium_form" })
    assert_html(
      html,
      "#herbarium_location_autocompleter input[type='hidden']" \
      "#herbarium_location_id[name='herbarium[location_id]']"
    )

    # Bounds hidden fields
    %w[north south east west low high].each do |key|
      assert_html(html, "input[type='hidden'][name='location[#{key}]']")
    end

    # Map section
    assert_html(html, "#herbarium_form_map.form-map")
    assert_html(html, "form#herbarium_form",
                attribute: { "data-controller" => "map" })

    # Personal checkbox for new record
    assert_html(html, "input[type='checkbox'][name='herbarium[personal]']")

    # Submit button and form action
    assert_html(html, "input[type='submit'][value='#{:CREATE.l}']")
    assert_html(html, "form[action='/herbaria']")

    # No back field when not provided
    assert_no_html(html, "input[name='herbarium[back]']")

    # No turbo for local form
    assert_no_html(html, "form[data-turbo]")
  end

  def test_existing_record_form
    herbarium = herbaria(:nybg_herbarium)
    html = render_form(model: herbarium)

    assert_html(html, "input[type='submit'][value='#{:SAVE.l}']")
    assert_html(html, "form[action*='/herbaria/#{herbarium.id}']")
  end

  def test_personal_herbarium_omits_code_field
    herbarium = @user.personal_herbarium || Herbarium.new
    herbarium.personal_user_id = @user.id
    html = render_form(model: herbarium)

    assert_no_html(html, "input[name='herbarium[code]']")
  end

  def test_with_back_param
    html = render_form(model: @herbarium, back: "/some/path")

    assert_html(html, "input[type='hidden'][name='herbarium[back]']" \
                      "[value='/some/path']")
  end

  def test_modal_form_enables_turbo
    html = render_form(model: @herbarium, local: false)

    assert_html(html, "form[data-turbo='true']")
  end

  private

  def render_form(model:, local: true, back: nil)
    render(Components::HerbariumForm.new(
             model,
             user: @user,
             back: back,
             local: local
           ))
  end
end
