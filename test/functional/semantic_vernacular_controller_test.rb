require File.expand_path(File.dirname(__FILE__) + '/../boot')

class SemanticVernacularControllerTest < FunctionalTestCase
  
  def test_index
    get_with_dump(:index) 
    assert_response('index')
    assert_not_nil(assigns(:all))
  end

  def test_show
  	get_with_dump(:show, :uri => "http://aquarius.tw.rpi.edu/ontology/fungi.owl#PineSpike")
  	assert_response("show")
  	assert_not_nil(assigns(:svd))
  end

end
