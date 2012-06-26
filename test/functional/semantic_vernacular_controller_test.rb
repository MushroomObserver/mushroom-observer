require File.expand_path(File.dirname(__FILE__) + '/../boot')

class SemanticVernacularControllerTest < FunctionalTestCase
  
  def test_index_vernaculars
    get_with_dump(:index_vernaculars)
    assert_response('index_vernaculars')
  end

  def test_index_species
  	get_with_dump(:index_species)
  	assert_response('index_species')
  end
end
