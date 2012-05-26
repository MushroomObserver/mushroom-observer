require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class ApiTest < UnitTestCase
  def test_basic_gets
    for model in [ Comment, Image, Location, Name, Observation, Project,
                   SpeciesList, User ]
      expected_object = model.find(1)
      api = API.execute(:method => :get, :action => model.type_tag, :id => 1)
      assert_obj_list_equal([expected_object], api.results, "Failed to get first #{model}")
    end
  end
end
