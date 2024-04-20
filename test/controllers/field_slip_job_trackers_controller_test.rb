# frozen_string_literal: true

require "test_helper"

class FieldSlipJobTrackersControllerTest < FunctionalTestCase
  def test_show
    login
    tracker = field_slip_job_trackers(:fsjt_page_one)
    get(:show, params: { id: tracker.id }, format: :turbo_stream)
    # response.body has the whole turbo_stream response
    assert_response(:success)
  end
end
