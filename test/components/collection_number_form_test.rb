# frozen_string_literal: true

require "test_helper"

class CollectionNumberFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @collection_number = CollectionNumber.new
    @observation = observations(:coprinus_comatus_obs)
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_name_field
    assert_html(@html, "input[name='collection_number[name]']")
  end

  def test_renders_form_with_number_field
    assert_html(@html, "input[name='collection_number[number]']")
  end

  def test_renders_submit_button_for_new_record
    assert_html(@html, "input[type='submit'][value='#{:ADD.l}']")
    assert_html(@html, "input.btn.btn-default")
  end

  def test_enables_turbo_by_default
    assert_html(@html, "form[data-turbo='true']")
  end

  def test_auto_determines_url_for_new_collection_number
    html = render_form_without_action
    assert_html(html, "form[action*='collection_numbers']")
  end

  def test_renders_submit_button_for_existing_record
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
    html = render_form

    assert_html(html, "input[type='submit'][value='#{:SAVE.l}']")
  end

  def test_shows_warning_for_multiple_observations
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
    # Add another observation to trigger the warning
    @collection_number.observations << observations(:agaricus_campestris_obs)
    html = render_form

    assert_html(html, ".multiple-observations-warning")
  end

  def test_omits_turbo_when_local_true
    html = render_form_local
    doc = Nokogiri::HTML(html)

    assert_nil(doc.at_css("form[data-turbo]"))
  end

  def test_auto_determines_url_for_existing_collection_number
    @collection_number = collection_numbers(:coprinus_comatus_coll_num)
    html = render_form_without_action

    assert_html(html, "form[action*='/collection_numbers/#{@collection_number.id}']")
  end

  private

  def render_form
    form = Components::CollectionNumberForm.new(
      @collection_number,
      observation: @observation,
      action: "/test_action",
      id: "collection_number_form",
      local: false
    )
    render(form)
  end

  def render_form_local
    form = Components::CollectionNumberForm.new(
      @collection_number,
      observation: @observation,
      action: "/test_action",
      id: "collection_number_form",
      local: true
    )
    render(form)
  end

  def render_form_without_action
    form = Components::CollectionNumberForm.new(
      @collection_number,
      observation: @observation
    )
    render(form)
  end
end
