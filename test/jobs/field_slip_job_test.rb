# frozen_string_literal: true

require "test_helper"

class FieldSlipJobTest < ActiveJob::TestCase
  test "perform performs" do
    job = FieldSlipJob.new
    filename = job.perform(:an_arg)
    assert(File.exist?(filename))
    File.delete(filename)
  end
end
