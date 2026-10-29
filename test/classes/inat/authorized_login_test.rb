# frozen_string_literal: true

require("test_helper")
require_relative("../../jobs/inat_import_job_test_doubles")

class Inat::AuthorizedLoginTest < UnitTestCase
  include InatImportJobTestDoubles

  def test_returns_the_login_of_the_authorizing_inat_user
    stub_token_requests
    stub_check_username_match("someone_on_inat")

    assert_equal("someone_on_inat", Inat::AuthorizedLogin.call("MockCode"))
  end
end
