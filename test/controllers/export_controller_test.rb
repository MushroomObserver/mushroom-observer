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
    put(:set_export_status, params: params)
    assert_redirected_to(new_account_login_path)

    # Require reviewer.
    login("dick")
    put(:set_export_status, params: params)
    assert_flash_error
    logout

    # Require correct params.
    login("rolf")
    put(:set_export_status, params: params.merge(id: 9999))
    assert_flash_error
    put(:set_export_status, params: params.merge(type: "bogus"))
    assert_flash_error
    put(:set_export_status, params: params.merge(value: "true"))
    assert_flash_error

    # Now check *correct* usage.
    assert_equal(true, name.reload.ok_for_export)
    put(:set_export_status, params: params.merge(value: "0"))
    assert_redirected_to(name_path(name.id))
    assert_equal(false, name.reload.ok_for_export)

    put(:set_export_status, params: params.merge(value: "1"))
    assert_redirected_to(name_path(name.id))
    assert_equal(true, name.reload.ok_for_export)

    put(:set_export_status, params: params.merge(value: "1", return: true))
    assert_redirected_to("/")
  end

  def test_set_export_status_turbo_stream
    name = names(:petigera)
    name.update(ok_for_export: true)
    login("rolf")

    put(:set_export_status,
        params: { id: name.id, type: "name", value: "0" },
        format: :turbo_stream)

    assert_response(:success)
    assert_equal("text/vnd.turbo-stream.html", response.media_type)
    assert_equal(false, name.reload.ok_for_export)

    dom_id = ActionView::RecordIdentifier.dom_id(name, :ok_for_export)
    assert_select("turbo-stream[action='replace'][target='#{dom_id}']") do
      # New current state ("Not exportable") is now bold; the flip
      # target ("OK to export") is now the PUT-method button.
      assert_select("b", text: :review_no_export.t)
      assert_select("form button[type='submit'][data-turbo='true']",
                    text: :review_ok_for_export.t)
    end
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
    put(:set_ml_status, params: ml_params)
    assert_redirected_to(new_account_login_path)
  end

  def test_set_ml_status_require_reviewer
    login("dick")
    put(:set_ml_status, params: ml_params)
    assert_flash_error
  end

  def test_set_ml_status_bad_params
    login("rolf")
    params = ml_params
    put(:set_ml_status, params: params.merge(id: 9999))
    assert_flash_error
    put(:set_ml_status, params: params.merge(type: "bogus"))
    assert_flash_error
    put(:set_ml_status, params: params.merge(value: "true"))
    assert_flash_error
  end

  def test_set_ml_status_turn_off
    login("rolf")
    image = ml_image
    image.update(diagnostic: true)
    put(:set_ml_status, params: ml_params.merge(value: "0"))
    assert_redirected_to(image_path(image.id))
    assert_equal(false, image.reload.diagnostic)
  end

  def test_set_ml_status_turn_on
    login("rolf")
    image = ml_image
    image.update(diagnostic: false)
    put(:set_ml_status, params: ml_params.merge(value: "1"))
    assert_redirected_to(image_path(image.id))
    assert_equal(true, image.reload.diagnostic)
  end

  def test_set_ml_status_no_change
    login("rolf")
    image = ml_image
    image.update(diagnostic: true)
    put(:set_ml_status, params: ml_params.merge(value: "1", return: true))
    assert_redirected_to("/")
  end

  def test_set_ml_status_turbo_stream
    image = ml_image
    image.update(diagnostic: false)
    login("rolf")

    put(:set_ml_status,
        params: ml_params.merge(value: "1"),
        format: :turbo_stream)

    assert_response(:success)
    assert_equal("text/vnd.turbo-stream.html", response.media_type)
    assert_equal(true, image.reload.diagnostic)

    dom_id = ActionView::RecordIdentifier.dom_id(image, :diagnostic)
    assert_select("turbo-stream[action='replace'][target='#{dom_id}']") do
      assert_select("b", text: :review_diagnostic.t)
      assert_select("form button[type='submit'][data-turbo='true']",
                    text: :review_non_diagnostic.t)
    end
  end
end
