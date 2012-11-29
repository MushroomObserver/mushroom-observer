require File.expand_path(File.dirname(__FILE__) + '/../boot')

class HerbariumControllerTest < FunctionalTestCase
  def test_show_herbarium
    nybg = herbaria(:nybg)
    assert(nybg)
    get_with_dump(:show_herbarium, :id => nybg.id)
    assert_response('show_herbarium')
  end

  def test_index
    get_with_dump(:index)
    assert_response('index')
  end
  
  def test_create_herbarium
    get(:create_herbarium)
    assert_response(:redirect)

    login('rolf')
    get_with_dump(:create_herbarium)
    assert_response('create_herbarium')
  end
  
  def create_herbarium_params
    return {
      :herbarium => {
        :name => "Rolf's Personal Herbarium",
        :description => 'Rolf wants Melanolucas!!!',
        :email => users(:rolf).email,
        :mailing_address => "",
        :place_name => ""
      }
    }
  end
  
  def test_create_herbarium_post
    login('rolf')
    params = create_herbarium_params
    post(:create_herbarium, params)
    herbarium = Herbarium.find(:all, :order => "created_at DESC")[0]
    assert_equal(params[:herbarium][:name], herbarium.name)
    assert_equal(params[:herbarium][:description], herbarium.description)
    assert_equal(params[:herbarium][:email], herbarium.email)
    assert_equal(params[:herbarium][:mailing_address], herbarium.mailing_address)
    assert_equal([users(:rolf)], herbarium.curators)
    assert_response(:redirect)
  end
  
  def test_create_herbarium_post_with_duplicate_name
    login('rolf')
    params = create_herbarium_params
    params[:herbarium][:name] = herbaria(:nybg).name
    post(:create_herbarium, params)
    assert_flash(/already exists/i)
    herbarium = Herbarium.find(:all, :order => "created_at DESC")[0]
    assert_not_equal(params[:herbarium][:description], herbarium.description)
    assert_response(:success) # Really means we go back to create_herbarium without having created one.
  end
  
  def test_create_herbarium_post_no_email
    login('rolf')
    params = create_herbarium_params
    params[:herbarium][:email] = ""
    post(:create_herbarium, params)
    assert_flash(/email address is required/i)
    herbarium = Herbarium.find(:all, :order => "created_at DESC")[0]
    assert_not_equal(params[:herbarium][:name], herbarium.name)
    assert_response(:success)
  end
  
  def test_create_herbarium_post_with_existing_place_name
    login('rolf')
    params = create_herbarium_params
    params[:herbarium][:place_name] = locations(:nybg).name
    post(:create_herbarium, params)
    herbarium = Herbarium.find(:all, :order => "created_at DESC")[0]
    assert_equal(params[:herbarium][:name], herbarium.name)
    assert_equal(params[:herbarium][:description], herbarium.description)
    assert_equal(params[:herbarium][:email], herbarium.email)
    assert_equal(params[:herbarium][:mailing_address], herbarium.mailing_address)
    assert_equal(locations(:nybg), herbarium.location)
    assert_response(:redirect)
  end
  
  def test_create_herbarium_post_with_nonexisting_place_name
    login('rolf')
    params = create_herbarium_params
    params[:herbarium][:place_name] = "Somewhere over the rainbow"
    post(:create_herbarium, params)
    herbarium = Herbarium.find(:all, :order => "created_at DESC")[0]
    assert_equal(params[:herbarium][:name], herbarium.name)
    assert_equal(params[:herbarium][:description], herbarium.description)
    assert_equal(params[:herbarium][:email], herbarium.email)
    assert_equal(params[:herbarium][:mailing_address], herbarium.mailing_address)
    assert_nil(herbarium.location)
    assert_response(:redirect)
  end

  def test_edit_herbarium
    nybg = herbaria(:nybg)
    get_with_dump(:edit_herbarium, :id => nybg.id)
    assert_response(:redirect)

    login('mary') # Non-curator
    get_with_dump(:edit_herbarium, :id => nybg.id)
    assert_flash(/non-curator/i)
    assert_response(:redirect)

    login('rolf')
    get_with_dump(:edit_herbarium, :id => nybg.id)
    assert_response('edit_herbarium')
  end
  
  def test_edit_herbarium_post
    login('rolf')
    nybg = herbaria(:nybg)
    params = create_herbarium_params
    params[:id] = nybg.id
    post(:edit_herbarium, params)
    herbarium = Herbarium.find(nybg.id)
    assert_equal(params[:herbarium][:name], herbarium.name)
    assert_equal(params[:herbarium][:description], herbarium.description)
    assert_equal(params[:herbarium][:email], herbarium.email)
    assert_equal(params[:herbarium][:mailing_address], herbarium.mailing_address)
    assert_nil(herbarium.location)
    assert_response(:redirect)
  end
  
  def test_edit_herbarium_post_with_duplicate_name
    login('rolf')
    nybg = herbaria(:nybg)
    rolf = herbaria(:rolf)
    params = create_herbarium_params
    params[:id] = nybg.id
    params[:herbarium][:name] = rolf.name
    post(:edit_herbarium, params)
    herbarium = Herbarium.find(nybg.id)
    assert_equal(nybg.name, herbarium.name)
    assert_flash(/already exists/i)
    assert_response(:success)
  end
  
  def test_edit_herbarium_post_no_name_change
    login('rolf')
    nybg = herbaria(:nybg)
    params = create_herbarium_params
    params[:herbarium][:name] = nybg.name
    params[:id] = nybg.id
    post(:edit_herbarium, params)
    herbarium = Herbarium.find(nybg.id)
    assert_equal(params[:herbarium][:name], herbarium.name)
    assert_equal(params[:herbarium][:description], herbarium.description)
    assert_equal(params[:herbarium][:email], herbarium.email)
    assert_equal(params[:herbarium][:mailing_address], herbarium.mailing_address)
    assert_nil(herbarium.location)
    assert_response(:redirect)
  end

  def test_edit_herbarium_post_no_email
    login('rolf')
    nybg = herbaria(:nybg)
    params = create_herbarium_params
    params[:id] = nybg.id
    params[:herbarium][:email] = ""
    post(:edit_herbarium, params)
    assert_flash(/email address is required/i)
    herbarium = Herbarium.find(nybg.id)
    assert_not_equal(params[:herbarium][:email], herbarium.email)
    assert_response(:success)
  end
  
  def test_edit_herbarium_post_with_existing_place_name
    login('rolf')
    nybg = herbaria(:nybg)
    params = create_herbarium_params
    params[:id] = nybg.id
    params[:herbarium][:place_name] = locations(:salt_point).name
    post(:edit_herbarium, params)
    herbarium = Herbarium.find(nybg.id)
    assert_equal(params[:herbarium][:name], herbarium.name)
    assert_equal(params[:herbarium][:description], herbarium.description)
    assert_equal(params[:herbarium][:email], herbarium.email)
    assert_equal(params[:herbarium][:mailing_address], herbarium.mailing_address)
    assert_equal(locations(:salt_point), herbarium.location)
    assert_response(:redirect)
  end
  
  def test_edit_herbarium_post_with_nonexisting_place_name
    login('rolf')
    nybg = herbaria(:nybg)
    params = create_herbarium_params
    params[:id] = nybg.id
    params[:herbarium][:place_name] = "Somewhere over the rainbow"
    post(:edit_herbarium, params)
    herbarium = Herbarium.find(nybg.id)
    assert_equal(params[:herbarium][:name], herbarium.name)
    assert_equal(params[:herbarium][:description], herbarium.description)
    assert_equal(params[:herbarium][:email], herbarium.email)
    assert_equal(params[:herbarium][:mailing_address], herbarium.mailing_address)
    assert_nil(herbarium.location)
    assert_response(:redirect)
  end
  
  def test_edit_herbarium_post_by_non_curator
    login('mary')
    nybg = herbaria(:nybg)
    old_name = nybg.name
    params = create_herbarium_params
    params[:id] = nybg.id
    post(:edit_herbarium, params)
    assert_flash(/non-curator/i)
    herbarium = Herbarium.find(nybg.id)
    assert_not_equal(params[:herbarium][:name], herbarium.name)
    assert_equal(old_name, herbarium.name)
    assert_response(:redirect)
  end
  
  def test_add_specimen
    get(:add_specimen)
    assert_response(:redirect)

    login('rolf')
    get_with_dump(:add_specimen, :id => observations(:coprinus_comatus_obs).id)
    assert_response('add_specimen')
    assert(assigns(:herbarium_label))
    assert(assigns(:herbarium_name))
  end
  
  def test_add_specimen_no_obs
    login('rolf')
    get_with_dump(:add_specimen)
    assert_response(:redirect)
  end
  
  def add_specimen_params
    return {
      :id => observations(:coprinus_comatus_obs).id,
      :specimen => {
        :herbarium_name => users(:rolf).preferred_herbarium_name,
        :herbarium_label => "Coprinus comatus (O.F. Mull.) Pers. det. Rolf Singer - NYBG 1234567",
        'when(1i)'      => '2012',
        'when(2i)'      => '11',
        'when(3i)'      => '26',
        :notes => "Some notes about this specimen"
      }
    }
  end
  
  def test_add_specimen_post
    login('rolf')
    specimen_count = Specimen.count
    params = add_specimen_params
    post(:add_specimen, params)
    assert_equal(specimen_count + 1, Specimen.count)
    specimen = Specimen.find(:all, :order => "created_at DESC")[0]
    assert_equal(params[:specimen][:herbarium_name], specimen.herbarium.name)
    assert_equal(params[:specimen][:herbarium_label], specimen.herbarium_label)
    assert_equal(params[:specimen]['when(1i)'].to_i, specimen.when.year)
    assert_equal(params[:specimen]['when(2i)'].to_i, specimen.when.month)
    assert_equal(params[:specimen]['when(3i)'].to_i, specimen.when.day)
    assert_equal(users(:rolf), specimen.user)
    assert_response(:redirect)
  end
  
  def test_add_specimen_post_new_herbarium
    mary = login('mary')
    herbarium_count = mary.curated_herbaria.count
    # Count the number of herbaria that mary is a curator for
    params = add_specimen_params
    params[:specimen][:herbarium_name] = mary.preferred_herbarium_name
    post(:add_specimen, params)
    mary = User.find(mary.id) # Reload user
    assert_equal(herbarium_count+1, mary.curated_herbaria.count)
    herbarium = Herbarium.find(:all, :order => "created_at DESC")[0]
    assert(herbarium.curators.member?(mary))
  end
  
  def test_add_specimen_post_duplicate
    login('rolf')
    specimen_count = Specimen.count
    params = add_specimen_params
    existing_specimen = specimens(:coprinus_comatus_spec)
    params[:specimen][:herbarium_name] = existing_specimen.herbarium.name
    params[:specimen][:herbarium_label] = existing_specimen.herbarium_label
    post(:add_specimen, params)
    assert_equal(specimen_count, Specimen.count)
    assert_flash(/already exists/i)    
    assert_response(:success)
  end

  def test_show_specimen
    specimen = specimens(:coprinus_comatus_spec)
    assert(specimen)
    get_with_dump(:show_specimen, :id => specimen.id)
    assert_response('show_specimen')
  end
end
