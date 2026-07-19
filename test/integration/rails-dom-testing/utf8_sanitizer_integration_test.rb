# frozen_string_literal: true

require("test_helper")

# Rack::UTF8Sanitizer (wired in config/application.rb) scrubs invalid
# UTF-8 bytes out of every incoming request, so a scanner's malformed
# bytes in a form POST can't reach a String op deep in the app and raise
# `invalid byte sequence in UTF-8` (a 500). These reproduce the shapes
# seen in the wild: POST /account/login and POST /support/confirm with
# an invalid byte (0xFF / 0xFE, URL-encoded) in a form value.
#
# Subclasses ActionDispatch::IntegrationTest directly (not
# IntegrationTestCase, which turns CSRF protection on) so the tokenless
# POST reaches the action -- CSRF is orthogonal to the byte-sanitizing
# this covers, and the 500 it guards against happens during param
# parsing/logging, before the controller's CSRF check.
class Utf8SanitizerIntegrationTest < ActionDispatch::IntegrationTest
  FORM = { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }.freeze

  def test_invalid_utf8_in_login_post_does_not_500
    post("/account/login",
         params: "user[login]=%FFabc&user[password]=x", headers: FORM)
    assert(response.status < 500,
           "login POST with invalid UTF-8 should not 500, " \
           "got #{response.status}")
  end

  def test_invalid_utf8_in_support_confirm_post_does_not_500
    post("/support/confirm",
         params: "donation[amount]=5&donation[who]=%FFbad&" \
                 "donation[email]=a%FEb&donation[anonymous]=0",
         headers: FORM)
    assert(response.status < 500,
           "confirm POST with invalid UTF-8 should not 500, " \
           "got #{response.status}")
  end
end
