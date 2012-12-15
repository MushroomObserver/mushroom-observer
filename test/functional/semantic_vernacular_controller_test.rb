require File.expand_path(File.dirname(__FILE__) + '/../boot')

class SemanticVernacularControllerTest < FunctionalTestCase
  
  def test_index
    begin
      get_with_dump(:index) 
      assert_response('index')
    rescue Errno::EHOSTUNREACH => err
    end
  end

  def test_show
    begin
    	get_with_dump(:show, :uri => "http://aquarius.tw.rpi.edu/ontology/svf.owl#SVD1")
    	assert_response("show")
    	assert_not_nil(assigns(:svd))
    rescue Errno::EHOSTUNREACH => err
    end
  end

end
