# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../boot')

class CuratorTest < IntegrationTestCase
  def test_first_specimen
    # login as mary (who doesn't have a herbarium)
    login('mary', 'testpassword', :true)
    get('/1')
    assert_template('observer/show_observation')
    click(:label => :show_observation_create_specimen.t)
    assert_template('specimen/add_specimen')
    open_form do |form|
      form.submit('Add')
    end
    assert_template('herbarium/edit_herbarium')
  end
  
  def test_herbarium_index_from_add_specimen
    login('mary', 'testpassword', :true)
    get('specimen/add_specimen/1')
    click(:label => :herbarium_index.t)
    assert_template('herbarium/index')
  end
  
  def test_single_herbarium_search
    get('/')
    open_form('form[action*=search]') do |form|
      form.change('pattern', 'New York')
      form.select('type', :HERBARIA.l)
      form.submit('Search')
    end
    assert_template('herbarium/show_herbarium')
  end
  
  def test_multiple_herbarium_search
    get('/')
    open_form('form[action*=search]') do |form|
      form.change('pattern', 'Personal')
      form.select('type', :HERBARIA.l)
      form.submit('Search')
    end
    assert_template('herbarium/list_herbaria')
  end
  
  def test_specimen_search
    get('/')
    open_form('form[action*=search]') do |form|
      form.change('pattern', 'Coprinus comatus')
      form.select('type', :SPECIMENS.l)
      form.submit('Search')
    end
    assert_template('specimen/list_specimens')
  end
  
  def test_herbarium_change_code
    herbarium = herbaria(:nybg)
    new_code = 'NYBG'
    assert_not_equal(new_code, herbarium.code)
    curator = herbarium.curators[0]
    login(curator.login, 'testpassword', :true)
    get("herbarium/edit_herbarium/#{herbarium.id}")
    open_form do |form|
      form.assert_value('code', herbarium.code)
      form.change('code', new_code)
      form.submit(:edit_herbarium_save.t)
    end
    herbarium = Herbarium.find(herbarium.id)
    assert_equal(new_code, herbarium.code)
    assert_template('herbarium/show_herbarium')
  end
  
  def test_herbarium_create
    user = users(:mary)
    assert_equal([], user.curated_herbaria)
    login(user.login, 'testpassword', :true)
    get("herbarium/create_herbarium")
    open_form do |form|
      form.assert_value('herbarium_name', user.personal_herbarium_name)
      form.assert_value('code', '')
      form.assert_value('description', '')
      form.assert_value('email', user.email)
      form.assert_value('mailing_address', '')
      form.assert_value('place_name', '')
      form.submit(:create_herbarium_add.t)
    end
    user = User.find(user.id)
    assert_not_equal([], user.curated_herbaria)
    assert_template('herbarium/show_herbarium')
  end
end
