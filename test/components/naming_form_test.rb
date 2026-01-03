# frozen_string_literal: true

require "test_helper"

class NamingFormTest < ComponentTestCase
  def setup
    super
    @observation = observations(:coprinus_comatus_obs)
  end

  def test_new_form
    html = render_form(model: Naming.new, vote: Vote.new, context: "blank")

    # Form structure
    assert_html(html, "form[action*='namings']")
    assert_html(html, "form[id='obs_#{@observation.id}_naming_form']")
    assert_html(html, "input[type='hidden'][name='context']")

    # Fields
    assert_html(html, "input[name='naming[name]']")
    assert_html(html, "input[data-autocompleter--name-target='input']")
    assert_html(html, "select[name='naming[vote][value]']")
    assert_html(html, "input[name='naming[reasons][1][check]']")

    # Submit button
    assert_html(html, "input[type='submit'][value='#{:CREATE.l}']")
    assert_html(html, "input.btn.btn-default")

    # Blank context collapses fields, has blank vote option
    assert_html(
      html, "div.collapse[data-autocompleter--name-target='collapseFields']"
    )
    assert_html(html, "select[name='naming[vote][value]'] option[value='']")
  end

  def test_edit_form
    naming = namings(:coprinus_comatus_naming)
    vote = votes(:coprinus_comatus_owner_vote)
    html = render_form(model: naming, vote: vote, context: "lightbox")

    # Form structure
    assert_html(html, "form[action*='/namings/#{naming.id}']")
    assert_html(html,
                "form[id='obs_#{@observation.id}_naming_#{naming.id}_form']")

    # Submit button
    assert_html(html, "input[type='submit'][value='#{:SAVE_EDITS.l}']")

    # Vote and reasons fields present in edit form
    assert_html(html, "select[name='naming[vote][value]']")
    assert_html(html, "input[name='naming[reasons][1][check]']")

    # Lightbox context doesn't collapse fields
    assert_html(html,
                "div:not(.collapse)[data-autocompleter--name-target=" \
                "'collapseFields']")

    # No blank option, vote value selected
    assert_no_html(html, "select[name='naming[vote][value]'] option[value='']")
    assert_html(html, "option[selected][value='#{vote.value}']")
  end

  def test_form_with_feedback
    naming = namings(:coprinus_comatus_naming)
    html = render_form(
      model: naming,
      vote: Vote.new,
      given_name: "Unknown name",
      feedback: { names: [], valid_names: nil, parent_deprecated: nil }
    )

    assert_html(html, "#name_messages")
  end

  def test_form_with_parent_deprecated_feedback
    naming = namings(:coprinus_comatus_naming)
    html = render_form(
      model: naming,
      vote: Vote.new,
      given_name: "Some name",
      feedback: {
        names: [names(:agaricus_campestris)],
        valid_names: [names(:coprinus_comatus)],
        parent_deprecated: names(:lactarius)
      }
    )

    assert_html(html, "#name_messages")
  end

  def test_turbo_enabled_when_local_false
    html = render_form(model: Naming.new, vote: Vote.new, local: false)

    assert_html(html, "form[data-turbo='true']")
  end

  def test_turbo_omitted_when_local_true
    html = render_form(model: Naming.new, vote: Vote.new, local: true)

    assert_no_html(html, "form[data-turbo]")
  end

  private

  # rubocop:disable Metrics/ParameterLists
  def render_form(model:, vote:, context: "lightbox", local: true,
                  given_name: "", feedback: nil)
    render(Components::NamingForm.new(
             model,
             observation: @observation,
             vote: vote,
             given_name: given_name,
             reasons: model.init_reasons,
             feedback: feedback,
             show_reasons: true,
             context: context,
             local: local
           ))
  end
  # rubocop:enable Metrics/ParameterLists
end
