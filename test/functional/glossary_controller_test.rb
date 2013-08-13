require File.expand_path(File.dirname(__FILE__) + '/../boot')

class GlossaryControllerTest < FunctionalTestCase
  def test_show_term
    conic = terms(:conic_term)
    get_with_dump(:show_term, :id => conic.id)
    assert_response('show_term')
  end

  def test_index
    get_with_dump(:index)
    assert_response('index')
  end

  def test_create_term
    get(:create_term)
    assert_response(:redirect)

    login
    get_with_dump(:create_term)
    assert_response('create_term')
  end
  
  def create_term_params
    return {
      :term => {
        :name => 'Convex',
        :description => 'Boring old convex',
        :upload_image => nil
      },
      :copyright_holder => "Insil Choi",
      :date => {
        :copyright_year => '2013'
      },
      :upload => {
        :license_id => '1'
      }
    }
  end
  
  def test_create_term_post
    make_admin
    user = @rolf
    params = create_term_params
    post(:create_term, params)
    term = Term.find(:all, :order => "created_at DESC")[0]
    assert_equal(params[:term][:name], term.name)
    assert_equal(params[:term][:description], term.description)
    assert_response(:redirect)
  end
  
end
