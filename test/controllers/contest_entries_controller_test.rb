# frozen_string_literal: true

require("test_helper")

class ContestEntriesControllerTest < FunctionalTestCase
  def test_index_non_admin
    login(:rolf)
    get(:index)
    assert_flash_error
  end

  def test_index_admin
    login(:rolf)
    make_admin
    get(:index)
    assert_response(:success)
  end

  def test_show
    login(:rolf)
    make_admin
    entry = contest_entries(:entry_two)
    get(:show, params: { id: entry.id })
    assert_response(:success)
    assert_template(:show)
  end

  def test_show_bad_id
    login(:rolf)
    make_admin
    get(:show, params: { id: 0 })
    assert_response(:redirect)
  end

  def test_new
    login(:rolf)
    make_admin
    get(:new)
    assert_form_action(action: :create)
  end
end
