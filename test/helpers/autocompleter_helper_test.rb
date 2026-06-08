# frozen_string_literal: true

require("test_helper")

class AutocompleterHelperTest < ActionView::TestCase
  include AutocompleterHelper
  include FormsHelper
  include LinkHelper

  def setup
    @form = ActionView::Helpers::FormBuilder.new(:location, nil, self, {})
  end

  # Line 39: textarea: true branch in autocompleter_field
  def test_autocompleter_field_renders_textarea_when_textarea_true
    html = autocompleter_field(form: @form, type: :location, field: :where,
                               textarea: true)
    doc = Nokogiri::HTML(html)

    assert(doc.at_css("textarea"),
           "Expected a textarea element when textarea: true")
  end

  # Line 82: unknown type triggers logger warning
  def test_stimulus_controller_name_warns_for_unknown_type
    assert_match(
      /autocompleter--bogus/,
      stimulus_controller_name(:bogus).to_s,
      "Expected controller name built from unknown type"
    )
  end

  # Lines 93-94: geocode_outlet arg populates outlet data
  def test_autocompleter_outlet_data_includes_geocode_outlet
    data = autocompleter_outlet_data(:"autocompleter--location",
                                     { geocode_outlet: ".geocode" })

    assert_equal(".geocode",
                 data[:autocompleter__location_geocode_outlet],
                 "Expected geocode outlet key in outlet data")
  end

  # Lines 127-129: create_text present, create absent → renders create button
  def test_autocompleter_create_button_renders_when_create_text_given
    html = autocompleter_create_button(type: :name, create_text: "Create name")

    assert_includes(html, "Create name",
                    "Expected create button text in rendered output")
  end

  # Lines 143-144: all three conditions met → renders modal create link
  def test_autocompleter_modal_create_link_renders_when_all_args_present
    html = autocompleter_modal_create_link(
      type: :name,
      create_text: "New name",
      create: "create-name",
      create_path: names_path
    )

    assert_includes(html, "New name",
                    "Expected modal link text in rendered output")
  end

  # Line 155: find_text present → renders find button
  def test_autocompleter_find_button_renders_when_find_text_given
    html = autocompleter_find_button(type: :location, find_text: "Find on map")

    assert_includes(html, "Find on map",
                    "Expected find button text in rendered output")
  end

  # Lines 167-168: keep_text present → renders keep box button
  def test_autocompleter_keep_box_button_renders_when_keep_text_given
    html = autocompleter_keep_box_button(type: :location, keep_text: "Keep")

    assert_includes(html, "Keep",
                    "Expected keep button text in rendered output")
  end

  # Lines 180-181: keep_text present → renders edit box button
  def test_autocompleter_edit_box_button_renders_when_keep_text_given
    html = autocompleter_edit_box_button(type: :location, keep_text: "Keep",
                                         edit_text: "Edit")

    assert_includes(html, "Edit",
                    "Expected edit button text in rendered output")
  end
end
