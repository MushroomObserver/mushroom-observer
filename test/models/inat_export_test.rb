# frozen_string_literal: true

require("test_helper")

class InatExportTest < ActiveSupport::TestCase
  def test_total_expected_time_tabula_rasa
    skip("Under Construction")
    zero_out_prior_export_records
    export = inat_exports(:rolf_inat_export)

    assert_equal(
      export.exportables * InatExport::BASE_AVG_EXPORT_SECONDS,
      export.total_expected_time,
      "If nobody has exported any MO observations, " \
      "total expected time for the 1st export should be the system default"
    )
  end

  def zero_out_prior_export_records
    skip("Under Construction")
    prior_exports = InatExport.where.not(total_exported_count: nil)
    prior_exports.each do |export|
      export.update(total_exported_count: nil, total_seconds: nil)
    end
  end

  def test_total_expected_time_user_without_prior_exports
    skip("Under Construction")
    export = inat_exports(:rolf_inat_export)

    assert_equal(
      export.exportables *
        InatExport.sum(:total_seconds) / InatExport.sum(:total_exported_count),
      export.total_expected_time
    )
  end

  def test_total_expected_time_user_with_prior_exports
    skip("Under Construction")
    export = inat_exports(:roy_inat_export)

    assert_equal(export.exportables * export.initial_avg_export_seconds,
                 export.total_expected_time)
  end
end
