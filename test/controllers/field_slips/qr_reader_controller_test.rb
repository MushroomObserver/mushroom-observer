# frozen_string_literal: true

require("test_helper")

module FieldSlips
  class QRReaderControllerTest < FunctionalTestCase
    def test_new
      login
      get(:new)
      assert_template("field_slips/qr_reader/new")
    end

    def test_create
      login
      code = "NEW-1234"
      post(:create, params: { field_slip: { code: code } })
      assert_redirected_to("#{MO.http_domain}/qr/#{code}")
    end

    def test_create_mo_url
      login
      code = "NEW-1234"
      post(:create,
           params: { field_slip:
                     { code: "http://mushroomobserver.org/qr/#{code}" } })
      assert_redirected_to("#{MO.http_domain}/qr/#{code}")
    end

    def test_create_bad_url
      login
      code = "http://realbad.com"
      post(:create, params: { field_slip: { code: code } })
      assert_redirected_to(field_slips_qr_reader_new_path)
    end
  end
end
