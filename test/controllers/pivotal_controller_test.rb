# frozen_string_literal: true

require "test_helper"

class PivotalControllerTest < FunctionalTestCase
  def test_index_disabled
    enabled = MO.pivotal_enabled
    MO.pivotal_enabled = false
    get(:index)
    assert_response("index")
    MO.pivotal_enabled = enabled
  end

  def test_index_enabled
    stub_request(
      :get,
      "https://www.pivotaltracker.com/services/v5/projects/224629/stories?" \
      "fields=story_type,estimate,current_state,name,description,updated_at," \
      "labels(name),comments(created_at,text)&"\
      "filter=state:unscheduled,started,unstarted&limit=500"
    ).
      with(
        headers: {
          'Accept': "*/*",
          'Accept-Encoding': "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          'User-Agent': "Ruby",
          'X-Trackertoken': "xxx"
        }
      ).to_return(status: 200,
                  body: '[{"id":"1",
                           "story_type":"fairy tale",
                           "estimate":"Never",
                           "current_state":"unstarted",
                           "name":"Steve",
                           "description":"",
                           "labels":[{"name":"specimen"}],
                           "comments":[]},
                           {"id":"2",
                            "story_type":"biography",
                            "estimate":"Someday",
                            "current_state":"started",
                            "name":"Martha",
                            "description":"",
                            "labels":[{"name":"critical"}],
                            "comments":[]}]',
                  headers: {})
    enabled = MO.pivotal_enabled
    MO.pivotal_enabled = true
    get(:index)
    assert_response("index")
    MO.pivotal_enabled = enabled
  end
end
