require File.dirname(__FILE__) + '/../test_helper'
require 'observer_controller'
require 'fileutils'

# Re-raise errors caught by the controller.
class ObserverController; def rescue_action(e) raise e end; end

class CurrentTest < Test::Unit::TestCase
  fixtures :observations
  fixtures :users
  fixtures :comments
  fixtures :images
  fixtures :images_observations
  fixtures :species_lists
  fixtures :observations_species_lists
  fixtures :names
  fixtures :rss_logs
  fixtures :synonyms
  fixtures :licenses

  def setup
    @controller = NameController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def teardown
  end

  def test_trivial
    assert_equal(1+1, 2)
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
        :rank => target_name.rank,
        :notes => ""
      }
    }
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
        :rank => target_name.rank,
        :notes => "" # Explicitly clear the notes
      }
    }
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
    past_names = correct_name.past_names.size
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
        :rank => :Species,
        :notes => ""
      }
    }
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
    assert(past_names+1 == correct_name.past_names.size)

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
    past_names = correct_name.past_names.size
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
        :rank => :Species,
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert_equal(correct_notes, correct_name.notes)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.past_names.size)

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
    past_names = correct_name.past_names.size
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
        :rank => misspelt_name.rank,
        :notes => misspelt_name.notes
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_response :success
    assert_template 'edit_name'
    misspelt_name = Name.find(misspelt_name.id)
    assert(misspelt_name)
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert(0 == correct_name.version)
    assert(past_names == correct_name.past_names.size)
    assert_equal(1, correct_name.namings.size)
    assert_equal(1, misspelt_name.namings.size)
    assert_not_equal(correct_name.namings[0], misspelt_name.namings[0])
  end
end

class StillToCome
  # no deprecation
end
