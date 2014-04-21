require File.expand_path(File.dirname(__FILE__) + '/../boot')

class PublicationsControllerTest < FunctionalTestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:publications)
  end

  def test_should_get_new
    login
    get :new
    assert_response :success
  end

  def test_should_create_publication
    login
    assert_difference('Publication.count') do
      post :create, :publication => { }
    end

    assert_redirected_to publication_path(assigns(:publication))
  end

  def test_should_not_create_publication
    login 'spamspamspam'
    assert_no_difference('Publication.count') do
      post :create, :publication => { }
    end
  end

  def test_should_show_publication
    get :show, :id => publications(:one).id
    assert_response :success
  end

  def test_should_get_edit
    login
    get :edit, :id => publications(:one).id
    assert_response :success
  end

  def test_should_update_publication
    login
    put :update, :id => publications(:one).id, :publication => { }
    assert_redirected_to publication_path(assigns(:publication))
  end

  def test_should_destroy_publication
    login
    assert_difference('Publication.count', -1) do
      delete :destroy, :id => publications(:one).id
    end

    assert_redirected_to publications_path
  end
end
