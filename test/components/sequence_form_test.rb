# frozen_string_literal: true

require "test_helper"

class SequenceFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @observation = observations(:coprinus_comatus_obs)
    @sequence = Sequence.new(observation: @observation)
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_locus_field
    assert_html(@html, "textarea[name='sequence[locus]']")
  end

  def test_renders_form_with_bases_field
    assert_html(@html, "textarea[name='sequence[bases]']")
  end

  def test_renders_form_with_notes_field
    assert_html(@html, "textarea[name='sequence[notes]']")
  end

  def test_renders_form_with_archive_field
    assert_html(@html, "select[name='sequence[archive]']")
  end

  def test_renders_form_with_accession_field
    assert_html(@html, "input[name='sequence[accession]']")
  end

  def test_renders_submit_button_for_new_record
    assert_html(@html, "input[type='submit'][value='#{:ADD.l}']")
    assert_html(@html, "input.btn.btn-default")
  end

  def test_enables_turbo_by_default
    assert_html(@html, "form[data-turbo='true']")
  end

  def test_auto_determines_url_for_new_sequence
    html = render_form_without_action
    assert_html(html, "form[action*='/sequences']")
  end

  def test_renders_submit_button_for_existing_record
    @sequence = sequences(:local_sequence)
    html = render_form

    assert_html(html, "input[type='submit'][value='#{:UPDATE.l}']")
  end

  def test_omits_turbo_when_local_true
    html = render_form_local
    doc = Nokogiri::HTML(html)

    assert_nil(doc.at_css("form[data-turbo]"))
  end

  def test_auto_determines_url_for_existing_sequence
    @sequence = sequences(:local_sequence)
    html = render_form_without_action

    assert_html(html, "form[action*='/sequences/#{@sequence.id}']")
  end

  private

  def render_form
    render(Components::SequenceForm.new(
             @sequence,
             action: "/test_action",
             id: "sequence_form",
             local: false
           ))
  end

  def render_form_local
    render(Components::SequenceForm.new(
             @sequence,
             action: "/test_action",
             id: "sequence_form",
             local: true
           ))
  end

  def render_form_without_action
    render(Components::SequenceForm.new(@sequence))
  end
end
