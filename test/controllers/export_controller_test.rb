# frozen_string_literal: true

require("test_helper")

# Controller tests for setting export state of various objects
class ExportControllerTest < FunctionalTestCase
  # Test setting export status of names and descriptions.
  def test_set_export_status
    name = names(:petigera)
    params = {
      id: name.id,
      type: "name",
      value: "1"
    }

    # Require login.
    get(:set_export_status, params: params)
    assert_redirected_to(controller: :account, action: :login)

    # Require reviewer.
    login("dick")
    get(:set_export_status, params: params)
    assert_flash_error
    logout

    # Require correct params.
    login("rolf")
    get(:set_export_status, params: params.merge(id: 9999))
    assert_flash_error
    get(:set_export_status, params: params.merge(type: "bogus"))
    assert_flash_error
    get(:set_export_status, params: params.merge(value: "true"))
    assert_flash_error

    # Now check *correct* usage.
    assert_equal(true, name.reload.ok_for_export)
    get(:set_export_status, params: params.merge(value: "0"))
    assert_redirected_to(controller: :name, action: :show_name, id: name.id)
    assert_equal(false, name.reload.ok_for_export)

    get(:set_export_status, params: params.merge(value: "1"))
    assert_redirected_to(controller: :name, action: :show_name, id: name.id)
    assert_equal(true, name.reload.ok_for_export)

    get(:set_export_status, params: params.merge(value: "1", return: true))
    assert_redirected_to("/")
  end
end
