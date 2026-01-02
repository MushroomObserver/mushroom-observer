# frozen_string_literal: true

require "test_helper"

class CollectionNumberFormTest < ComponentTestCase
  def setup
    super
    @observation = observations(:coprinus_comatus_obs)
  end

  def test_new_record_form
    html = render_form(model: CollectionNumber.new)

    assert_html(html, "input[name='collection_number[name]']")
    assert_html(html, "input[name='collection_number[number]']")
    assert_html(html, "input[type='submit'][value='#{:ADD.l}']")
    assert_html(html, "input.btn.btn-default")
    assert_html(html, "form[data-turbo='true']")
  end

  def test_existing_record_form
    record = collection_numbers(:coprinus_comatus_coll_num)
    html = render_form(model: record)

    assert_html(html, "input[type='submit'][value='#{:SAVE.l}']")
  end

  def test_multiple_observations_warning
    record = collection_numbers(:coprinus_comatus_coll_num)
    record.observations << observations(:agaricus_campestris_obs)
    html = render_form(model: record)

    assert_html(html, ".multiple-observations-warning")
  end

  def test_local_form_omits_turbo
    html = render_form(model: CollectionNumber.new, local: true)

    assert_no_html(html, "form[data-turbo]")
  end

  def test_auto_url_for_new_record
    html = render_form(model: CollectionNumber.new, action: nil)

    assert_html(html, "form[action*='collection_numbers']")
  end

  def test_auto_url_for_existing_record
    record = collection_numbers(:coprinus_comatus_coll_num)
    html = render_form(model: record, action: nil)

    assert_html(html, "form[action*='/collection_numbers/#{record.id}']")
  end

  private

  def render_form(model:, action: "/test_action", local: false)
    render(Components::CollectionNumberForm.new(
             model,
             observation: @observation,
             action: action,
             id: "collection_number_form",
             local: local
           ))
  end
end
