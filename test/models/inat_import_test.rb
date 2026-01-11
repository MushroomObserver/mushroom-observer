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

  def test_mutually_exclusive_inputs
    import = inat_imports(:rolf_inat_import)

    # Valid: only inat_ids
    import.update(inat_ids: "123,456", inat_search_url: nil, import_all: false)
    assert(import.valid_input?, "Should accept only inat_ids")

    # Valid: only inat_search_url
    import.update(
      inat_ids: nil,
      inat_search_url: "https://www.inaturalist.org/observations/123",
      import_all: false
    )
    assert(import.valid_input?, "Should accept only inat_search_url")

    # Valid: only import_all
    import.update(inat_ids: nil, inat_search_url: nil, import_all: true)
    assert(import.valid_input?, "Should accept only import_all")

    # Invalid: inat_ids + inat_search_url
    import.inat_ids = "123"
    import.inat_search_url = "https://www.inaturalist.org/observations/456"
    import.import_all = false
    assert_not(import.valid_input?, "Should reject IDs + URL")

    # Invalid: none specified
    import.inat_ids = nil
    import.inat_search_url = nil
    import.import_all = false
    assert_not(import.valid_input?, "Should reject no input")
  end
end
