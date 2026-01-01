# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::APIKeysTest < UnitTestCase
  include API2Extensions
  include ActiveJob::TestHelper

  # ----------------------------
  #  :section: APIKey Requests
  # ----------------------------

  def test_page_length_methods
    api = API2::APIKeyAPI.new
    assert_equal(1000, api.high_detail_page_length)
    assert_equal(1000, api.low_detail_page_length)
    assert_equal(1000, api.put_page_length)
    assert_equal(1000, api.delete_page_length)
  end

  def test_getting_api_keys
    params = {
      method: :get,
      action: :api_key,
      api_key: @api_key.key,
      user: rolf.id
    }
    # No GET requests allowed now.
    assert_api_fail(params)
  end

  def test_posting_api_key_for_yourself
    @for_user = rolf
    @app = "  Mushroom  Mapper  "
    @verified = true
    params = {
      method: :post,
      action: :api_key,
      api_key: @api_key.key,
      app: @app
    }
    # No email sent when creating key for yourself (verified immediately)
    assert_no_enqueued_jobs do
      api = API2.execute(params)
      assert_no_errors(api, "Errors while posting api key")
      assert_obj_arrays_equal([APIKey.last], api.results)
      assert_last_api_key_correct
    end
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:app))
  end

  def test_posting_api_key_with_email
    @for_user = rolf.email
    @app = "  Mushroom  Mapper  "
    @verified = true
    params = {
      method: :post,
      action: :api_key,
      api_key: @api_key.key,
      app: @app
    }
    # No email sent when creating key for yourself (verified immediately)
    assert_no_enqueued_jobs do
      api = API2.execute(params)
      assert_no_errors(api, "Errors while posting api key")
      assert_obj_arrays_equal([APIKey.last], api.results)
    end
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:app))
  end

  def test_posting_api_key_for_another_user_without_password
    @for_user = katrina
    @app = "  Mushroom  Mapper  "
    @verified = false
    params = {
      method: :post,
      action: :api_key,
      api_key: @api_key.key,
      app: @app,
      for_user: @for_user.id
    }
    # Email sent when creating key for another user without their password
    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      api = API2.execute(params)
      assert_no_errors(api, "Errors while posting api key")
      assert_obj_arrays_equal([APIKey.last], api.results)
      assert_last_api_key_correct
    end
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:app))
    assert_api_fail(params.merge(app: ""))
    assert_api_fail(params.merge(for_user: 123_456))
  end

  def test_posting_api_key_for_another_user_with_password
    @for_user = katrina
    @app = "  Mushroom  Mapper  "
    @verified = true
    params = {
      method: :post,
      action: :api_key,
      api_key: @api_key.key,
      app: @app,
      for_user: @for_user.id,
      password: "testpassword"
    }
    # No email sent when password provided (verified immediately)
    assert_no_enqueued_jobs do
      api = API2.execute(params)
      assert_no_errors(api, "Errors while posting api key")
      assert_obj_arrays_equal([APIKey.last], api.results)
      assert_last_api_key_correct
    end
    assert_api_fail(params.merge(password: "bogus"))
  end

  def test_posting_api_key_where_key_already_exists
    api_key = api_keys(:rolfs_mo_app_api_key)
    @for_user = rolf
    @app = api_key.notes
    @verified = true
    params = {
      method: :post,
      action: :api_key,
      api_key: @api_key.key,
      app: @app,
      for_user: @for_user.id,
      password: "testpassword"
    }
    # No email sent - returns existing verified key
    assert_no_enqueued_jobs do
      api = API2.execute(params)
      assert_no_errors(api, "Errors while posting api key")
      assert_obj_arrays_equal([api_key], api.results)
    end
    assert_api_fail(params.merge(password: "bogus"))

    api_key.update(verified: nil)
    assert_nil(api_key.reload.verified)
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting api key")
    assert_not_nil(api_key.reload.verified)
  end

  def test_patching_api_keys
    params = {
      method: :patch,
      action: :api_key,
      api_key: @api_key.key,
      id: @api_key.id,
      set_app: "new app"
    }
    # No PATCH requests allowed now.
    assert_api_fail(params)
  end

  def test_deleting_api_keys
    params = {
      method: :delete,
      action: :api_key,
      api_key: @api_key.key,
      id: @api_key.id
    }
    # No DELETE requests allowed now.
    assert_api_fail(params)
  end
end
