require File.dirname(__FILE__) + '/../test_helper'
require 'name_controller'

# Re-raise errors caught by the controller.
class NameController; def rescue_action(e) raise e end; end

class NameControllerTest < Test::Unit::TestCase
  fixtures :names
  fixtures :users
  fixtures :namings
  fixtures :observations
  fixtures :locations
  fixtures :synonyms
  fixtures :past_names
  fixtures :notifications
  fixtures :user_groups
  fixtures :user_groups_users

  def setup
    @controller = NameController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_name_index
    get_with_dump :name_index
    assert_response :success
    assert_template 'name_index'
  end

  def test_observation_index
    get_with_dump :observation_index
    assert_response :success
    assert_template 'name_index'
  end

  def test_authored_names
    get_with_dump :authored_names
    assert_response :success
    assert_template 'name_index'
  end

  def test_show_name
    get_with_dump :show_name, :id => 1
    assert_response :success
    assert_template 'show_name'
  end

  def test_show_past_name
    get_with_dump :show_past_name, :id => 1
    assert_response :success
    assert_template 'show_past_name'
  end

  def test_names_by_author
    get_with_dump :names_by_author, :id => 1
    assert_response :success
    assert_template 'name_index'
  end

  def test_names_by_editor
    get_with_dump :names_by_editor, :id => 1
    assert_response :success
    assert_template 'name_index'
  end

  def test_name_search
    @request.session[:pattern] = "56"
    get_with_dump :name_search
    assert_response :success
    assert_template 'name_index'
    assert_equal :name_index_matching.t(:pattern => '56'), @controller.instance_variable_get('@title')
    # There is no second page of these!
    # get_with_dump :name_search, { :page => 2 }
    # assert_response :success
    # assert_template 'name_index'
    # assert_equal "Names matching '56'", @controller.instance_variable_get('@title')
  end

  def test_edit_name
    name = @coprinus_comatus
    params = { "id" => name.id.to_s }
    requires_login(:edit_name, params)
    assert_form_action :action => 'edit_name'
  end

  def test_create_name
    requires_login(:create_name)
    assert_form_action :action => 'create_name'
  end

  def test_bulk_name_edit_list
    requires_login :bulk_name_edit
    assert_form_action :action => 'bulk_name_edit'
  end

  def test_change_synonyms
    name = @chlorophyllum_rachodes
    params = { :id => name.id }
    requires_login(:change_synonyms, params)
    assert_form_action :action => 'change_synonyms', :approved_synonyms => []
  end

  def test_deprecate_name
    name = @chlorophyllum_rachodes
    params = { :id => name.id }
    requires_login(:deprecate_name, params)
    assert_form_action :action => 'deprecate_name', :approved_name => ''
  end

  def test_approve_name
    name = @lactarius_alpigenes
    params = { :id => name.id }
    requires_login(:approve_name, params)
    assert_form_action :action => 'approve_name'
  end

  # ----------------------------
  #  Maps
  # ----------------------------

  # test_map - name with Observations that have Locations
  def test_map
    get_with_dump :map, :id => @agaricus_campestris.id
    assert_response :success
    assert_template 'map'
  end

  # test_map_no_loc - name with Observations that don't have Locations
  def test_map_no_loc
    get_with_dump :map, :id => @coprinus_comatus.id
    assert_response :success
    assert_template 'map'
  end

  # test_map_no_obs - name with no Observations
  def test_map_no_obs
    get_with_dump :map, :id => @conocybe_filaris.id
    assert_response :success
    assert_template 'map'
  end

  # ----------------------------
  #  Create name.
  # ----------------------------

  def empty_notes
    result = {}
    for f in Name.all_note_fields
      result[f] = ""
    end
    result
  end

  def test_create_name_post
    text_name = "Amanita velosa"
    author = "Lloyd"
    name = Name.find_by_text_name(text_name)
    assert_nil(name)
    params = {
      :name => {
        :text_name => text_name,
        :author => author,
        :rank => :Species,
        :citation => "__Mycol. Writ.__ 9(15). 1898."
      }
    }
    params[:name].merge!(empty_notes)

    post_requires_login(:create_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    # Amanita baccata is in there but not Amanita sp., so this creates two names.
    assert_equal(30, @rolf.reload.contribution)
    name = Name.find_by_text_name(text_name)
    assert(name)
    assert_equal(text_name, name.text_name)
    assert_equal(author, name.author)
    assert_equal(@rolf, name.user)
  end

  def test_create_name_existing
    name = @conocybe_filaris
    text_name = name.text_name
    count = Name.find(:all).length
    params = {
      :name => {
        :text_name => text_name,
        :author => "",
        :rank => :Species,
        :citation => ""
      }
    }
    params[:name].merge!(empty_notes)
    post_requires_login(:create_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_equal(10, @rolf.reload.contribution)
    name = Name.find_by_text_name(text_name)
    assert_equal(@conocybe_filaris, name)
    assert_equal(count, Name.find(:all).length)
  end

  def test_create_name_become_author
    text_name = "Macrocybe crassa"
    name = Name.find_by_text_name(text_name)
    assert_nil(name)
    params = {
      :name => {
        :text_name => text_name,
        :author => "",
        :rank => :Species,
        :citation => "",
        :gen_desc => "The Crass Macrocybe"
      }
    }
    params[:name] = empty_notes.merge(params[:name])
    post_requires_login(:create_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_equal(110, @rolf.reload.contribution)
    name = Name.find_by_text_name(text_name)
    assert(name)
    assert_equal(text_name, name.text_name)
    assert_equal(@rolf, name.user)
  end

  def test_create_name_bad_taxonomic_classification
    text_name = "Amanita pantherina"
    name = Name.find_by_text_name(text_name)
    assert_nil(name)
    params = {
      :name => {
        :text_name => text_name,
        :rank => :Species,
        :classification => "Clade: Basidiomycetes"
      }
    }
    params[:name] = empty_notes.merge(params[:name])

    post_requires_login(:create_name, params, false)
    
    # Should fail and no name should get created
    assert_nil(Name.find_by_text_name(text_name))
    assert_form_action(:action => 'create_name')
  end

  def test_create_name_alt_rank
    text_name = "Amanita pantherina"
    name = Name.find_by_text_name(text_name)
    assert_nil(name)
    params = {
      :name => {
        :text_name => text_name,
        :rank => :Species,
        :classification => "Division: Basidiomycetes"
      }
    }
    params[:name] = empty_notes.merge(params[:name])
    
    post_requires_login(:create_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    name = Name.find_by_text_name(text_name)
    assert(name)
    assert_equal('Phylum: _Basidiomycetes_', name.classification)
  end

  # ----------------------------
  #  Edit name.
  # ----------------------------

  def test_edit_name_post
    name = @conocybe_filaris
    assert(name.text_name == "Conocybe filaris")
    assert(name.author.nil?)
    past_names = name.versions.size
    assert(0 == name.version)
    params = {
      :id => name.id,
      :name => {
        :text_name => name.text_name,
        :author => "(Fr.) Kühner",
        :rank => :Species,
        :citation => "__Le Genera Galera__, 139. 1935."
      }
    }
    params[:name].merge!(empty_notes)
    post_requires_login(:edit_name, params, false)
    # Must be creating Conocybe sp, too.
    assert_equal(30, @rolf.reload.contribution)
    name.reload
    assert_equal("(Fr.) Kühner", name.author)
    assert_equal("**__Conocybe filaris__** (Fr.) Kühner", name.display_name)
    assert_equal("**__Conocybe filaris__** (Fr.) Kühner", name.observation_name)
    assert_equal("Conocybe filaris (Fr.) Kühner", name.search_name)
    assert_equal("__Le Genera Galera__, 139. 1935.", name.citation)
    assert_equal(@rolf, name.user)
  end

  # Test to see if add a new general description sets the description author list
  # to the current user.
  def test_edit_name_add_gen_desc
    name = @conocybe_filaris
    assert_equal([], name.authors)
    assert_nil(name.gen_desc)
    past_names = name.versions.size
    assert(0 == name.version)
    old_contrib = name.user.contribution
    params = {
      :id => name.id,
      :name => {
        :text_name => name.text_name,
        :author => "(Fr.) Kühner",
        :rank => :Species,
        :citation => "__Le Genera Galera__, 139. 1935.",
        :gen_desc => "A general description"
      }
    }
    params[:name] = empty_notes.merge(params[:name])
    post_requires_login(:edit_name, params, false)
    name.reload
    assert_equal(100 + 10 + old_contrib, name.user.reload.contribution)
    assert(name.gen_desc)
    assert_equal(name.authors, [name.user])
  end

  # Test name changes in various ways.
  def test_edit_name_deprecated
    name = @lactarius_alpigenes
    assert(name.deprecated)
    params = {
      :id => name.id,
      :name => {
        :text_name => name.text_name,
        :author => "",
        :rank => :Species,
        :citation => ""
      }
    }
    params[:name].merge!(empty_notes)
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    # (creates Lactarius since it's not in the fixtures, AND it changes L. alpigenes)
    assert_equal(30, @rolf.reload.contribution)
    name = Name.find(name.id)
    assert(name.deprecated)
  end

  def test_edit_name_different_user
    name = @macrolepiota_rhacodes
    name_owner = name.user
    user = "rolf"
    assert(user != name_owner.login) # Make sure it's not owned by the default user
    params = {
      :id => name.id,
      :name => {
        :text_name => name.text_name,
        :author => name.author,
        :rank => :Species,
        :citation => name.citation
      }
    }
    params[:name].merge!(name.all_notes)
    post_requires_login(:edit_name, params, false, user)
    assert_redirected_to(:controller => "name", :action => "show_name")
    # Hmmm, this isn't catching the fact that rolf shouldn't be allowed to change the name,
    # instead it seems to be doing nothing sinply because he's not actually changing anything!
    assert_equal(10, @rolf.reload.contribution)
    name = Name.find(name.id)
    assert(name_owner == name.user)
  end

  # If non-reviewer makes significant change, should reset status.
  def test_edit_name_cause_review_status_reset
    name = @peltigera
    params = {
      :id => name.id,
      :name => {
        :text_name => name.text_name,
        :author => name.author,
        :rank => :Genus,
        :citation => name.citation,
        :license_id => name.license_id
      }
    }
    params[:name].merge!(name.all_notes)

    # Non-reviewer making no change.
    @request.session[:user_id] = @mary.id
    post(:edit_name, params)
    assert_equal(:vetted, @peltigera.reload.review_status)

    # Non-reviewer making change.
    params[:name][:citation] = "Blah blah blah."
    @request.session[:user_id] = @mary.id
    post(:edit_name, params)
    assert_equal(:unreviewed, @peltigera.reload.review_status)

    # Set it back to vetted, and have reviewer make a change.
    @peltigera.update_review_status(:vetted, @rolf)
    params[:name][:citation] = "Whatever."
    @request.session[:user_id] = @rolf.id
    post(:edit_name, params)
    assert_equal(:vetted, @peltigera.reload.review_status)
  end

  def test_edit_name_simple_merge
    misspelt_name = @agaricus_campestrus
    correct_name = @agaricus_campestris
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.versions.size
    assert(0 == correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs_id = misspelt_name.namings[0].observation.id
    assert_equal(2, correct_name.namings.size)
    correct_obs_id = correct_name.namings[0].observation.id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => @agaricus_campestris.text_name,
        :author => "",
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.versions.size)

    assert_equal(3, correct_name.namings.size)
    misspelt_obs = Observation.find(misspelt_obs_id)
    assert_equal(@agaricus_campestris, misspelt_obs.name)
    correct_obs = Observation.find(correct_obs_id)
    assert_equal(@agaricus_campestris, correct_obs.name)
  end

  def test_edit_name_author_merge
    misspelt_name = @amanita_baccata_borealis
    correct_name = @amanita_baccata_arora
    assert_not_equal(misspelt_name, correct_name)
    assert_equal(misspelt_name.text_name, correct_name.text_name)
    correct_author = correct_name.author
    assert_not_equal(misspelt_name.author, correct_author)
    past_names = correct_name.versions.size
    assert_equal(0, correct_name.version)
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => misspelt_name.text_name,
        :author => correct_name.author,
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert_equal(correct_author, correct_name.author)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.versions.size)
  end

  # Test that merged names end up as not deprecated if the
  # correct name is not deprecated.
  def test_edit_name_deprecated_merge
    misspelt_name = @lactarius_alpigenes
    assert(misspelt_name.deprecated)
    correct_name = @lactarius_alpinus
    assert(!correct_name.deprecated)
    assert_not_equal(misspelt_name, correct_name)
    assert_not_equal(misspelt_name.text_name, correct_name.text_name)
    correct_author = correct_name.author
    assert_not_equal(misspelt_name.author, correct_author)
    past_names = correct_name.versions.size
    assert_equal(0, correct_name.version)
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_name.text_name,
        :author => correct_name.author,
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert(!correct_name.deprecated)
    assert_equal(correct_author, correct_name.author)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.versions.size)
  end

  # Test that merged names end up as not deprecated even if the
  # correct name is deprecated but the misspelt name is not deprecated
  def test_edit_name_deprecated2_merge
    misspelt_name = @lactarius_alpinus
    assert(!misspelt_name.deprecated)
    correct_name = @lactarius_alpigenes
    assert(correct_name.deprecated)
    assert_not_equal(misspelt_name, correct_name)
    assert_not_equal(misspelt_name.text_name, correct_name.text_name)
    correct_author = correct_name.author
    correct_text_name = correct_name.text_name
    assert_not_equal(misspelt_name.author, correct_author)
    past_names = correct_name.versions.size
    assert(0 == correct_name.version)
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_name.text_name,
        :author => correct_name.author,
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      correct_name = Name.find(correct_name.id)
    end
    misspelt_name = Name.find(misspelt_name.id)
    assert(misspelt_name)
    assert(!misspelt_name.deprecated)
    assert_equal(correct_author, misspelt_name.author)
    assert_equal(correct_text_name, misspelt_name.text_name)
    assert(1 == misspelt_name.version)
    assert(past_names+1 == misspelt_name.versions.size)
  end

  # Test merge two names where the matching_name has notes.
  def test_edit_name_merge_matching_notes
    target_name = @russula_brevipes_no_author
    matching_name = @russula_brevipes_author_notes
    assert_not_equal(target_name, matching_name)
    assert_equal(target_name.text_name, matching_name.text_name)
    assert_nil(target_name.author)
    assert_nil(target_name.notes)
    assert_not_nil(matching_name.author)
    notes = matching_name.notes
    assert_not_nil(matching_name.notes)

    params = {
      :id => target_name.id,
      :name => {
        :text_name => target_name.text_name,
        :citation => "",
        :author => target_name.author,
        :rank => target_name.rank
      }
    }
    params[:name].merge!(empty_notes)
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    merged_name = Name.find(matching_name.id)
    assert(merged_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(target_name.id)
    end
    assert_equal(notes, merged_name.notes)
  end

  # Test merge two names that both start with notes, but the notes are cleared in the input.
  def test_edit_name_merge_both_notes
    target_name = @russula_cremoricolor_no_author_notes
    matching_name = @russula_cremoricolor_author_notes
    assert_not_equal(target_name, matching_name)
    assert_equal(target_name.text_name, matching_name.text_name)
    assert_nil(target_name.author)
    target_notes = target_name.notes
    assert_not_nil(target_notes)
    assert_not_nil(matching_name.author)
    matching_notes = matching_name.notes
    assert_not_nil(matching_notes)
    assert_not_equal(target_notes, matching_notes)

    params = {
      :id => target_name.id,
      :name => {
        :text_name => target_name.text_name,
        :citation => "",
        :author => target_name.author,
        :rank => target_name.rank
      }
    }
    params[:name].merge!(empty_notes) # Explicitly clear the notes
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    merged_name = Name.find(matching_name.id)
    assert(merged_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(target_name.id)
    end
    assert_equal(matching_notes, merged_name.notes)
  end

  def test_edit_name_misspelt_unmergeable
    misspelt_name = @agaricus_campestras
    correct_name = @agaricus_campestris
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.versions.size
    assert(0 == correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs_id = misspelt_name.namings[0].observation.id
    assert_equal(2, correct_name.namings.size)
    correct_obs_id = correct_name.namings[0].observation.id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => "",
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    # Because misspelt name is unmergable it gets reused and
    # corrected rather than the correct name
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(correct_name.id)
    end
    correct_name = Name.find(misspelt_name.id)
    assert(correct_name)
    assert(1 == correct_name.version)
    assert(past_names+1 == correct_name.versions.size)

    assert_equal(3, correct_name.namings.size)
    misspelt_obs = Observation.find(misspelt_obs_id)
    assert_equal(@agaricus_campestras, misspelt_obs.name)
    correct_obs = Observation.find(correct_obs_id)
    assert_equal(@agaricus_campestras, correct_obs.name)
  end

  def test_edit_name_correct_unmergeable
    misspelt_name = @agaricus_campestrus
    correct_name = @agaricus_campestras
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    correct_notes = correct_name.notes
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.versions.size
    assert_equal(0, correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs_id = misspelt_name.namings[0].observation.id
    assert_equal(1, correct_name.namings.size)
    correct_obs_id = correct_name.namings[0].observation.id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => "",
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert_equal(correct_notes, correct_name.notes)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.versions.size)

    assert_equal(2, correct_name.namings.size)
    misspelt_obs = Observation.find(misspelt_obs_id)
    assert_equal(@agaricus_campestras, misspelt_obs.name)
    correct_obs = Observation.find(correct_obs_id)
    assert_equal(@agaricus_campestras, correct_obs.name)
  end

  def test_edit_name_neither_mergeable
    misspelt_name = @agaricus_campestros
    correct_name = @agaricus_campestras
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.versions.size
    assert(0 == correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs_id = misspelt_name.namings[0].observation.id
    assert_equal(1, correct_name.namings.size)
    correct_obs_id = correct_name.namings[0].observation.id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => misspelt_name.author,
        :rank => misspelt_name.rank
      }
    }
    all_notes = empty_notes
    all_notes[:notes] = misspelt_name.notes
    params[:name].merge!(all_notes)

    post_requires_login(:edit_name, params, false)
    assert_response :success
    assert_template 'edit_name'
    misspelt_name = Name.find(misspelt_name.id)
    assert(misspelt_name)
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert(0 == correct_name.version)
    assert(past_names == correct_name.versions.size)
    assert_equal(1, correct_name.namings.size)
    assert_equal(1, misspelt_name.namings.size)
    assert_not_equal(correct_name.namings[0], misspelt_name.namings[0])
  end

  def test_edit_name_correct_unmergable_with_notes # Should 'fail'
    misspelt_name = @russula_brevipes_no_author # Shouldn't have notes
    correct_name = @russula_brevipes_author_notes # Should have notes
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    assert_not_equal(misspelt_name, correct_name)
    assert_nil(misspelt_name.notes)
    assert(correct_name.notes)

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => misspelt_name.author,
        :rank => misspelt_name.rank
      }
    }
    all_notes = empty_notes
    all_notes[:notes] = "Some new notes"
    params[:name].merge!(all_notes)

    post_requires_login(:edit_name, params, false)
    assert_response :success
    assert_template 'edit_name'
    misspelt_name = Name.find(misspelt_name.id)
    assert(misspelt_name)
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
  end

  def test_edit_name_page_version_merge
    page_name = @coprinellus_micaceus
    other_name = @coprinellus_micaceus_no_author
    assert(page_name.version > other_name.version)
    assert_not_equal(page_name, other_name)
    assert_equal(page_name.text_name, other_name.text_name)
    correct_author = page_name.author
    assert_not_equal(other_name.author, correct_author)
    past_names = page_name.versions.size
    params = {
      :id => page_name.id,
      :name => {
        :text_name => page_name.text_name,
        :author => '',
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)

    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      destroyed_name = Name.find(other_name.id)
    end
    merge_name = Name.find(page_name.id)
    assert(merge_name)
    assert_equal(correct_author, merge_name.author)
    assert_equal(past_names, merge_name.version)
  end

  def test_edit_name_other_version_merge
    page_name = @coprinellus_micaceus_no_author
    other_name = @coprinellus_micaceus
    assert(page_name.version < other_name.version)
    assert_not_equal(page_name, other_name)
    assert_equal(page_name.text_name, other_name.text_name)
    correct_author = other_name.author
    assert_not_equal(page_name.author, correct_author)
    past_names = other_name.versions.size
    params = {
      :id => page_name.id,
      :name => {
        :text_name => page_name.text_name,
        :author => '',
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)

    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      destroyed_name = Name.find(page_name.id)
    end
    merge_name = Name.find(other_name.id)
    assert(merge_name)
    assert_equal(correct_author, merge_name.author)
    assert_equal(past_names, merge_name.version)
  end

  def test_edit_name_add_author
    name = @strobilurus_diminutivus_no_author
    old_text_name = name.text_name
    new_author = 'Desjardin'
    assert(name.namings.length > 0)
    params = {
      :id => name.id,
      :name => {
        :author => new_author,
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)

    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    # It seems to be creating Strobilurus sp. as well?
    assert_equal(30, @rolf.reload.contribution)
    name = Name.find(name.id)
    assert_equal(new_author, name.author)
    assert_equal(old_text_name, name.text_name)
  end

  # Test merge of name with notes with name without notes
  def test_edit_name_notes
    target_name = @russula_brevipes_no_author
    matching_name = @russula_brevipes_author_notes
    assert_not_equal(target_name, matching_name)
    assert_equal(target_name.text_name, matching_name.text_name)
    assert_nil(target_name.author)
    assert_nil(target_name.notes)
    assert_not_nil(matching_name.author)
    notes = matching_name.notes
    assert_not_nil(matching_name.notes)

    params = {
      :id => target_name.id,
      :name => {
        :text_name => target_name.text_name,
        :citation => "",
        :author => target_name.author,
        :rank => target_name.rank
      }
    }
    params[:name].merge!(empty_notes)

    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    # (creates Russula since not in fixtures, changes R. brevipes, deletes some name, but leaves past_name)
    assert_equal(30, @rolf.reload.contribution)
    merged_name = Name.find(matching_name.id)
    assert(merged_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(target_name.id)
    end
    assert_equal(notes, merged_name.notes)
  end

  # ----------------------------
  #  Bulk names.
  # ----------------------------

  def test_update_bulk_names_nn_synonym
    new_name_str = "Amanita fergusonii"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    new_synonym_str = "Amanita lanei"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_synonym_str]))
    params = {
      :list => { :members => "#{new_name_str} = #{new_synonym_str}"},
    }
    post_requires_login(:bulk_name_edit, params, false)
    assert_response :success
    assert_template 'bulk_name_edit'
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_synonym_str]))
    assert_equal(10, @rolf.reload.contribution)
  end

  def test_update_bulk_names_approved_nn_synonym
    new_name_str = "Amanita fergusonii"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    new_synonym_str = "Amanita lanei"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_synonym_str]))
    params = {
      :list => { :members => "#{new_name_str} = #{new_synonym_str}"},
      :approved_names => [new_name_str, new_synonym_str]
    }
    post_requires_login(:bulk_name_edit, params, false)
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    new_name = Name.find(:first, :conditions => ["text_name = ?", new_name_str])
    assert(new_name)
    assert_equal(new_name_str, new_name.text_name)
    assert_equal("**__#{new_name_str}__**", new_name.display_name)
    assert(!new_name.deprecated)
    assert_equal(:Species, new_name.rank)
    synonym_name = Name.find(:first, :conditions => ["text_name = ?", new_synonym_str])
    assert(synonym_name)
    assert_equal(new_synonym_str, synonym_name.text_name)
    assert_equal("__#{new_synonym_str}__", synonym_name.display_name)
    assert(synonym_name.deprecated)
    assert_equal(:Species, synonym_name.rank)
    assert_not_nil(new_name.synonym)
    assert_equal(new_name.synonym, synonym_name.synonym)
  end

  def test_update_bulk_names_ee_synonym
    approved_name = @chlorophyllum_rachodes
    synonym_name = @macrolepiota_rachodes
    assert_not_equal(approved_name.synonym, synonym_name.synonym)
    assert(!synonym_name.deprecated)
    params = {
      :list => { :members => "#{approved_name.search_name} = #{synonym_name.search_name}"},
    }
    post_requires_login(:bulk_name_edit, params, false)
    # print "\n#{flash[:notice]}\n"
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    approved_name = Name.find(approved_name.id)
    assert(!approved_name.deprecated)
    synonym_name = Name.find(synonym_name.id)
    assert(synonym_name.deprecated)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
  end

  def test_update_bulk_names_eee_synonym
    approved_name = @lepiota_rachodes
    synonym_name = @lepiota_rhacodes
    assert_nil(approved_name.synonym)
    assert_nil(synonym_name.synonym)
    assert(!synonym_name.deprecated)
    synonym_name2 = @chlorophyllum_rachodes
    assert_not_nil(synonym_name2.synonym)
    assert(!synonym_name2.deprecated)
    params = {
      :list => { :members => ("#{approved_name.search_name} = #{synonym_name.search_name}\r\n" +
                              "#{approved_name.search_name} = #{synonym_name2.search_name}")},
    }
    post_requires_login(:bulk_name_edit, params, false)
    # print "\n#{flash[:notice]}\n"
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    approved_name = Name.find(approved_name.id)
    assert(!approved_name.deprecated)
    synonym_name = Name.find(synonym_name.id)
    assert(synonym_name.deprecated)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
    synonym_name2 = Name.find(synonym_name2.id)
    assert(synonym_name.deprecated)
    assert_equal(approved_name.synonym, synonym_name2.synonym)
  end

  def test_update_bulk_names_en_synonym
    approved_name = @chlorophyllum_rachodes
    target_synonym = approved_name.synonym
    assert(target_synonym)
    new_synonym_str = "New name Wilson"
    assert_nil(Name.find(:first, :conditions => ["search_name = ?", new_synonym_str]))
    params = {
      :list => { :members => "#{approved_name.search_name} = #{new_synonym_str}"},
      :approved_names => [approved_name.search_name, new_synonym_str]
    }
    post_requires_login(:bulk_name_edit, params, false)
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    approved_name = Name.find(approved_name.id)
    assert(!approved_name.deprecated)
    synonym_name = Name.find(:first, :conditions => ["search_name = ?", new_synonym_str])
    assert(synonym_name)
    assert(synonym_name.deprecated)
    assert_equal(:Species, synonym_name.rank)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
    assert_equal(target_synonym, approved_name.synonym)
  end

  def test_update_bulk_names_ne_synonym
    new_name_str = "New name Wilson"
    assert_nil(Name.find(:first, :conditions => ["search_name = ?", new_name_str]))
    synonym_name = @macrolepiota_rachodes
    assert(!synonym_name.deprecated)
    target_synonym = synonym_name.synonym
    assert(target_synonym)
    params = {
      :list => { :members => "#{new_name_str} = #{synonym_name.search_name}"},
      :approved_names => [new_name_str, synonym_name.search_name]
    }
    post_requires_login(:bulk_name_edit, params, false)
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    approved_name = Name.find(:first, :conditions => ["search_name = ?", new_name_str])
    assert(approved_name)
    assert(!approved_name.deprecated)
    assert_equal(:Species, approved_name.rank)
    synonym_name = Name.find(synonym_name.id)
    assert(synonym_name.deprecated)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
    assert_equal(target_synonym, approved_name.synonym)
  end

  # Test a bug fix for the case of adding a subtaxon when the parent taxon is duplicated due to
  # different authors.
  def test_update_bulk_names_approved_for_dup_parents
    parent1 = @lentinellus_ursinus_author1
    parent2 = @lentinellus_ursinus_author2
    assert_not_equal(parent1, parent2)
    assert_equal(parent1.text_name, parent2.text_name)
    assert_not_equal(parent1.author, parent2.author)
    new_name_str = "#{parent1.text_name} f. robustus"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    params = {
      :list => { :members => "#{new_name_str}"},
      :approved_names => [new_name_str]
    }
    post_requires_login(:bulk_name_edit, params, false)
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    new_name = Name.find(:first, :conditions => ["text_name = ?", new_name_str])
    assert(new_name)
  end

  # ----------------------------
  #  Synonyms.
  # ----------------------------

  # combine two Names that have no Synonym
  def test_transfer_synonyms_1_1
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    selected_past_name_count = selected_name.versions.length
    selected_version = selected_name.version

    add_name = @lepiota_rhacodes
    assert(!add_name.deprecated)
    assert_equal("**__Lepiota rhacodes__** Vittad.", add_name.display_name)
    assert_nil(add_name.synonym)
    add_past_name_count = add_name.versions.length
    add_name_version = add_name.version

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.text_name },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal("__Lepiota rhacodes__ Vittad.", add_name.display_name)
    assert_equal(add_past_name_count+1, add_name.versions.length) # past name should have been created
    assert(add_name.versions.latest.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_name_version+1, add_name.version)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_past_name_count, selected_name.versions.length)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)

    assert(!Name.find(@lepiota.id).deprecated)
  end

  # combine two Names that have no Synonym and no deprecation
  def test_transfer_synonyms_1_1_nd
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    selected_version = selected_name.version

    add_name = @lepiota_rhacodes
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)
    add_version = add_name.version

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.text_name },
      :deprecate => { :all => "0" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_version, add_name.version)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)
  end

  # add new name string to Name with no Synonym but not approved
  def test_transfer_synonyms_1_0_na
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    params = {
      :id => selected_name.id,
      :synonym => { :members => "Lepiota rachodes var. rachodes" },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_response :success
    assert_template 'change_synonyms'

    selected_name = Name.find(selected_name.id)
    assert_nil(selected_name.synonym)
    assert(!selected_name.deprecated)
  end

  # add new name string to Name with no Synonym but approved
  def test_transfer_synonyms_1_0_a
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => "Lepiota rachodes var. rachodes" },
      :approved_names => ["Lepiota rachodes var. rachodes"],
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    assert_equal(selected_version, selected_name.version)
    synonym = selected_name.synonym
    assert_not_nil(synonym)
    assert_equal(2, synonym.names.length)
    for n in synonym.names
      if n == selected_name
        assert(!n.deprecated)
      else
        assert(n.deprecated)
      end
    end
    assert(!Name.find(@lepiota.id).deprecated)
  end

  # add new name string to Name with no Synonym but approved
  def test_transfer_synonyms_1_00_a
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => "Lepiota rachodes var. rachodes\r\nLepiota rhacodes var. rhacodes" },
      :approved_names => ["Lepiota rachodes var. rachodes", "Lepiota rhacodes var. rhacodes"],
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    synonym = selected_name.synonym
    assert_not_nil(synonym)
    assert_equal(3, synonym.names.length)
    for n in synonym.names
      if n == selected_name
        assert(!n.deprecated)
      else
        assert(n.deprecated)
      end
    end
    assert(!Name.find(@lepiota.id).deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym
  def test_transfer_synonyms_n_1
    add_name = @lepiota_rachodes
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)
    add_version = add_name.version

    selected_name = @chlorophyllum_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_version+1, add_name.version)
    assert(!Name.find(@lepiota.id).deprecated)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(start_size + 1, add_synonym.names.size)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym wih the alternates checked
  def test_transfer_synonyms_n_1_c
    add_name = @lepiota_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    assert_nil(add_name.synonym)

    selected_name = @chlorophyllum_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n != selected_name # Check all names not matching the selected one
        assert(!n.deprecated)
        split_name = n
        existing_synonyms[n.id.to_s] = "checked"
      end
    end
    assert_not_nil(split_name)
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(start_size + 1, add_synonym.names.size)

    split_name = Name.find(split_name.id)
    assert(!split_name.deprecated)
    split_synonym = split_name.synonym
    assert_equal(add_synonym, split_synonym)
    assert(!Name.find(@lepiota.id).deprecated)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym wih the alternates not checked
  def test_transfer_synonyms_n_1_nc
    add_name = @lepiota_rachodes
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)
    add_version = add_name.version

    selected_name = @chlorophyllum_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n != selected_name # Uncheck all names not matching the selected one
        assert(!n.deprecated)
        split_name = n
        existing_synonyms[n.id.to_s] = "0"
      end
    end
    assert_not_nil(split_name)
    assert(!split_name.deprecated)
    split_version = split_name.version
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)

    split_name = Name.find(split_name.id)
    assert(!split_name.deprecated)
    assert_equal(split_version, split_name.version)
    assert_nil(split_name.synonym)
    assert(!Name.find(@lepiota.id).deprecated)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym with no approved synonyms
  def test_transfer_synonyms_1_n_ns
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_response :success
    assert_template 'change_synonyms'

    add_name = Name.find(add_name.id)
    assert(!add_name.deprecated)
    assert_equal(add_version, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_nil(selected_synonym)

    assert_equal(start_size, add_synonym.names.size)
    assert(!Name.find(@lepiota.id).deprecated)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym with all approved synonyms
  def test_transfer_synonyms_1_n_s
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    synonym_ids = (add_synonym.names.map {|n| n.id}).join('/')
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :approved_synonyms => synonym_ids,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)

    assert_equal(start_size+1, add_synonym.names.size)
    assert(!Name.find(@lepiota.id).deprecated)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym with all approved synonyms
  def test_transfer_synonyms_1_n_l
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    synonym_names = (add_synonym.names.map {|n| n.search_name}).join("\r\n")
    params = {
      :id => selected_name.id,
      :synonym => { :members => synonym_names },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)

    assert_equal(start_size+1, add_synonym.names.size)
    assert(!Name.find(@lepiota.id).deprecated)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # combine two Names that each have Synonyms with no chosen names
  def test_transfer_synonyms_n_n_ns
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = @macrolepiota_rachodes
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_response :success
    assert_template 'change_synonyms'

    add_name = Name.find(add_name.id)
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_start_size, add_synonym.names.size)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_not_equal(add_synonym, selected_synonym)
    assert_equal(selected_start_size, selected_synonym.names.size)
  end

  # combine two Names that each have Synonyms with all chosen names
  def test_transfer_synonyms_n_n_s
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = @macrolepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)

    synonym_ids = (add_synonym.names.map {|n| n.id}).join('/')
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :approved_synonyms => synonym_ids,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_start_size + selected_start_size, add_synonym.names.size)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
  end

  # combine two Names that each have Synonyms with all names listed
  def test_transfer_synonyms_n_n_l
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = @macrolepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)

    synonym_names = (add_synonym.names.map {|n| n.search_name}).join("\r\n")
    params = {
      :id => selected_name.id,
      :synonym => { :members => synonym_names },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_start_size + selected_start_size, add_synonym.names.size)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
  end

  # split off a single name from a name with multiple synonyms
  def test_transfer_synonyms_split_3_1
    selected_name = @lactarius_alpinus
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_id = selected_name.id
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n.id != selected_id
        assert(n.deprecated)
        if split_name.nil? # Find the first different name and uncheck it
          split_name = n
          existing_synonyms[n.id.to_s] = "0"
        else
          kept_name = n
          existing_synonyms[n.id.to_s] = "checked" # Check the rest
        end
      end
    end
    split_version = split_name.version
    kept_version = kept_name.version
    params = {
      :id => selected_name.id,
      :synonym => { :members => "" },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    assert_equal(selected_version, selected_name.version)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(selected_start_size - 1, selected_synonym.names.size)

    split_name = Name.find(split_name.id)
    assert(split_name.deprecated)
    assert_equal(split_version, split_name.version)
    assert_nil(split_name.synonym)

    assert(kept_name.deprecated)
    assert_equal(kept_version, kept_name.version)
  end

  # split 4 synonymized names into two sets of synonyms with two members each
  def test_transfer_synonyms_split_2_2
    selected_name = @lactarius_alpinus
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_id = selected_name.id
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_names = []
    count = 0
    for n in selected_synonym.names
      if n != selected_name
        assert(n.deprecated)
        if count < 2 # Uncheck two names
          split_names.push(n)
          existing_synonyms[n.id.to_s] = "0"
        else
          existing_synonyms[n.id.to_s] = "checked"
        end
        count += 1
      end
    end
    assert_equal(2, split_names.length)
    assert_not_equal(split_names[0], split_names[1])
    params = {
      :id => selected_name.id,
      :synonym => { :members => "" },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(selected_start_size - 2, selected_synonym.names.size)

    split_names[0] = Name.find(split_names[0].id)
    assert(split_names[0].deprecated)
    split_synonym = split_names[0].synonym
    assert_not_nil(split_synonym)
    split_names[1] = Name.find(split_names[1].id)
    assert(split_names[1].deprecated)
    assert_not_equal(split_names[0], split_names[1])
    assert_equal(split_synonym, split_names[1].synonym)
    assert_equal(2, split_synonym.names.size)
  end

  # take four synonymized names and separate off one
  def test_transfer_synonyms_split_1_3
    selected_name = @lactarius_alpinus
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_id = selected_name.id
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n != selected_name # Uncheck all names not matching the selected one
        assert(n.deprecated)
        split_name = n
        existing_synonyms[n.id.to_s] = "0"
      end
    end
    assert_not_nil(split_name)
    split_version = split_name.version
    params = {
      :id => selected_name.id,
      :synonym => { :members => "" },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    assert_equal(selected_version, selected_name.version)
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)

    split_name = Name.find(split_name.id)
    assert(split_name.deprecated)
    assert_equal(split_version, split_name.version)
    split_synonym = split_name.synonym
    assert_not_nil(split_synonym)
    assert_equal(selected_start_size - 1, split_synonym.names.size)
  end

  # ----------------------------
  #  Deprecation.
  # ----------------------------

  # deprecate an existing unique name with another existing name
  def test_do_deprecation
    current_name = @lepiota_rachodes
    assert(!current_name.deprecated)
    assert_nil(current_name.synonym)
    current_past_name_count = current_name.versions.length
    current_version = current_name.version
    current_notes = current_name.notes

    proposed_name = @chlorophyllum_rachodes
    assert(!proposed_name.deprecated)
    assert_not_nil(proposed_name.synonym)
    proposed_synonym_length = proposed_name.synonym.names.size
    proposed_past_name_count = proposed_name.versions.length
    proposed_version = proposed_name.version
    proposed_notes = proposed_name.notes

    params = {
      :id => current_name.id,
      :proposed => { :name => proposed_name.text_name },
      :comment => { :comment => "Don't like this name" }
    }
    post_requires_login(:deprecate_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name") # Success

    old_name = Name.find(current_name.id)
    assert(old_name.deprecated)
    assert_equal(current_past_name_count+1, old_name.versions.length) # past name should have been created
    assert(old_name.versions.latest.deprecated)
    old_synonym = old_name.synonym
    assert_not_nil(old_synonym)
    assert_equal(current_version+1, old_name.version)
    assert_not_equal(current_notes, old_name.notes)

    new_name = Name.find(proposed_name.id)
    assert(!new_name.deprecated)
    assert_equal(proposed_past_name_count, new_name.versions.length)
    new_synonym = new_name.synonym
    assert_not_nil(new_synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(proposed_synonym_length+1, new_synonym.names.size)
    assert_equal(proposed_version, new_name.version)
    assert_equal(proposed_notes, new_name.notes)
  end

  # deprecate an existing unique name with an ambiguous name
  def test_do_deprecation_ambiguous
    current_name = @lepiota_rachodes
    assert(!current_name.deprecated)
    assert_nil(current_name.synonym)
    current_past_name_count = current_name.versions.length

    proposed_name = @amanita_baccata_arora # Ambiguous text name
    assert(!proposed_name.deprecated)
    assert_nil(proposed_name.synonym)
    proposed_past_name_count = proposed_name.versions.length

    params = {
      :id => current_name.id,
      :proposed => { :name => proposed_name.text_name },
      :comment => { :comment => ""}
    }
    post_requires_login(:deprecate_name, params, false)
    assert_response :success # Fail since name can't be disambiguated
    assert_template 'deprecate_name'

    old_name = Name.find(current_name.id)
    assert(!old_name.deprecated)
    assert_equal(current_past_name_count, old_name.versions.length)
    assert_nil(old_name.synonym)

    new_name = Name.find(proposed_name.id)
    assert(!new_name.deprecated)
    assert_equal(proposed_past_name_count, new_name.versions.length)
    assert_nil(new_name.synonym)
  end

  # deprecate an existing unique name with an ambiguous name, but using :chosen_name to disambiguate
  def test_do_deprecation_chosen
    current_name = @lepiota_rachodes
    assert(!current_name.deprecated)
    assert_nil(current_name.synonym)
    current_past_name_count = current_name.versions.length

    proposed_name = @amanita_baccata_arora # Ambiguous text name
    assert(!proposed_name.deprecated)
    assert_nil(proposed_name.synonym)
    proposed_synonym_length = 0
    proposed_past_name_count = proposed_name.versions.length

    params = {
      :id => current_name.id,
      :proposed => { :name => proposed_name.text_name },
      :chosen_name => { :name_id => proposed_name.id },
      :comment => { :comment => "Don't like this name"}
    }
    post_requires_login(:deprecate_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name") # Success

    old_name = Name.find(current_name.id)
    assert(old_name.deprecated)
    assert_equal(current_past_name_count+1, old_name.versions.length) # past name should have been created
    assert(old_name.versions.latest.deprecated)
    old_synonym = old_name.synonym
    assert_not_nil(old_synonym)

    new_name = Name.find(proposed_name.id)
    assert(!new_name.deprecated)
    assert_equal(proposed_past_name_count, new_name.versions.length)
    new_synonym = new_name.synonym
    assert_not_nil(new_synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(2, new_synonym.names.size)
  end

  # deprecate an existing unique name with an ambiguous name
  def test_do_deprecation_new_name
    current_name = @lepiota_rachodes
    assert(!current_name.deprecated)
    assert_nil(current_name.synonym)
    current_past_name_count = current_name.versions.length

    proposed_name_str = "New name"

    params = {
      :id => current_name.id,
      :proposed => { :name => proposed_name_str },
      :comment => { :comment => "Don't like this name"}
    }
    post_requires_login(:deprecate_name, params, false)
    assert_response :success # Fail since new name is not approved
    assert_template 'deprecate_name'

    old_name = Name.find(current_name.id)
    assert(!old_name.deprecated)
    assert_equal(current_past_name_count, old_name.versions.length)
    assert_nil(old_name.synonym)
  end

  # deprecate an existing unique name with an ambiguous name, but using :chosen_name to disambiguate
  def test_do_deprecation_approved_new_name
    current_name = @lepiota_rachodes
    assert(!current_name.deprecated)
    assert_nil(current_name.synonym)
    current_past_name_count = current_name.versions.length

    proposed_name_str = "New name"

    params = {
      :id => current_name.id,
      :proposed => { :name => proposed_name_str },
      :approved_name => proposed_name_str,
      :comment => { :comment => "Don't like this name" }
    }
    post_requires_login(:deprecate_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name") # Success

    old_name = Name.find(current_name.id)
    assert(old_name.deprecated)
    assert_equal(current_past_name_count+1, old_name.versions.length) # past name should have been created
    assert(old_name.versions.latest.deprecated)
    old_synonym = old_name.synonym
    assert_not_nil(old_synonym)

    new_name = Name.find(:first, :conditions => ["text_name = ?", proposed_name_str])
    assert(!new_name.deprecated)
    new_synonym = new_name.synonym
    assert_not_nil(new_synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(2, new_synonym.names.size)
  end

  # ----------------------------
  #  Approval.
  # ----------------------------

  # approve a deprecated name
  def test_do_approval_default
    current_name = @lactarius_alpigenes
    assert(current_name.deprecated)
    assert(current_name.synonym)
    current_past_name_count = current_name.versions.length
    current_version = current_name.version
    approved_synonyms = current_name.approved_synonyms
    current_notes = current_name.notes

    params = {
      :id => current_name.id,
      :deprecate => { :others => '1' },
      :comment => { :comment => "Prefer this name"}
    }
    post_requires_login(:approve_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name") # Success

    current_name = Name.find(current_name.id)
    assert(!current_name.deprecated)
    assert_equal(current_past_name_count+1, current_name.versions.length) # past name should have been created
    assert(!current_name.versions.latest.deprecated)
    assert_equal(current_version + 1, current_name.version)
    assert_not_equal(current_notes, current_name.notes)

    for n in approved_synonyms
      n = Name.find(n.id)
      assert(n.deprecated)
    end
  end

  # approve a deprecated name, but don't deprecate the synonyms
  def test_do_approval_no_deprecate
    current_name = @lactarius_alpigenes
    assert(current_name.deprecated)
    assert(current_name.synonym)
    current_past_name_count = current_name.versions.length
    approved_synonyms = current_name.approved_synonyms

    params = {
      :id => current_name.id,
      :deprecate => { :others => '0' },
      :comment => { :comment => ""}
    }
    post_requires_login(:approve_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name") # Success

    current_name = Name.find(current_name.id)
    assert(!current_name.deprecated)
    assert_equal(current_past_name_count+1, current_name.versions.length) # past name should have been created
    assert(!current_name.versions.latest.deprecated)

    for n in approved_synonyms
      n = Name.find(n.id)
      assert(!n.deprecated)
    end
  end

  # ----------------------------
  #  Email Tracking (Naming Notifications).
  # ----------------------------

  def test_email_tracking
    name = @coprinus_comatus
    params = { "id" => name.id.to_s }
    requires_login(:email_tracking, params)
    assert_response :success
    assert_form_action :action => 'email_tracking'
  end

  def test_email_tracking_enable_no_note
    name = @conocybe_filaris
    count_before = Notification.find(:all).length
    notification = Notification.find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert_nil(notification)
    params = {
      :id => name.id,
      :commit => :app_enable.t,
      :notification => {
        :note_template => ""
      }
    }
    post_requires_login(:email_tracking, params, false)
    count_after = Notification.find(:all).length # This is needed before the next find for some reason
    assert_equal(count_before+1, count_after)
    notification = Notification.find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert(notification)
    assert_nil(notification.note_template)
    assert_nil(notification.calc_note(@rolf, @coprinus_comatus_obs))
  end

  def test_email_tracking_enable_with_note
    name = @conocybe_filaris
    count_before = Notification.find(:all).length
    notification = Notification.find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert_nil(notification)
    params = {
      :id => name.id,
      :commit => :app_enable.t,
      :notification => {
        :note_template => 'A note about :observation from :observer'
      }
    }
    post_requires_login(:email_tracking, params, false)
    count_after = Notification.find(:all).length # This is needed before the next find for some reason
    assert_equal(count_before+1, count_after)
    notification = Notification.find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert(notification)
    assert(notification.note_template)
    assert(notification.calc_note(@mary, @coprinus_comatus_obs))
  end

  def test_email_tracking_update_add_note
    name = @coprinus_comatus
    count_before = Notification.find(:all).length
    notification = Notification.find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert(notification)
    assert_nil(notification.note_template)
    params = {
      :id => name.id,
      :commit => 'Update',
      :notification => {
        :note_template => 'A note about :observation from :observer'
      }
    }
    post_requires_login(:email_tracking, params, false)
    count_after = Notification.find(:all).length # This is needed before the next find for some reason
    assert_equal(count_before, count_after)
    notification = Notification.find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert(notification)
    assert(notification.note_template)
    assert(notification.calc_note(@rolf, @coprinus_comatus_obs))
  end

  def test_email_tracking_disable
    name = @coprinus_comatus
    count_before = Notification.find(:all).length
    notification = Notification.find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert(notification)
    params = {
      :id => name.id,
      :commit => :app_disable.t,
      :notification => {
        :note_template => 'A note about :observation from :observer'
      }
    }
    post_requires_login(:email_tracking, params, false)
    # count_after = Notification.find(:all).length # This is needed before the next find for some reason
    # assert_equal(count_before - 1, count_after)
    notification = Notification.find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert_nil(notification)
  end

  def test_set_review_status_reviewer
    name = @coprinus_comatus
    assert_equal(:unreviewed, name.review_status)
    assert(@rolf.in_group('reviewers'))
    params = {
      :id => name.id,
      :value => 'vetted'
    }
    post_requires_login(:set_review_status, params, false, @rolf.login)
    assert_redirected_to(:controller => "name", :action => "show_name")
    name = Name.find(name.id) # Reload
    assert_equal(:vetted, name.review_status)
  end

  def test_set_review_status_non_reviewer
    name = @coprinus_comatus
    assert_equal(:unreviewed, name.review_status)
    assert(!@mary.in_group('reviewers'))
    params = {
      :id => name.id,
      :value => 'vetted'
    }
    post_requires_login(:set_review_status, params, false, @mary.login)
    assert_redirected_to(:controller => "name", :action => "show_name")
    name = Name.find(name.id) # Reload
    assert_equal(:unreviewed, name.review_status)
  end

  def test_send_author_request
    params = {
      :id => @coprinus_comatus.id,
      :email => {
        :subject => "Author request subject",
        :message => "Message for authors"
      }
    }
    requires_login :send_author_request, params, false
    assert_equal(:request_success.t, flash[:notice])
    assert_redirected_to(:action => "show_name", :id => @coprinus_comatus.id)
  end

  def test_author_request
    id = @coprinus_comatus.id
    requires_login(:author_request, {:id => id})
    assert_form_action(:action => 'send_author_request', :id => id)
  end

  # ----------------------------
  #  Interest.
  # ----------------------------

  def test_interest_in_show_name
    # No interest in this name yet.
    @request.session[:user_id] = @rolf.id
    get(:show_name, { :id => @peltigera.id })
    assert_response :success
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => @peltigera.id, :state => 1
    })
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => @peltigera.id, :state => -1
    })

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.new(:object => @peltigera, :user => @rolf, :state => true).save
    @request.session[:user_id] = @rolf.id
    get(:show_name, { :id => @peltigera.id })
    assert_response :success
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => @peltigera.id, :state => 0
    })
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => @peltigera.id, :state => -1
    })

    # Destroy that interest, create new one with interest off.
    Interest.find_all_by_user_id(@rolf.id).last.destroy
    Interest.new(:object => @peltigera, :user => @rolf, :state => false).save
    @request.session[:user_id] = @rolf.id
    get(:show_name, { :id => @peltigera.id })
    assert_response :success
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => @peltigera.id, :state => 0
    })
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>/, {
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => @peltigera.id, :state => 1
    })
  end
end
