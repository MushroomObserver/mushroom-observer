# frozen_string_literal: true

require "test_helper"

class InatImportTest < ActiveSupport::TestCase
  def test_total_expected_time_tabula_rasa
    zero_out_prior_import_records
    import = inat_imports(:rolf_inat_import)

    assert_equal(
      import.importables * InatImport::BASE_AVG_IMPORT_SECONDS,
      import.total_expected_time,
      "If nobody has imported anhy iNat obss, " \
      "total expected time for the 1st import should be the system default"
    )
  end

  def zero_out_prior_import_records
    prior_imports = InatImport.where.not(total_imported_count: nil)
    prior_imports.each do |import|
      import.update(total_imported_count: nil, total_seconds: nil)
    end
  end

  def test_total_expected_time_user_without_prior_imports
    import = inat_imports(:rolf_inat_import)

    assert_equal(
      import.importables *
        InatImport.sum(:total_seconds) / InatImport.sum(:total_imported_count),
      import.total_expected_time
    )
  end

  def test_total_expected_time_user_with_prior_imports
    import = inat_imports(:roy_inat_import)

    assert_equal(import.importables * import.initial_avg_import_seconds,
                 import.total_expected_time)
  end

  def test_adequate_constraints
    assert(
      inat_imports(:rolf_inat_import).adequate_constraints?,
      "iNat username adequately constrains imports"
    )

    assert_not(
      inat_imports(:ollie_inat_import).adequate_constraints?,
      "Import without an iNat username does not adequately constrain imports"
    )

    # Not-own superimporter: needs username OR specific IDs
    superimporter_import = inat_imports(:dick_inat_import)

    not_own_with_username_import = superimporter_import.dup.tap do |i|
      i.import_others = true
      i.inat_username = "some_user"
      i.inat_ids = ""
    end
    assert(not_own_with_username_import.adequate_constraints?,
           "Not-own import with username should be adequately constrained")

    not_own_with_ids_import = superimporter_import.dup.tap do |i|
      i.import_others = true
      i.inat_username = ""
      i.inat_ids = "123,456"
    end
    assert(not_own_with_ids_import.adequate_constraints?,
           "Not-own import with specific IDs should be adequately constrained")

    not_own_no_constraints_import = superimporter_import.dup.tap do |i|
      i.import_others = true
      i.inat_username = ""
      i.inat_ids = ""
    end
    assert_not(not_own_no_constraints_import.adequate_constraints?,
               "Not-own import with no username or IDs should " \
               "not be adequately constrained")
  end

  def test_super_importer
    assert(
      InatImport.super_importer?(users(:dick)),
      "Dick is a super importer"
    )
    assert_not(
      InatImport.super_importer?(users(:roy)),
      "Roy is not a super importer"
    )
  end

  def test_add_response_error_with_exception
    import = inat_imports(:rolf_inat_import)
    error = StandardError.new("Exception error message")

    import.add_response_error(error)
    import.reload

    assert_match(/Exception error message/, import.response_errors)
  end

  def test_add_response_error_with_rest_client_response
    import = inat_imports(:rolf_inat_import)
    net_res = Net::HTTPBadRequest.new("1.1", 400, "Bad Request")
    req = RestClient::Request.new(method: :get, url: "http://example.com")
    response = RestClient::Response.create("iNat API error", net_res, req)

    import.add_response_error(response)
    import.reload

    assert_match(/iNat API error/, import.response_errors,
                 "RestClient::Response body should be added to response_errors")
  end

  def test_response_errors_initialized_on_new_instance
    import = InatImport.new(user: users(:rolf))

    assert_not_nil(import.response_errors,
                   "response_errors should be initialized to empty string")
    assert_equal("", import.response_errors,
                 "response_errors should be initialized to empty string")
  end

  def test_add_response_error_without_prior_errors
    import = InatImport.new(user: users(:rolf))
    import.save!

    import.add_response_error("Test error message")

    assert_match(/Test error message/, import.response_errors,
                 "Error message should be added to response_errors")
  end
end
