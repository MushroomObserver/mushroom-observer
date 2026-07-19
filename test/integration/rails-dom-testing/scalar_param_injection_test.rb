# frozen_string_literal: true

require("test_helper")

# Automated SQL-injection scanners send a scalar request param as a
# nested hash (e.g. `?letter[foo]=bar`), which Rails parses into an
# ActionController::Parameters object. When such a value reached a
# String-only sink -- an ActiveRecord bind, a Literal `String` prop,
# `String#to_sym` -- it raised a 500. `ApplicationController#string_param`
# now coerces a non-scalar to nil, so the request is served normally.
#
# These exercise the exact shapes seen in the wild (a time-based blind
# SQLi payload as the hash key).
class ScalarParamInjectionTest < IntegrationTestCase
  BAD = {
    "information_schema where (select 0) or sleep(30)" => { "1" => "1" }
  }.freeze

  # set_locale is a before_action on every request -> params_locale.
  def test_hash_shaped_user_locale_is_ignored_not_500
    get("/articles", params: { user_locale: BAD })
    assert_response(:success)
  end

  # articles#index renders the letter-pagination nav (a String prop).
  def test_hash_shaped_letter_is_ignored_not_500
    get("/articles", params: { letter: BAD })
    assert_response(:success)
  end

  # images#show -> set_default_size does `params[:size].to_sym`.
  def test_hash_shaped_image_size_is_ignored_not_500
    get("/images/#{images(:in_situ_image).id}", params: { size: BAD })
    assert_response(:success)
  end
end
