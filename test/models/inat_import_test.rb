# frozen_string_literal: true

require("test_helper")

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
end
