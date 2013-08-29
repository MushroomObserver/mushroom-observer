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
    login
    user = @rolf
    params = create_term_params
    post(:create_term, params)
    term = Term.find(:all, :order => "created_at DESC")[0]
    assert_equal(params[:term][:name], term.name)
    assert_equal(params[:term][:description], term.description)
    assert_equal(@rolf.id, term.user_id)
    assert_response(:redirect)
  end

  def test_edit_term
    conic = terms(:conic_term)
    get_with_dump(:edit_term, :id => conic.id)
    assert_response(:redirect)

    make_admin
    get_with_dump(:edit_term, :id => conic.id)
    assert_response('edit_term')
  end
  
  def test_edit_term_post
    conic = terms(:conic_term)
    count = Term::Version.count
    make_admin
    user = @rolf

    params = create_term_params
    params[:id] = conic.id
    post(:edit_term, params)
    conic.reload
    assert_equal(params[:term][:name], conic.name)
    assert_equal(params[:term][:description], conic.description)
    assert_equal(count+1, Term::Version.count)
    assert_response(:redirect)
  end

  def test_show_past_term
    login
    term = terms(:plane_term)
    old_count = term.versions.length
    term.update_attributes(:description => 'Are we flying yet?')
    term.reload
    new_count = term.versions.length
    assert_equal(1, new_count - old_count)
    get_with_dump(:show_past_term, :id => term.id)
    assert_response('show_past_term')
  end

end
