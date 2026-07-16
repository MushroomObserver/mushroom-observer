# frozen_string_literal: true

require("test_helper")

class RefreshNameListerCacheJobTest < ActiveJob::TestCase
  include GeneralExtensions

  def test_perform_writes_cache_file
    output_file = MO.name_lister_cache_file
    FileUtils.rm(output_file) if File.exist?(output_file)

    RefreshNameListerCacheJob.perform_now

    assert_path_exists(output_file,
                       "Job should have written #{output_file}")
    output = File.read(output_file)
    fixture = Rails.root.join("test/reports/name_list_data.js")
    if sql_collates_accents?
      assert_string_equal_file(output, fixture)
    else
      expect = fixture.read
      assert_equal(expect.tr("ü", "u"), output.tr("ü", "u"),
                   "File #{output} is wrong.")
    end
  end
end
