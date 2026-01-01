# frozen_string_literal: true

require "test_helper"

# Tests for NamingFields component (Superform mode only).
# For ERB form tests, see the system tests for observation form.
class NamingFieldsTest < ComponentTestCase

  def setup
    super
    @naming = Naming.new
    @vote = Vote.new
    @reasons = @naming.init_reasons
  end

  # Test for bug: edit naming form missing vote/confidence and reasons fields
  def test_renders_vote_field_for_existing_naming
    @naming = namings(:coprinus_comatus_naming)
    @vote = votes(:coprinus_comatus_owner_vote)
    html = render_naming_form(create: false)

    assert_html(html, "select[name='naming[vote][value]']")
  end

  def test_renders_vote_field_for_new_naming
    html = render_naming_form(create: true)

    assert_html(html, "select[name='naming[vote][value]']")
  end

  def test_renders_reasons_fields_when_show_reasons_true
    html = render_naming_form(create: true, show_reasons: true)

    assert_html(html, "input[name*='reasons']")
  end

  def test_renders_name_autocompleter
    html = render_naming_form(create: true)

    assert_html(html, "input[name='naming[name]']")
  end

  # Test for bug: collapseFields target must use namespaced controller format
  # The autocompleter--name controller requires data-autocompleter--name-target
  # not data-autocompleter-target
  def test_collapse_fields_uses_correct_stimulus_target
    html = render_naming_form(create: true)

    # Should use the namespaced target format for autocompleter--name controller
    assert_match(/data-autocompleter--name-target=.collapseFields/, html,
                 "collapseFields should use autocompleter--name-target")
    # Should NOT use the old non-namespaced format
    assert_no_match(/data-autocompleter-target=.collapseFields/, html,
                    "Should not use non-namespaced autocompleter-target")
  end

  private

  # Render NamingFields via NamingForm which provides the form_namespace
  def render_naming_form(create: true, show_reasons: true, context: "lightbox")
    component = Components::NamingForm.new(
      @naming,
      observation: observations(:minimal_unknown_obs),
      vote: @vote,
      given_name: "",
      reasons: @reasons,
      show_reasons: show_reasons,
      context: context,
      create: create
    )
    render(component)
  end
end
