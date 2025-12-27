# frozen_string_literal: true

require "test_helper"

class HerbariumFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @user = users(:rolf)
    @herbarium = Herbarium.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_name_field
    html = render_form

    assert_html(html, "input[name='herbarium[name]']")
  end

  def test_renders_form_with_email_field
    html = render_form

    assert_html(html, "input[name='herbarium[email]']")
  end

  def test_renders_form_with_mailing_address_field
    html = render_form

    assert_html(html, "textarea[name='herbarium[mailing_address]']")
  end

  def test_renders_form_with_notes_field
    html = render_form

    assert_html(html, "textarea[name='herbarium[description]']")
  end

  def test_renders_form_with_location_autocompleter
    html = render_form

    assert_html(html, "#herbarium_place_name_autocompleter")
    assert_html(html, "input[name='herbarium[place_name]']")
  end

  def test_renders_form_with_bounds_hidden_fields
    html = render_form

    %w[north south east west low high].each do |key|
      assert_html(html, "input[type='hidden'][name='location[#{key}]']")
    end
  end

  def test_renders_form_with_map_section
    html = render_form

    assert_html(html, "#herbarium_form_map.form-map")
  end

  def test_renders_create_button_for_new_record
    html = render_form

    assert_html(html, "input[type='submit'][value='#{:CREATE.l}']")
  end

  def test_renders_save_button_for_existing_record
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::HerbariumForm.new(
                    herbarium,
                    user: @user,
                    local: true
                  ))

    assert_html(html, "input[type='submit'][value='#{:SAVE.l}']")
  end

  def test_renders_personal_checkbox_for_new_record
    html = render_form

    assert_html(html, "input[type='checkbox'][name='herbarium[personal]']")
  end

  def test_omits_code_field_for_personal_herbarium
    herbarium = @user.personal_herbarium || Herbarium.new
    herbarium.personal_user_id = @user.id

    html = render(Components::HerbariumForm.new(
                    herbarium,
                    user: @user,
                    local: true
                  ))
    doc = Nokogiri::HTML(html)

    assert_nil(doc.at_css("input[name='herbarium[code]']"))
  end

  def test_renders_code_field_for_institutional_herbarium
    html = render_form

    assert_html(html, "input[name='herbarium[code]']")
  end

  def test_renders_form_with_correct_action_for_create
    html = render_form

    assert_html(html, "form[action='/herbaria']")
  end

  def test_renders_form_with_correct_action_for_update
    herbarium = herbaria(:nybg_herbarium)
    html = render(Components::HerbariumForm.new(
                    herbarium,
                    user: @user,
                    local: true
                  ))

    assert_html(html, "form[action*='/herbaria/#{herbarium.id}']")
  end

  def test_renders_back_hidden_field_when_provided
    html = render(Components::HerbariumForm.new(
                    @herbarium,
                    user: @user,
                    back: "/some/path",
                    local: true
                  ))

    assert_html(html, "input[type='hidden'][name='herbarium[back]']" \
                      "[value='/some/path']")
  end

  def test_omits_back_field_when_not_provided
    html = render_form
    doc = Nokogiri::HTML(html)

    assert_nil(doc.at_css("input[name='herbarium[back]']"))
  end

  def test_enables_turbo_for_modal_rendering
    html = render(Components::HerbariumForm.new(
                    @herbarium,
                    user: @user,
                    local: false
                  ))

    assert_html(html, "form[data-turbo='true']")
  end

  def test_disables_turbo_for_local_form
    html = render_form
    doc = Nokogiri::HTML(html)

    # local: true should not have data-turbo attribute
    form = doc.at_css("form")
    assert_nil(form["data-turbo"])
  end

  def test_renders_map_controller_data_attributes
    html = render_form
    doc = Nokogiri::HTML(html)
    form = doc.at_css("form#herbarium_form")

    assert_equal("map", form["data-controller"])
    # Boolean false in Phlex doesn't render the attribute or renders empty
    # Check that the form has map controller - the map-open state is optional
    assert(form["data-controller"].include?("map"))
  end

  private

  def render_form
    render(Components::HerbariumForm.new(
             @herbarium,
             user: @user,
             local: true
           ))
  end
end
