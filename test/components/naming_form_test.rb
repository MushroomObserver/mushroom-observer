# frozen_string_literal: true

require "test_helper"

class NamingFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @naming = Naming.new
    @observation = observations(:coprinus_comatus_obs)
    @vote = Vote.new
    controller.request = ActionDispatch::TestRequest.create
    @html = render_new_form
  end

  def test_renders_form_with_name_autocompleter
    assert_html(@html, "input[name='naming[name]']")
    assert_html(@html, "input[data-autocompleter--name-target='input']")
  end

  def test_renders_form_with_vote_select
    assert_html(@html, "select[name='naming[vote][value]']")
  end

  def test_renders_form_with_reasons_fields
    assert_html(@html, "input[name='naming[reasons][1][check]']")
  end

  def test_renders_form_with_context_hidden_field
    assert_html(@html, "input[type='hidden'][name='context']")
  end

  def test_renders_submit_button_for_new_naming
    assert_html(@html, "input[type='submit'][value='#{:CREATE.l}']")
    assert_html(@html, "input.btn.btn-default")
  end

  def test_renders_submit_button_for_existing_naming
    @naming = namings(:coprinus_comatus_naming)
    html = render_edit_form

    assert_html(html, "input[type='submit'][value='#{:SAVE_EDITS.l}']")
  end

  def test_auto_determines_url_for_new_naming
    assert_html(@html, "form[action*='namings']")
  end

  def test_auto_determines_url_for_existing_naming
    @naming = namings(:coprinus_comatus_naming)
    html = render_edit_form

    assert_html(html, "form[action*='/namings/#{@naming.id}']")
  end

  def test_form_id_for_new_naming
    assert_html(@html, "form[id='obs_#{@observation.id}_naming_form']")
  end

  def test_form_id_for_existing_naming
    @naming = namings(:coprinus_comatus_naming)
    html = render_edit_form

    assert_html(html,
                "form[id='obs_#{@observation.id}_naming_#{@naming.id}_form']")
  end

  def test_collapse_class_for_blank_context
    assert_html(@html,
                "div.collapse[data-autocompleter-target='collapseFields']")
  end

  def test_no_collapse_class_for_lightbox_context
    html = render_form_with_context("lightbox")

    doc = Nokogiri::HTML(html)
    collapse_div = doc.at_css("div[data-autocompleter-target='collapseFields']")
    assert_not_includes(collapse_div["class"].to_s, "collapse")
  end

  def test_includes_blank_option_for_new_naming
    assert_html(@html, "select[name='naming[vote][value]'] option[value='']")
  end

  def test_no_blank_option_for_existing_naming
    @naming = namings(:coprinus_comatus_naming)
    @vote = votes(:coprinus_comatus_owner_vote)
    html = render_edit_form

    doc = Nokogiri::HTML(html)
    selector = "select[name='naming[vote][value]'] option[value='']"
    blank_option = doc.at_css(selector)
    assert_nil(blank_option)
  end

  def test_selects_vote_value_for_existing_naming
    @naming = namings(:coprinus_comatus_naming)
    @vote = votes(:coprinus_comatus_owner_vote)
    html = render_edit_form

    assert_html(html, "option[selected][value='#{@vote.value}']")
  end

  # Test for bug: edit naming form missing vote/confidence and reasons fields
  def test_renders_vote_field_for_existing_naming_in_modal
    @naming = namings(:coprinus_comatus_naming)
    @vote = votes(:coprinus_comatus_owner_vote)
    html = render_edit_form

    assert_html(html, "select[name='naming[vote][value]']")
  end

  def test_renders_reasons_fields_for_existing_naming
    @naming = namings(:coprinus_comatus_naming)
    @vote = votes(:coprinus_comatus_owner_vote)
    html = render_edit_form

    assert_html(html, "input[name='naming[reasons][1][check]']")
  end

  def test_renders_name_feedback_when_given_name_present
    @naming = namings(:coprinus_comatus_naming)
    html = render_form_with_feedback(
      given_name: "Unknown name",
      names: []
    )

    assert_html(html, "#name_messages")
  end

  def test_renders_parent_deprecated_feedback
    @naming = namings(:coprinus_comatus_naming)
    deprecated_parent = names(:lactarius)
    html = render_form_with_feedback(
      given_name: "Some name",
      names: [names(:agaricus_campestris)],
      valid_names: [names(:coprinus_comatus)],
      parent_deprecated: deprecated_parent
    )

    assert_html(html, "#name_messages")
  end

  def test_enables_turbo_when_local_false
    html = render_form_with_local(false)
    assert_html(html, "form[data-turbo='true']")
  end

  def test_omits_turbo_when_local_true
    html = render_form_with_local(true)
    doc = Nokogiri::HTML(html)

    assert_nil(doc.at_css("form[data-turbo]"))
  end

  private

  def render_new_form
    form = Components::NamingForm.new(
      @naming,
      observation: @observation,
      vote: @vote,
      given_name: "",
      reasons: @naming.init_reasons,
      show_reasons: true,
      context: "blank",
      local: true
    )
    render(form)
  end

  def render_edit_form(given_name: "")
    form = Components::NamingForm.new(
      @naming,
      observation: @observation,
      vote: @vote,
      given_name: given_name,
      reasons: @naming.init_reasons,
      show_reasons: true,
      context: "lightbox",
      local: true
    )
    render(form)
  end

  def render_form_with_context(context)
    form = Components::NamingForm.new(
      @naming,
      observation: @observation,
      vote: @vote,
      given_name: "",
      reasons: @naming.init_reasons,
      show_reasons: true,
      context: context,
      local: true
    )
    render(form)
  end

  def render_form_with_local(local)
    form = Components::NamingForm.new(
      @naming,
      observation: @observation,
      vote: @vote,
      given_name: "",
      reasons: @naming.init_reasons,
      show_reasons: true,
      context: "blank",
      local: local
    )
    render(form)
  end

  def render_form_with_feedback(given_name:, names: nil, valid_names: nil,
                                 parent_deprecated: nil)
    form = Components::NamingForm.new(
      @naming,
      observation: @observation,
      vote: @vote,
      given_name: given_name,
      reasons: @naming.init_reasons,
      feedback: {
        names: names,
        valid_names: valid_names,
        parent_deprecated: parent_deprecated
      },
      show_reasons: true,
      context: "lightbox",
      local: true
    )
    render(form)
  end
end
