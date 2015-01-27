
require "test_helper"

class SemanticVernacularControllerTest < FunctionalTestCase
  def test_index
    begin
      get(:index)
      assert_response(:redirect)
      login
      get_with_dump(:index)
      assert_template(:index)
    rescue Errno::EHOSTUNREACH => err
    end
  end

  def test_show
  uri = "http://aquarius.tw.rpi.edu/ontology/svf.owl#SVD1"
    begin
    	get(:show, uri: uri)
    	assert_response(:redirect)
    	login
    	get_with_dump(:show, uri: uri)
      assert_template(:show)
    	assert_not_nil(assigns(:svd))
    rescue Errno::EHOSTUNREACH => err
    rescue ActionView::TemplateError => err
    end
  end

  # Need a real test framework to do anything meaningful.
  # In the meantime, simply ensure that both logged out and logged in users get
  # redirected since delete requires admin.
  def test_delete
    begin
      get(:delete)
      assert_response(:redirect)
      login
      get(:delete)
      assert_response(:redirect)
    rescue Errno::EHOSTUNREACH => err
    end
  end
end
