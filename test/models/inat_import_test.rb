# frozen_string_literal: true

require("test_helper")

class InatImportTest < ActiveSupport::TestCase
  def test_total_expected_time_tabula_rasa
    zero_out_prior_import_records
    import = inat_imports(:timings_import)

    assert_equal(import.importables * InatImport::BASE_AVG_IMPORT_SECONDS,
                 import.total_expected_time)
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
    import = inat_imports(:timings_import)

    assert_equal(import.importables * import.initial_avg_import_seconds,
                 import.total_expected_time)
  end
end
