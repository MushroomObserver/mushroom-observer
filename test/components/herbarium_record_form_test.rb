# frozen_string_literal: true

require "test_helper"

class HerbariumRecordFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @herbarium_record = HerbariumRecord.new
    @observation = observations(:coprinus_comatus_obs)
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_herbarium_name_field
    assert_html(@html, "input[name='herbarium_record[herbarium_name]']")
    assert_html(@html, "input[data-autocompleter-target='input']")
  end

  def test_renders_form_with_initial_det_field
    assert_html(@html, "input[name='herbarium_record[initial_det]']")
  end

  def test_renders_form_with_accession_number_field
    assert_html(@html, "input[name='herbarium_record[accession_number]']")
  end

  def test_renders_form_with_notes_field
    assert_html(@html, "textarea[name='herbarium_record[notes]']")
  end

  def test_renders_submit_button_for_new_record
    assert_html(@html, "input[type='submit'][value='#{:ADD.l}']")
    assert_html(@html, "input.btn.btn-default")
  end

  def test_enables_turbo_by_default
    assert_html(@html, "form[data-turbo='true']")
  end

  def test_auto_determines_url_for_new_herbarium_record
    html = render_form_without_action
    assert_html(html, "form[action*='herbarium_records']")
  end

  def test_renders_submit_button_for_existing_record
    @herbarium_record = herbarium_records(:interesting_unknown)
    html = render_form

    assert_html(html, "input[type='submit'][value='#{:SAVE.l}']")
  end

  def test_shows_warning_for_multiple_observations
    @herbarium_record = herbarium_records(:interesting_unknown)
    # Add another observation to trigger the warning
    @herbarium_record.observations << observations(:agaricus_campestris_obs)
    html = render_form

    assert_html(html, ".multiple-observations-warning")
  end

  def test_omits_turbo_when_local_true
    html = render_form_local
    doc = Nokogiri::HTML(html)

    assert_nil(doc.at_css("form[data-turbo]"))
  end

  def test_auto_determines_url_for_existing_herbarium_record
    @herbarium_record = herbarium_records(:interesting_unknown)
    html = render_form_without_action

    assert_html(html,
                "form[action*='/herbarium_records/#{@herbarium_record.id}']")
  end

  private

  def render_form
    form = Components::HerbariumRecordForm.new(
      @herbarium_record,
      observation: @observation,
      action: "/test_action",
      id: "herbarium_record_form",
      local: false
    )
    render(form)
  end

  def render_form_local
    form = Components::HerbariumRecordForm.new(
      @herbarium_record,
      observation: @observation,
      action: "/test_action",
      id: "herbarium_record_form",
      local: true
    )
    render(form)
  end

  def render_form_without_action
    form = Components::HerbariumRecordForm.new(
      @herbarium_record,
      observation: @observation
    )
    render(form)
  end
end
