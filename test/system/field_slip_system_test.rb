# frozen_string_literal: true

require "application_system_test_case"

class FieldSlipSystemTest < ApplicationSystemTestCase
  setup do
    @field_slip = field_slips(:field_slip_one)
  end

  def test_create_update_delete_field_slip
    login!(mary)
    visit(field_slips_url)
    assert_selector("h1", text: :FIELD_SLIPS.t)

    first(class: /field_slip_link_/).click
    assert_text(:field_slip_index.t)

    click_on(:field_slip_edit.t, match: :first)

    fill_in(:field_slip_code.t, with: @field_slip.code)
    select(@field_slip.project.title, from: :PROJECT.t)
    click_on(:field_slip_keep_obs.t)

    assert_text(:field_slip_updated.t)

    visit(field_slip_url(@field_slip))
    click_on(:field_slip_destroy.t, match: :first)

    assert_text(:field_slip_destroyed.t)
  end
end
