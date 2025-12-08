# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::UsersTest < UnitTestCase
  include API2Extensions
  include ActiveJob::TestHelper

  def test_basic_user_get
    do_basic_get_test(User)
  end

  # --------------------------
  #  :section: User Requests
  # --------------------------

  def params_get(**)
    { method: :get, action: :user }.merge(**)
  end

  def test_getting_users
    assert_api_pass(params_get(detail: :low))
    assert_api_results(User.all)
  end

  def usr_samples
    @usr_samples ||= User.all.sample(3)
  end

  def test_getting_users_ids
    assert_api_pass(params_get(id: usr_samples.map(&:id).join(",")))
    assert_api_results(usr_samples)
  end

  def test_posting_minimal_user
    @login = "stephane"
    @name = ""
    @email = "stephane@grappelli.com"
    @locale = "en"
    @notes = ""
    @license = License.preferred
    @location = nil
    @image = nil
    @address = ""
    @new_key = nil
    params = {
      method: :post,
      action: :user,
      api_key: @api_key.key,
      login: @login,
      email: @email,
      password: "secret"
    }
    # No API key requested, so no VerifyAccount email should be queued
    api = API2.execute(params)
    assert_no_errors(api, "Errors while posting user")
    assert_obj_arrays_equal([User.last], api.results)
    assert_last_user_correct
    assert_api_fail(params)
    params[:login] = "miles"
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:login))
    assert_api_fail(params.except(:email))
    assert_api_fail(params.merge(login: "x" * 1000))
    assert_api_fail(params.merge(email: "x" * 1000))
    assert_api_fail(params.merge(email: "bogus address @ somewhere dot com"))
  end

  def test_posting_maximal_user
    @login = "stephane"
    @name = "Stephane Grappelli"
    @email = "_Rea||y+{$tran&e}-e#ai1!?_@123.whosi-whatsit.com"
    @locale = "el"
    @notes = " Here are some notes\nThey look like this!\n "
    @license = (License.where(deprecated: false) - [License.preferred]).first
    @location = Location.last
    @image = Image.last
    @address = " I live here "
    @new_key = "  Blah  Blah  Blah  "
    params = {
      method: :post,
      action: :user,
      api_key: @api_key.key,
      login: @login,
      name: @name,
      email: @email,
      password: "supersecret",
      locale: @locale,
      notes: @notes,
      license: @license.id,
      location: @location.id,
      image: @image.id,
      mailing_address: @address,
      create_key: @new_key
    }
    # With create_key, VerifyAccount email should be queued
    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: ->(args) { args[0] == "VerifyAccountMailer" && args[1] == "build" }
    ) do
      api = API2.execute(params)
      assert_no_errors(api, "Errors while posting user")
      assert_obj_arrays_equal([User.last], api.results)
      assert_last_user_correct
    end
    params[:login] = "miles"
    assert_api_fail(params.merge(name: "x" * 1000))
    assert_api_fail(params.merge(locale: "xx"))
    assert_api_fail(params.merge(license: "123456"))
    assert_api_fail(params.merge(location: "123456"))
    assert_api_fail(params.merge(image: "123456"))
  end

  def test_patching_users
    params = {
      method: :patch,
      action: :user,
      api_key: @api_key.key,
      id: rolf.id,
      set_locale: "pt",
      set_notes: "some notes",
      set_mailing_address: "somewhere, USA",
      set_license: licenses(:publicdomain).id,
      set_location: locations(:burbank).id,
      set_image: images(:peltigera_image).id
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.merge(set_image: mary.images.first.id))
    assert_api_fail(params.merge(set_locale: ""))
    assert_api_fail(params.merge(set_license: ""))
    assert_api_pass(params)
    rolf.reload
    assert_equal("pt", rolf.locale)
    assert_equal("some notes", rolf.notes)
    assert_equal("somewhere, USA", rolf.mailing_address)
    assert_objs_equal(licenses(:publicdomain), rolf.license)
    assert_objs_equal(locations(:burbank), rolf.location)
    assert_objs_equal(images(:peltigera_image), rolf.image)
  end

  def test_deleting_users
    params = {
      method: :delete,
      action: :user,
      api_key: @api_key.key # (rolf's)
    }

    # Rolf can't delete Mary.
    assert_api_fail(params.merge(id: mary.id))

    # Rolf can delete himself, but since he has a comment on one of Mary's
    # observations, his account is just disabled, not destroyed.
    assert_api_pass(params.merge(id: rolf.id))
    assert_not_nil(User.find_by(id: rolf.id))
    rolf.reload
    assert_blank(rolf.password)
    assert_blank(rolf.email)
    assert_blank(rolf.mailing_address)
    assert_true(rolf.blocked)

    zero = users(:zero_user)
    zeros_api_key = APIKey.create!(
      user: zero,
      key: "whatever",
      notes: "blah",
      verified: Time.zone.now
    )

    # Zero can also delete himself, and since he hasn't done anything,
    # it should actually fully destroy the account.
    assert_api_pass(params.merge(api_key: zeros_api_key.key, id: zero.id))
    assert_nil(User.find_by(id: zero.id))
  end
end
