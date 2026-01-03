# frozen_string_literal: true

require "test_helper"

class HerbariumRecordFormTest < ComponentTestCase
  def setup
    super
    @observation = observations(:coprinus_comatus_obs)
  end

  def test_new_record_form
    html = render_form(model: HerbariumRecord.new)

    assert_html(html, "input[name='herbarium_record[herbarium_name]']")
    assert_html(html, "input[data-autocompleter--herbarium-target='input']")
    assert_html(html, "input[name='herbarium_record[initial_det]']")
    assert_html(html, "input[name='herbarium_record[accession_number]']")
    assert_html(html, "textarea[name='herbarium_record[notes]']")
    assert_html(html, "input[type='submit'][value='#{:ADD.l}']")
    assert_html(html, "input.btn.btn-default")
    assert_html(html, "form[data-turbo='true']")
  end

  def test_existing_record_form
    record = herbarium_records(:interesting_unknown)
    html = render_form(model: record)

    assert_html(html, "input[type='submit'][value='#{:SAVE.l}']")
  end

  def test_multiple_observations_warning
    record = herbarium_records(:interesting_unknown)
    record.observations << observations(:agaricus_campestris_obs)
    html = render_form(model: record)

    assert_html(html, ".multiple-observations-warning")
  end

  def test_local_form_omits_turbo
    html = render_form(model: HerbariumRecord.new, local: true)

    assert_no_html(html, "form[data-turbo]")
  end

  def test_auto_url_for_new_record
    html = render_form(model: HerbariumRecord.new, action: nil)

    assert_html(html, "form[action*='herbarium_records']")
  end

  def test_auto_url_for_existing_record
    record = herbarium_records(:interesting_unknown)
    html = render_form(model: record, action: nil)

    assert_html(html, "form[action*='/herbarium_records/#{record.id}']")
  end

  private

  def render_form(model:, action: "/test_action", local: false)
    render(Components::HerbariumRecordForm.new(
             model,
             observation: @observation,
             action: action,
             id: "herbarium_record_form",
             local: local
           ))
  end
end
