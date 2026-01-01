# frozen_string_literal: true

require "test_helper"

class FormListFeedbackTest < ComponentTestCase
  def test_renders_nothing_when_no_feedback
    assert_empty(Nokogiri::HTML(render_feedback).text.strip)
    html = render_feedback(
      new_names: [], deprecated_names: [], multiple_names: {}
    )
    assert_empty(Nokogiri::HTML(html).text.strip)
  end

  def test_renders_missing_names_alert
    html = render_feedback(new_names: ["Agaricus foo", "Boletus bar"])

    assert_html(html, ".alert-danger#missing_names")
    assert_html(html, ".font-weight-bold",
                text: :form_list_feedback_missing_names.t)
    assert_html(html, ".help-note")
    assert_html(html, "body", text: "Agaricus foo")
    assert_html(html, "body", text: "Boletus bar")
    assert_html(html, "br", count: 2)
  end

  def test_renders_deprecated_names_with_approved_synonyms
    deprecated = names(:lactarius_alpigenes)
    approved = names(:lactarius_alpinus)
    html = render_feedback(deprecated_names: [deprecated])

    assert_html(html, ".alert-warning#deprecated_names")
    assert_html(html, ".font-weight-bold")
    assert_html(html, ".help-note")
    assert_html(html, "body", text: "alpigenes")
    assert_html(html, "input[type='radio']" \
                      "[name='chosen_approved_names[#{deprecated.id}]']" \
                      "[value='#{approved.id}']")
    assert_html(html, "label", text: "alpinus")
  end

  def test_renders_multiple_deprecated_names
    deprecated1 = names(:lactarius_alpigenes)
    deprecated2 = names(:lactarius_subalpinus)
    html = render_feedback(deprecated_names: [deprecated1, deprecated2])

    assert_html(html, "body", text: "alpigenes")
    assert_html(html, "body", text: "subalpinus")
  end

  def test_renders_ambiguous_names_with_observation_counts
    name = names(:coprinus_comatus)
    other = names(:agaricus_campestris)
    html = render_feedback(multiple_names: { name => [other] })

    assert_html(html, ".alert-warning#ambiguous_names")
    assert_html(html, "body", text: :form_species_lists_multiple_names.t)
    assert_html(html, "body", text: "comatus")
    assert_html(html, "input[type='radio']" \
                      "[name='chosen_multiple_names[#{name.id}]']" \
                      "[value='#{other.id}']")
    assert_html(html, "label", text: "campestris")
    assert_html(html, "body", text: "(#{other.observations.count})")
  end

  def test_renders_multiple_ambiguous_names
    name1 = names(:coprinus_comatus)
    name2 = names(:agaricus_campestris)
    html = render_feedback(multiple_names: {
                             name1 => [names(:lactarius_alpinus)],
                             name2 => [names(:lactarius_alpigenes)]
                           })

    assert_html(html, "body", text: "comatus")
    assert_html(html, "body", text: "campestris")
    assert_html(html, "input[type='radio']", count: 2)
  end

  def test_renders_all_three_alert_types_together
    name = names(:coprinus_comatus)
    other = names(:agaricus_campestris)
    html = render_feedback(
      new_names: ["Unknown name"],
      deprecated_names: [names(:lactarius_alpinus)],
      multiple_names: { name => [other] }
    )

    assert_html(html, ".alert-danger#missing_names")
    assert_html(html, ".alert-warning#deprecated_names")
    assert_html(html, ".alert-warning#ambiguous_names")
  end

  private

  def render_feedback(new_names: nil, deprecated_names: nil,
                      multiple_names: nil)
    render(Components::FormListFeedback.new(
             new_names: new_names,
             deprecated_names: deprecated_names,
             multiple_names: multiple_names
           ))
  end
end
