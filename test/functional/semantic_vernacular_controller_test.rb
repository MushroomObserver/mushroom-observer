require File.expand_path(File.dirname(__FILE__) + '/../boot')

class SemanticVernacularControllerTest < FunctionalTestCase
  
  def test_index
    get_with_dump(:index) 
    assert_response('index')
  end

  def test_show
  	get_with_dump(:show, :uri => "http://aquarius.tw.rpi.edu/ontology/svf.owl#SVD1")
  	assert_response("show")
  	assert_not_nil(assigns(:svd))
  end

end
