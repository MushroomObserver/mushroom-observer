# frozen_string_literal: true

require "test_helper"

class SequenceFormTest < ComponentTestCase
  def setup
    super
    @observation = observations(:coprinus_comatus_obs)
  end

  def test_new_form
    html = render_form(model: Sequence.new(observation: @observation))

    # Form fields
    assert_html(html, "textarea[name='sequence[locus]']")
    assert_html(html, "textarea[name='sequence[bases]']")
    assert_html(html, "textarea[name='sequence[notes]']")
    assert_html(html, "select[name='sequence[archive]']")
    assert_html(html, "input[name='sequence[accession]']")

    # Submit button for new record
    assert_html(html, "input[type='submit'][value='#{:ADD.l}']")
    assert_html(html, "input.btn.btn-default")

    # Turbo enabled by default
    assert_html(html, "form[data-turbo='true']")
  end

  def test_new_form_auto_determines_url
    html = render_form(model: Sequence.new(observation: @observation),
                       action: nil)

    assert_html(html, "form[action*='/sequences']")
  end

  def test_existing_record_form
    sequence = sequences(:local_sequence)
    html = render_form(model: sequence)

    assert_html(html, "input[type='submit'][value='#{:UPDATE.l}']")
  end

  def test_existing_record_auto_determines_url
    sequence = sequences(:local_sequence)
    html = render_form(model: sequence, action: nil)

    assert_html(html, "form[action*='/sequences/#{sequence.id}']")
  end

  def test_local_form_omits_turbo
    html = render_form(model: Sequence.new(observation: @observation),
                       local: true)

    assert_no_html(html, "form[data-turbo]")
  end

  private

  def render_form(model:, action: "/test_action", local: false)
    render(Components::SequenceForm.new(
             model,
             action: action,
             id: "sequence_form",
             local: local
           ))
  end
end
