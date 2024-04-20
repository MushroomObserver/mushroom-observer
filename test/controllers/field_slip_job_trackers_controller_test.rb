# frozen_string_literal: true

require("test_helper")

class FieldSlipJobTrackersControllerTest < FunctionalTestCase
  include ActiveJob::TestHelper

  test "should show tracker_row" do
    login(mary.login)
    get(:show, params: { id: field_slip_job_trackers(:fsjt_page_one).id }, as: :turbo_stream)
    assert_response :success
  end
end
