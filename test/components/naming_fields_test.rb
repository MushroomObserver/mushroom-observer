# frozen_string_literal: true

require "test_helper"

class NamingFieldsTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @naming = Naming.new
    @vote = Vote.new
    @reasons = @naming.init_reasons
    controller.request = ActionDispatch::TestRequest.create
  end

  # Test for bug: edit naming form missing vote/confidence and reasons fields
  def test_renders_vote_field_for_existing_naming
    @naming = namings(:coprinus_comatus_naming)
    @vote = votes(:coprinus_comatus_owner_vote)
    html = render_fields(create: false)

    assert_html(html, "select[name='naming[vote][value]']")
  end

  def test_renders_vote_field_for_new_naming
    html = render_fields(create: true)

    assert_html(html, "select[name='naming[vote][value]']")
  end

  def test_renders_reasons_fields_when_show_reasons_true
    html = render_fields(create: true, show_reasons: true)

    assert_html(html, "input[name*='reasons']")
  end

  def test_renders_name_autocompleter
    html = render_fields(create: true)

    assert_html(html, "input[name='naming[name]']")
  end

  private

  def render_fields(create: true, show_reasons: true, context: "lightbox")
    component = Components::NamingFields.new(
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
