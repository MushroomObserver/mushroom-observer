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
end
