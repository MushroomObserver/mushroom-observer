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
    assert_redirected_to(new_account_login_path)

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
    assert_redirected_to(name_path(name.id))
    assert_equal(false, name.reload.ok_for_export)

    get(:set_export_status, params: params.merge(value: "1"))
    assert_redirected_to(name_path(name.id))
    assert_equal(true, name.reload.ok_for_export)

    get(:set_export_status, params: params.merge(value: "1", return: true))
    assert_redirected_to("/")
  end

  # Test setting ml status of images
  def ml_image
    images(:in_situ_image)
  end

  def ml_params
    {
      id: ml_image.id,
      type: "image",
      value: "1"
    }
  end

  def test_set_ml_status_login
    get(:set_ml_status, params: ml_params)
    assert_redirected_to(new_account_login_path)
  end

  def test_set_ml_status_require_reviewer
    login("dick")
    get(:set_ml_status, params: ml_params)
    assert_flash_error
  end

  def test_set_ml_status_bad_params
    login("rolf")
    params = ml_params
    get(:set_ml_status, params: params.merge(id: 9999))
    assert_flash_error
    get(:set_ml_status, params: params.merge(type: "bogus"))
    assert_flash_error
    get(:set_ml_status, params: params.merge(value: "true"))
    assert_flash_error
  end

  def test_set_ml_status_turn_off
    login("rolf")
    image = ml_image
    image.update(diagnostic: true)
    get(:set_ml_status, params: ml_params.merge(value: "0"))
    assert_redirected_to(image_path(image.id))
    assert_equal(false, image.reload.diagnostic)
  end

  def test_set_ml_status_turn_on
    login("rolf")
    image = ml_image
    image.update(diagnostic: false)
    get(:set_ml_status, params: ml_params.merge(value: "1"))
    assert_redirected_to(image_path(image.id))
    assert_equal(true, image.reload.diagnostic)
  end

  def test_set_ml_status_no_change
    login("rolf")
    image = ml_image
    image.update(diagnostic: true)
    get(:set_ml_status, params: ml_params.merge(value: "1", return: true))
    assert_redirected_to("/")
  end
end
