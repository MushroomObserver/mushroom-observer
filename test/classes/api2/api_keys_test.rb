# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::APIKeysTest < UnitTestCase
  include API2Extensions

  # ----------------------------
  #  :section: APIKey Requests
  # ----------------------------

  def test_getting_api_keys
    params = {
      method: :patch,
      action: :api_key,
      api_key: @api_key.key,
      user: rolf.id
    }
    # No GET requests allowed now.
    assert_api_fail(params)
  end

  def test_posting_api_key_for_yourself
    email_count = ActionMailer::Base.deliveries.size
    @for_user = rolf
    @app = "  Mushroom  Mapper  "
    @verified = true
    params = {
      method: :post,
      action: :api_key,
      api_key: @api_key.key,
      app: @app
    }
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting api key")
    assert_obj_arrays_equal([APIKey.last], api.results)
    assert_last_api_key_correct
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:app))
    assert_equal(email_count, ActionMailer::Base.deliveries.size)
  end

  def test_posting_api_key_with_email
    email_count = ActionMailer::Base.deliveries.size
    @for_user = rolf.email
    @app = "  Mushroom  Mapper  "
    @verified = true
    params = {
      method: :post,
      action: :api_key,
      api_key: @api_key.key,
      app: @app
    }
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting api key")
    assert_obj_arrays_equal([APIKey.last], api.results)
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:app))
    assert_equal(email_count, ActionMailer::Base.deliveries.size)
  end

  def test_posting_api_key_for_another_user_without_password
    email_count = ActionMailer::Base.deliveries.size
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
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting api key")
    assert_obj_arrays_equal([APIKey.last], api.results)
    assert_last_api_key_correct
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:app))
    assert_api_fail(params.merge(app: ""))
    assert_api_fail(params.merge(for_user: 123_456))
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.size)
  end

  def test_posting_api_key_for_another_user_with_password
    email_count = ActionMailer::Base.deliveries.size
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
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting api key")
    assert_obj_arrays_equal([APIKey.last], api.results)
    assert_last_api_key_correct
    assert_api_fail(params.merge(password: "bogus"))
    assert_equal(email_count, ActionMailer::Base.deliveries.size)
  end

  def test_posting_api_key_where_key_already_exists
    email_count = ActionMailer::Base.deliveries.size
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
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting api key")
    assert_obj_arrays_equal([api_key], api.results)
    assert_api_fail(params.merge(password: "bogus"))
    assert_equal(email_count, ActionMailer::Base.deliveries.size)

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
