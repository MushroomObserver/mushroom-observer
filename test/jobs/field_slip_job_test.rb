# frozen_string_literal: true

require "test_helper"

class FieldSlipJobTest < ActiveJob::TestCase
  test "it should perform" do
    job = FieldSlipJob.new
    filename = "public/field_slips/perform.pdf"
    job.perform(projects(:eol_project).id, 1234, 12, filename)
    assert(File.exist?(filename))
    File.delete(filename)
  end
end
