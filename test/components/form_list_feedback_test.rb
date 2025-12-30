# frozen_string_literal: true

require "test_helper"

class FormListFeedbackTest < UnitTestCase
  include ComponentTestHelper

  def setup
    controller.request = ActionDispatch::TestRequest.create
  end

  # ----- Missing Names Tests -----

  def test_renders_nothing_when_all_props_nil
    html = render_component(new_names: nil, deprecated_names: nil,
                            multiple_names: nil)
    assert_empty(Nokogiri::HTML(html).text.strip)
  end

  def test_renders_nothing_when_all_arrays_empty
    html = render_component(new_names: [], deprecated_names: [],
                            multiple_names: {})
    assert_empty(Nokogiri::HTML(html).text.strip)
  end

  def test_renders_missing_names_alert
    html = render_component(new_names: ["Agaricus foo", "Boletus bar"])

    assert_html(html, ".alert-danger#missing_names")
    assert_html(html, ".font-weight-bold",
                text: :form_list_feedback_missing_names.t)
    assert_html(html, ".help-note")
  end

  def test_renders_missing_names_list
    html = render_component(new_names: ["Agaricus foo", "Boletus bar"])

    assert_html(html, "p")
    assert_html(html, "body", text: "Agaricus foo")
    assert_html(html, "body", text: "Boletus bar")
    # Each name should have a line break before it
    assert_html(html, "br", count: 2)
  end

  # ----- Deprecated Names Tests -----

  def test_renders_deprecated_names_alert
    deprecated_name = names(:lactarius_alpinus)
    html = render_component(deprecated_names: [deprecated_name])

    assert_html(html, ".alert-warning#deprecated_names")
    assert_html(html, ".font-weight-bold")
    assert_html(html, ".help-note")
  end

  def test_renders_deprecated_name_with_approved_synonyms
    deprecated_name = names(:lactarius_alpigenes)
    approved_synonym = names(:lactarius_alpinus)
    html = render_component(deprecated_names: [deprecated_name])

    # Name should be displayed (check for text without HTML tags)
    assert_html(html, "body", text: "Lactarius")
    assert_html(html, "body", text: "alpigenes")

    # Radio button for approved synonym
    assert_html(html, "input[type='radio']" \
                      "[name='chosen_approved_names[#{deprecated_name.id}]']" \
                      "[value='#{approved_synonym.id}']")
    # Check for label text without HTML tags
    assert_html(html, "label", text: "alpinus")
  end

  def test_renders_multiple_deprecated_names
    deprecated1 = names(:lactarius_alpigenes)
    deprecated2 = names(:lactarius_subalpinus)
    html = render_component(deprecated_names: [deprecated1, deprecated2])

    # Check for text content without HTML tags
    assert_html(html, "body", text: "alpigenes")
    assert_html(html, "body", text: "subalpinus")
  end

  # ----- Multiple Names (Ambiguous) Tests -----

  def test_renders_multiple_names_alert
    name = names(:coprinus_comatus)
    other_authors = [names(:agaricus_campestris)]
    html = render_component(multiple_names: { name => other_authors })

    assert_html(html, ".alert-warning#ambiguous_names")
    assert_html(html, "body", text: :form_species_lists_multiple_names.t)
    assert_html(html, "body",
                text: :form_species_lists_multiple_names_help.t)
  end

  def test_renders_multiple_name_choices_with_observation_counts
    name = names(:coprinus_comatus)
    other_name = names(:agaricus_campestris)
    html = render_component(multiple_names: { name => [other_name] })

    # Name should be displayed (check for text without HTML tags)
    assert_html(html, "body", text: "Coprinus")
    assert_html(html, "body", text: "comatus")

    # Radio button for alternative
    assert_html(html, "input[type='radio']" \
                      "[name='chosen_multiple_names[#{name.id}]']" \
                      "[value='#{other_name.id}']")
    # Check for label text without HTML tags
    assert_html(html, "label", text: "campestris")

    # Observation count should be displayed
    assert_html(html, "body", text: "(#{other_name.observations.count})")
  end

  def test_renders_multiple_ambiguous_names
    name1 = names(:coprinus_comatus)
    name2 = names(:agaricus_campestris)
    other1 = names(:lactarius_alpinus)
    other2 = names(:lactarius_alpigenes)

    html = render_component(
      multiple_names: {
        name1 => [other1],
        name2 => [other2]
      }
    )

    # Check for text content without HTML tags
    assert_html(html, "body", text: "comatus")
    assert_html(html, "body", text: "campestris")
    assert_html(html, "input[type='radio']", count: 2)
  end

  # ----- Combined Scenarios -----

  def test_renders_all_three_alert_types_together
    deprecated_name = names(:lactarius_alpinus)
    name = names(:coprinus_comatus)
    other_name = names(:agaricus_campestris)

    html = render_component(
      new_names: ["Unknown name"],
      deprecated_names: [deprecated_name],
      multiple_names: { name => [other_name] }
    )

    # All three alert types should be present
    assert_html(html, ".alert-danger#missing_names")
    assert_html(html, ".alert-warning#deprecated_names")
    assert_html(html, ".alert-warning#ambiguous_names")
  end

  private

  def render_component(new_names: nil, deprecated_names: nil,
                       multiple_names: nil)
    component = Components::FormListFeedback.new(
      new_names: new_names,
      deprecated_names: deprecated_names,
      multiple_names: multiple_names
    )
    render(component)
  end
end
