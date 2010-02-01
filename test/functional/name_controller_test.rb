require File.dirname(__FILE__) + '/../boot'

class NameControllerTest < ControllerTestCase

  def empty_notes
    result = {}
    for f in Name.all_note_fields
      result[f] = ""
    end
    result
  end

################################################################################

  def test_name_index
    get_with_dump(:name_index)
    assert_response('list_names')
  end

  def test_observation_index
    get_with_dump(:observation_index)
    assert_response('list_names')
  end

  def test_authored_names
    get_with_dump(:authored_names)
    assert_response(:action => :show_name, :id => 2)
  end

  def test_show_name
    get_with_dump(:show_name, :id => 2)
    assert_response('show_name')
  end

  def test_show_past_name
    get_with_dump(:show_past_name, :id => 2)
    assert_response('show_past_name')
  end

  def test_names_by_author
    get_with_dump(:names_by_author, :id => 1)
    assert_response(:action => :show_name, :id => 2)
  end

  def test_names_by_editor
    get_with_dump(:names_by_editor, :id => 1)
    assert_response(:action => :show_name, :id => 2)
  end

  def test_name_search
    get_with_dump(:name_search, :pattern => '56')
    assert_response('list_names')
    assert_equal(:name_index_matching.t(:pattern => '56'),
                 @controller.instance_variable_get('@title'))
  end

  def test_advanced_search
    query = Query.lookup_and_save(:Name, :advanced,
      :name => "Don't know",
      :user => "myself",
      :content => "Long pink stem and small pink cap",
      :location => "Eastern Oklahoma"
    )
    get(:advanced_search, @controller.query_params(query))
    assert_response('list_names')
  end

  def test_edit_name
    name = names(:coprinus_comatus)
    params = { "id" => name.id.to_s }
    requires_login(:edit_name, params)
    assert_form_action(:action => 'edit_name')
  end

  def test_create_name
    requires_login(:create_name)
    assert_form_action(:action => 'create_name')
  end

  def test_bulk_name_edit_list
    requires_login(:bulk_name_edit)
    assert_form_action(:action => 'bulk_name_edit')
  end

  def test_change_synonyms
    name = names(:chlorophyllum_rachodes)
    params = { :id => name.id }
    requires_login(:change_synonyms, params)
    assert_form_action(:action => 'change_synonyms', :approved_synonyms => [])
  end

  def test_deprecate_name
    name = names(:chlorophyllum_rachodes)
    params = { :id => name.id }
    requires_login(:deprecate_name, params)
    assert_form_action(:action => 'deprecate_name', :approved_name => '')
  end

  def test_approve_name
    name = names(:lactarius_alpigenes)
    params = { :id => name.id }
    requires_login(:approve_name, params)
    assert_form_action(:action => 'approve_name')
  end

  def test_review_authors
    fungi = names(:fungi)

    # Make sure it lets reviewers get to page.
    requires_login(:review_authors, :id => 1)
    assert_response('review_authors')

    # Remove Rolf from reviewers group.
    user_groups(:reviewers).users.delete(@rolf)
    assert(!@rolf.reload.in_group('reviewers'))

    # Make sure it fails to let unauthorized users see page.
    get(:review_authors, :id => 1)
    assert_response(:action => :show_name, :id => 1)

    # Make Rolf an author.
    fungi.add_author(@rolf)
    assert_equal([@rolf.login], fungi.reload.authors.map(&:login).sort)

    # Rolf should be able to do it again now.
    get(:review_authors, :id => 1)
    assert_response('review_authors')

    # Rolf giveth with one hand...
    post(:review_authors, :id => 1, :add => @mary.id)
    assert_response('review_authors')
    assert_equal([@mary.login, @rolf.login],
                 fungi.reload.authors.map(&:login).sort)

    # ...and taketh with the other.
    post(:review_authors, :id => 1, :remove => @mary.id)
    assert_response('review_authors')
    assert_equal([@rolf.login], fungi.reload.authors.map(&:login).sort)
  end

  # ----------------------------
  #  Maps
  # ----------------------------

  # test_map - name with Observations that have Locations
  def test_map
    get_with_dump(:map, :id => names(:agaricus_campestris).id)
    assert_response('map')
  end

  # test_map_no_loc - name with Observations that don't have Locations
  def test_map_no_loc
    get_with_dump(:map, :id => names(:coprinus_comatus).id)
    assert_response('map')
  end

  # test_map_no_obs - name with no Observations
  def test_map_no_obs
    get_with_dump(:map, :id => names(:conocybe_filaris).id)
    assert_response('map')
  end

  # ----------------------------
  #  Create name.
  # ----------------------------

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
    post_requires_login(:create_name, params)
    assert_response(:action => :show_name)
    # Amanita baccata is in there but not Amanita sp., so this creates two names.
    assert_equal(30, @rolf.reload.contribution)
    assert(name = Name.find_by_text_name(text_name))
    assert_equal(text_name, name.text_name)
    assert_equal(author, name.author)
    assert_equal(@rolf, name.user)
  end

  def test_create_name_existing
    name = names(:conocybe_filaris)
    text_name = name.text_name
    count = Name.all.length
    params = {
      :name => {
        :text_name => text_name,
        :author => "",
        :rank => :Species,
        :citation => ""
      }
    }
    params[:name].merge!(empty_notes)
    login('rolf')
    post(:create_name, params)
    assert_response(:action => :show_name)
    assert_equal(10, @rolf.reload.contribution)
    name = Name.find_by_text_name(text_name)
    assert_equal(names(:conocybe_filaris), name)
    assert_equal(count, Name.all.length)
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
    login('rolf')
    post(:create_name, params)
    assert_response(:action => :show_name)
    assert_equal(110, @rolf.reload.contribution)
    assert(name = Name.find_by_text_name(text_name))
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

    login('rolf')
    post(:create_name, params)
    assert_response('create_name')

    # Should fail and no name should get created
    assert_nil(Name.find_by_text_name(text_name))
    assert_form_action(:action => 'create_name')
  end

  def test_create_name_bad_name
    text_name = "Amanita Pantherina"
    name = Name.find_by_text_name(text_name)
    assert_nil(name)
    params = {
      :name => {
        :text_name => text_name,
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)

    login('rolf')
    post(:create_name, params)
    assert_response('create_name')

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
    login('rolf')
    post(:create_name, params)
    assert_response(:action => :show_name)
    assert(name = Name.find_by_text_name(text_name))
    assert_equal('Phylum: _Basidiomycetes_', name.classification)
  end

  # ----------------------------
  #  Edit name.
  # ----------------------------

  def test_edit_name_post
    name = names(:conocybe_filaris)
    assert_equal("Conocybe filaris", name.text_name)
    assert_nil(name.author)
    past_names = name.versions.size
    assert_equal(0, name.version)
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
    post_requires_login(:edit_name, params)
    # Must be creating Conocybe sp, too.
    assert_equal(30, @rolf.reload.contribution)
    assert_equal("(Fr.) Kühner", name.reload.author)
    assert_equal("**__Conocybe filaris__** (Fr.) Kühner", name.display_name)
    assert_equal("**__Conocybe filaris__** (Fr.) Kühner", name.observation_name)
    assert_equal("Conocybe filaris (Fr.) Kühner", name.search_name)
    assert_equal("__Le Genera Galera__, 139. 1935.", name.citation)
    assert_equal(@rolf, name.user)
  end

  # Test to see if add a new general description sets the description author
  # list to the current user.
  def test_edit_name_add_gen_desc
    name = names(:conocybe_filaris)
    assert_equal([], name.authors)
    assert_nil(name.gen_desc)
    past_names = name.versions.size
    assert_equal(0, name.version)
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
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_equal(100 + 10 + old_contrib, name.reload.user.reload.contribution)
    assert(name.gen_desc)
    assert_equal([name.user], name.authors)
  end

  # Test name changes in various ways.
  def test_edit_name_deprecated
    name = names(:lactarius_alpigenes)
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
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    # (creates Lactarius since it's not in the fixtures, AND it changes L. alpigenes)
    assert_equal(30, @rolf.reload.contribution)
    assert(name.reload.deprecated)
  end

  def test_edit_name_different_user
    name = names(:macrolepiota_rhacodes)
    name_owner = name.user
    user = "rolf"
    # Make sure it's not owned by the default user
    assert_not_equal(user, name_owner.login)
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
    login('rolf')
    post(:edit_name, params)
    # Hmmm, this isn't catching the fact that Rolf shouldn't be allowed to
    # change the name, instead it seems to be doing nothing simply because he's
    # not actually changing anything!
    assert_response(:action => :show_name)
    # (In fact, it is implicitly creating Macrolepiota and adding Rolf as
    # editor on both it and M. rhacodes, since neither has an editor yet.)
    assert_equal(30, @rolf.reload.contribution)
    assert_equal(name_owner, name.reload.user)
  end

  # If non-reviewer makes significant change, should reset status.
  def test_edit_name_cause_review_status_reset
    name = peltigera = names(:peltigera)
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
    assert_response(:action => :show_name)
    assert_equal(:vetted, peltigera.reload.review_status)

    # Non-reviewer making change.
    params[:name][:citation] = "Blah blah blah."
    @request.session[:user_id] = @mary.id
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_equal(:unreviewed, peltigera.reload.review_status)

    # Set it back to vetted, and have reviewer make a change.
    User.current = @rolf
    peltigera.update_review_status(:vetted)
    params[:name][:citation] = "Whatever."
    @request.session[:user_id] = @rolf.id
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_equal(:vetted, peltigera.reload.review_status)
  end

  def test_edit_name_simple_merge
    misspelt_name = agaricus_campestrus = names(:agaricus_campestrus)
    correct_name  = agaricus_campestris = names(:agaricus_campestris)
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.versions.size
    assert_equal(0, correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs = misspelt_name.namings[0].observation
    assert_equal(2, correct_name.namings.size)
    correct_obs = correct_name.namings[0].observation
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => agaricus_campestris.text_name,
        :author => "",
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    assert(correct_name.reload)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.versions.size)
    assert_equal(3, correct_name.namings.size)
    assert_equal(agaricus_campestris, misspelt_obs.reload.name)
    assert_equal(agaricus_campestris, correct_obs.reload.name)
  end

  def test_edit_name_author_merge
    misspelt_name = names(:amanita_baccata_borealis)
    correct_name  = names(:amanita_baccata_arora)
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
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    assert(correct_name.reload)
    assert_equal(correct_author, correct_name.author)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.versions.size)
  end

  def test_edit_name_misspelling_merge
    misspelt_name = names(:suilus)
    wrong_author_name = names(:suillus_by_white)
    correct_name = names(:suillus)
    assert_equal(misspelt_name.correct_spelling, wrong_author_name)
    spelling_id = misspelt_name.correct_spelling_id
    correct_author = correct_name.author
    assert_not_equal(wrong_author_name.author, correct_author)
    params = {
      :id => wrong_author_name.id,
      :name => {
        :text_name => wrong_author_name.text_name,
        :author => correct_name.author,
        :rank => correct_name.rank
      }
    }
    params[:name].merge!(empty_notes)
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      wrong_author_name = Name.find(wrong_author_name.id)
    end
    assert_not_equal(spelling_id, misspelt_name.reload.correct_spelling_id)
    assert_equal(misspelt_name.correct_spelling, correct_name)
  end

  # Test that merged names end up as not deprecated if the
  # correct name is not deprecated.
  def test_edit_name_deprecated_merge
    misspelt_name = names(:lactarius_alpigenes)
    assert(misspelt_name.deprecated)
    correct_name = names(:lactarius_alpinus)
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
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    assert(correct_name.reload)
    assert(!correct_name.deprecated)
    assert_equal(correct_author, correct_name.author)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.versions.size)
  end

  # Test that merged names end up as not deprecated even if the
  # correct name is deprecated but the misspelt name is not deprecated
  def test_edit_name_deprecated2_merge
    misspelt_name = names(:lactarius_alpinus)
    assert(!misspelt_name.deprecated)
    correct_name = names(:lactarius_alpigenes)
    assert(correct_name.deprecated)
    assert_not_equal(misspelt_name, correct_name)
    assert_not_equal(misspelt_name.text_name, correct_name.text_name)
    correct_author = correct_name.author
    correct_text_name = correct_name.text_name
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
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      correct_name = Name.find(correct_name.id)
    end
    assert(misspelt_name.reload)
    assert(!misspelt_name.deprecated)
    assert_equal(correct_author, misspelt_name.author)
    assert_equal(correct_text_name, misspelt_name.text_name)
    assert_equal(1, misspelt_name.version)
    assert_equal(past_names+1, misspelt_name.versions.size)
  end

  # Test merge two names where the matching_name has notes.
  def test_edit_name_merge_matching_notes
    target_name = names(:russula_brevipes_no_author)
    matching_name = names(:russula_brevipes_author_notes)
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
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert(matching_name.reload)
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(target_name.id)
    end
    assert_equal(notes, matching_name.notes)
  end

  # Test merge two names that both start with notes, but the notes are cleared in the input.
  def test_edit_name_merge_both_notes
    target_name = names(:russula_cremoricolor_no_author_notes)
    matching_name = names(:russula_cremoricolor_author_notes)
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
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert(matching_name.reload)
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(target_name.id)
    end
    assert_equal(matching_notes, matching_name.notes)
  end

  def test_edit_name_misspelt_unmergeable
    misspelt_name = names(:agaricus_campestras)
    correct_name = names(:agaricus_campestris)
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.versions.size
    assert_equal(0, correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs = misspelt_name.namings[0].observation
    assert_equal(2, correct_name.namings.size)
    correct_obs = correct_name.namings[0].observation
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => "",
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    # Because misspelt name is unmergable it gets reused and
    # corrected rather than the correct name
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(correct_name.id)
    end
    assert(misspelt_name.reload)
    assert_equal(1, misspelt_name.version)
    assert_equal(past_names+1, misspelt_name.versions.size)
    assert_equal(3, misspelt_name.namings.size)
    assert_equal(names(:agaricus_campestras), misspelt_obs.reload.name)
    assert_equal(names(:agaricus_campestras), correct_obs.reload.name)
  end

  def test_edit_name_correct_unmergeable
    misspelt_name = names(:agaricus_campestrus)
    correct_name = names(:agaricus_campestras)
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    correct_notes = correct_name.notes
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.versions.size
    assert_equal(0, correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs = misspelt_name.namings[0].observation
    assert_equal(1, correct_name.namings.size)
    correct_obs = correct_name.namings[0].observation
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => "",
        :rank => :Species
      }
    }
    params[:name].merge!(empty_notes)
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    assert_equal(correct_notes, correct_name.reload.notes)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.versions.size)
    assert_equal(2, correct_name.namings.size)
    assert_equal(names(:agaricus_campestras), misspelt_obs.reload.name)
    assert_equal(names(:agaricus_campestras), correct_obs.reload.name)
  end

  def test_edit_name_neither_mergeable
    misspelt_name = names(:agaricus_campestros)
    correct_name = names(:agaricus_campestras)
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.versions.size
    assert_equal(0, correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs = misspelt_name.namings[0].observation
    assert_equal(1, correct_name.namings.size)
    correct_obs = correct_name.namings[0].observation
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
    login('rolf')
    post(:edit_name, params)
    assert_response('edit_name')
    assert(misspelt_name.reload)
    assert(correct_name.reload)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.versions.size)
    assert_equal(1, correct_name.namings.size)
    assert_equal(1, misspelt_name.namings.size)
    assert_not_equal(correct_name.namings[0], misspelt_name.namings[0])
  end

  def test_edit_name_correct_unmergable_with_notes # Should 'fail'
    misspelt_name = names(:russula_brevipes_no_author) # Shouldn't have notes
    correct_name = names(:russula_brevipes_author_notes) # Should have notes
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
    login('rolf')
    post(:edit_name, params)
    assert_response('edit_name')
    assert(misspelt_name.reload)
    assert(correct_name.reload)
  end

  def test_edit_name_page_version_merge
    page_name = names(:coprinellus_micaceus)
    other_name = names(:coprinellus_micaceus_no_author)
    assert(page_name.version > other_name.version)
    assert_not_equal(page_name, other_name)
    assert_equal(page_name.text_name, other_name.text_name)
    assert_not_equal('', correct_author = page_name.author)
    assert_equal('', other_name.author)
    past_names = page_name.versions.size
    params = {
      :id => page_name.id,
      :name => {
        :text_name => page_name.text_name,
        :author => '',
        :rank => :Species
      }.merge(empty_notes)
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      destroyed_name = Name.find(other_name.id)
    end
    assert(page_name.reload)
    assert_equal(correct_author, page_name.author)
    assert_equal(past_names, page_name.version)
  end

  def test_edit_name_other_version_merge
    page_name = names(:coprinellus_micaceus_no_author)
    other_name = names(:coprinellus_micaceus)
    assert(page_name.version < other_name.version)
    assert_not_equal(page_name, other_name)
    assert_equal(page_name.text_name, other_name.text_name)
    assert_equal('', page_name.author)
    assert_not_equal('', correct_author = other_name.author)
    past_names = other_name.versions.size
    params = {
      :id => page_name.id,
      :name => {
        :text_name => page_name.text_name,
        :author => '',
        :rank => :Species
      }.merge(empty_notes)
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      destroyed_name = Name.find(page_name.id)
    end
    assert(other_name.reload)
    assert_equal(correct_author, other_name.author)
    assert_equal(past_names, other_name.version)
  end

  def test_edit_name_add_author
    name = names(:strobilurus_diminutivus_no_author)
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
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    # It seems to be creating Strobilurus sp. as well?
    assert_equal(30, @rolf.reload.contribution)
    assert_equal(new_author, name.reload.author)
    assert_equal(old_text_name, name.text_name)
  end

  # Test merge of name with notes with name without notes
  def test_edit_name_notes
    target_name = names(:russula_brevipes_no_author)
    matching_name = names(:russula_brevipes_author_notes)
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
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    # (creates Russula since not in fixtures, changes R. brevipes, deletes some name, but leaves past_name)
    assert_equal(30, @rolf.reload.contribution)
    assert(matching_name.reload)
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(target_name.id)
    end
    assert_equal(notes, matching_name.notes)
  end

  # ----------------------------
  #  Bulk names.
  # ----------------------------

  def test_update_bulk_names_nn_synonym
    new_name_str = "Amanita fergusonii"
    assert_nil(Name.find_by_text_name(new_name_str))
    new_synonym_str = "Amanita lanei"
    assert_nil(Name.find_by_text_name(new_synonym_str))
    params = {
      :list => { :members => "#{new_name_str} = #{new_synonym_str}"},
    }
    post_requires_login(:bulk_name_edit, params)
    assert_response('bulk_name_edit')
    assert_nil(Name.find_by_text_name(new_name_str))
    assert_nil(Name.find_by_text_name(new_synonym_str))
    assert_equal(10, @rolf.reload.contribution)
  end

  def test_update_bulk_names_approved_nn_synonym
    new_name_str = "Amanita fergusonii"
    assert_nil(Name.find_by_text_name(new_name_str))
    new_synonym_str = "Amanita lanei"
    assert_nil(Name.find_by_text_name(new_synonym_str))
    params = {
      :list => { :members => "#{new_name_str} = #{new_synonym_str}"},
      :approved_names => [new_name_str, new_synonym_str]
    }
    login('rolf')
    post(:bulk_name_edit, params)
    assert_response(:controller => "observer", :action => "list_rss_logs")
    assert(new_name = Name.find_by_text_name(new_name_str))
    assert_equal(new_name_str, new_name.text_name)
    assert_equal("**__#{new_name_str}__**", new_name.display_name)
    assert(!new_name.deprecated)
    assert_equal(:Species, new_name.rank)
    assert(synonym_name = Name.find_by_text_name(new_synonym_str))
    assert_equal(new_synonym_str, synonym_name.text_name)
    assert_equal("__#{new_synonym_str}__", synonym_name.display_name)
    assert(synonym_name.deprecated)
    assert_equal(:Species, synonym_name.rank)
    assert_not_nil(new_name.synonym)
    assert_equal(new_name.synonym, synonym_name.synonym)
  end

  def test_update_bulk_names_ee_synonym
    approved_name = names(:chlorophyllum_rachodes)
    synonym_name = names(:macrolepiota_rachodes)
    assert_not_equal(approved_name.synonym, synonym_name.synonym)
    assert(!synonym_name.deprecated)
    params = {
      :list => { :members => "#{approved_name.search_name} = #{synonym_name.search_name}"},
    }
    login('rolf')
    post(:bulk_name_edit, params)
    assert_response(:controller => "observer", :action => "list_rss_logs")
    assert(!approved_name.reload.deprecated)
    assert(synonym_name.reload.deprecated)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
  end

  def test_update_bulk_names_eee_synonym
    approved_name = names(:lepiota_rachodes)
    synonym_name  = names(:lepiota_rhacodes)
    synonym_name2 = names(:chlorophyllum_rachodes)
    assert_nil(approved_name.synonym)
    assert_nil(synonym_name.synonym)
    assert_not_nil(synonym_name2.synonym)
    assert(!approved_name.deprecated)
    assert(!synonym_name.deprecated)
    assert(!synonym_name2.deprecated)
    params = { :list => {
      :members =>
        "#{approved_name.search_name} = #{synonym_name.search_name}\r\n" +
        "#{approved_name.search_name} = #{synonym_name2.search_name}"
      }
    }
    login('rolf')
    post(:bulk_name_edit, params)
    assert_response(:controller => "observer", :action => "list_rss_logs")
    assert(!approved_name.reload.deprecated)
    assert(synonym_name.reload.deprecated)
    assert(synonym_name2.reload.deprecated)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
    assert_equal(approved_name.synonym, synonym_name2.synonym)
  end

  def test_update_bulk_names_en_synonym
    approved_name = names(:chlorophyllum_rachodes)
    target_synonym = approved_name.synonym
    assert(target_synonym)
    new_synonym_str = "New name Wilson"
    assert_nil(Name.find_by_search_name(new_synonym_str))
    params = {
      :list => { :members => "#{approved_name.search_name} = #{new_synonym_str}" },
      :approved_names => [approved_name.search_name, new_synonym_str]
    }
    login('rolf')
    post(:bulk_name_edit, params)
    assert_response(:controller => "observer", :action => "list_rss_logs")
    assert(!approved_name.reload.deprecated)
    assert(synonym_name = Name.find_by_search_name(new_synonym_str))
    assert(synonym_name.deprecated)
    assert_equal(:Species, synonym_name.rank)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
    assert_equal(target_synonym, approved_name.synonym)
  end

  def test_update_bulk_names_ne_synonym
    new_name_str = "New name Wilson"
    assert_nil(Name.find_by_search_name(new_name_str))
    synonym_name = names(:macrolepiota_rachodes)
    assert(!synonym_name.deprecated)
    target_synonym = synonym_name.synonym
    assert(target_synonym)
    params = {
      :list => { :members => "#{new_name_str} = #{synonym_name.search_name}" },
      :approved_names => [new_name_str, synonym_name.search_name]
    }
    login('rolf')
    post(:bulk_name_edit, params)
    assert_response(:controller => "observer", :action => "list_rss_logs")
    assert(approved_name = Name.find_by_search_name(new_name_str))
    assert(!approved_name.deprecated)
    assert_equal(:Species, approved_name.rank)
    assert(synonym_name.reload.deprecated)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
    assert_equal(target_synonym, approved_name.synonym)
  end

  # Test a bug fix for the case of adding a subtaxon when the parent taxon is duplicated due to
  # different authors.
  def test_update_bulk_names_approved_for_dup_parents
    parent1 = names(:lentinellus_ursinus_author1)
    parent2 = names(:lentinellus_ursinus_author2)
    assert_not_equal(parent1, parent2)
    assert_equal(parent1.text_name, parent2.text_name)
    assert_not_equal(parent1.author, parent2.author)
    new_name_str = "#{parent1.text_name} f. robustus"
    assert_nil(Name.find_by_text_name(new_name_str))
    params = {
      :list => { :members => "#{new_name_str}" },
      :approved_names => [new_name_str]
    }
    login('rolf')
    post(:bulk_name_edit, params)
    assert_response(:controller => "observer", :action => "list_rss_logs")
    assert(Name.find_by_text_name(new_name_str))
  end

  # ----------------------------
  #  Synonyms.
  # ----------------------------

  # combine two Names that have no Synonym
  def test_transfer_synonyms_1_1
    selected_name = names(:lepiota_rachodes)
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    selected_past_name_count = selected_name.versions.length
    selected_version = selected_name.version

    add_name = names(:lepiota_rhacodes)
    assert(!add_name.deprecated)
    assert_equal("**__Lepiota rhacodes__** Vittad.", add_name.display_name)
    assert_nil(add_name.synonym)
    add_past_name_count = add_name.versions.length
    add_name_version = add_name.version

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.text_name },
      :deprecate => { :all => "1" }
    }
    post_requires_login(:change_synonyms, params)
    assert_response(:action => :show_name)

    assert(add_name.reload.deprecated)
    assert_equal("__Lepiota rhacodes__ Vittad.", add_name.display_name)
    assert_equal(add_past_name_count+1, add_name.versions.length) # past name should have been created
    assert(add_name.versions.latest.deprecated)
    assert_not_nil(add_synonym = add_name.synonym)
    assert_equal(add_name_version+1, add_name.version)

    assert(!selected_name.reload.deprecated)
    assert_equal(selected_past_name_count, selected_name.versions.length)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)

    assert(!names(:lepiota).reload.deprecated)
  end

  # combine two Names that have no Synonym and no deprecation
  def test_transfer_synonyms_1_1_nd
    selected_name = names(:lepiota_rachodes)
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    selected_version = selected_name.version

    add_name = names(:lepiota_rhacodes)
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)
    add_version = add_name.version

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.text_name },
      :deprecate => { :all => "0" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => :show_name)

    assert(!add_name.reload.deprecated)
    assert_not_nil(add_synonym = add_name.synonym)
    assert_equal(add_version, add_name.version)

    assert(!selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)
  end

  # add new name string to Name with no Synonym but not approved
  def test_transfer_synonyms_1_0_na
    selected_name = names(:lepiota_rachodes)
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => "Lepiota rachodes var. rachodes" },
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response('change_synonyms')

    assert_nil(selected_name.reload.synonym)
    assert(!selected_name.deprecated)
  end

  # add new name string to Name with no Synonym but approved
  def test_transfer_synonyms_1_0_a
    selected_name = names(:lepiota_rachodes)
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => "Lepiota rachodes var. rachodes" },
      :approved_names => ["Lepiota rachodes var. rachodes"],
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => :show_name)

    assert_equal(selected_version, selected_name.reload.version)
    assert_not_nil(synonym = selected_name.synonym)
    assert_equal(2, synonym.names.length)
    for n in synonym.names
      if n == selected_name
        assert(!n.deprecated)
      else
        assert(n.deprecated)
      end
    end

    assert(!names(:lepiota).reload.deprecated)
  end

  # add new name string to Name with no Synonym but approved
  def test_transfer_synonyms_1_00_a
    page_name = names(:lepiota_rachodes)
    assert(!page_name.deprecated)
    assert_nil(page_name.synonym)

    params = {
      :id => page_name.id,
      :synonym => {
        :members => "Lepiota rachodes var. rachodes\r\n" +
                    "Lepiota rhacodes var. rhacodes"
      },
      :approved_names => [
        "Lepiota rachodes var. rachodes",
        "Lepiota rhacodes var. rhacodes"
      ],
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => :show_name)

    assert(!page_name.reload.deprecated)
    assert_not_nil(synonym = page_name.synonym)
    assert_equal(3, synonym.names.length)
    for n in synonym.names
      if n == page_name
        assert(!n.deprecated)
      else
        assert(n.deprecated)
      end
    end

    assert(!names(:lepiota).reload.deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym
  def test_transfer_synonyms_n_1
    add_name = names(:lepiota_rachodes)
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)
    add_version = add_name.version

    selected_name = names(:chlorophyllum_rachodes)
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => :show_name)

    assert(add_name.reload.deprecated)
    assert_not_nil(add_synonym = add_name.synonym)
    assert_equal(add_version+1, add_name.version)
    assert(!names(:lepiota).reload.deprecated)

    assert(!selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(start_size + 1, add_synonym.names.size)

    assert(!names(:chlorophyllum).reload.deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym wih the alternates checked
  def test_transfer_synonyms_n_1_c
    add_name = names(:lepiota_rachodes)
    assert(!add_name.deprecated)
    add_version = add_name.version
    assert_nil(add_name.synonym)

    selected_name = names(:chlorophyllum_rachodes)
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
        existing_synonyms[n.id.to_s] = "1"
      end
    end
    assert_not_nil(split_name)

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => :show_name)

    assert(add_name.reload.deprecated)
    assert_equal(add_version+1, add_name.version)
    assert_not_nil(add_synonym = add_name.synonym)

    assert(!selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(start_size + 1, add_synonym.names.size)

    assert(!split_name.reload.deprecated)
    assert_equal(add_synonym, split_synonym = split_name.synonym)

    assert(!names(:lepiota).reload.deprecated)
    assert(!names(:chlorophyllum).reload.deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym wih the alternates not checked
  def test_transfer_synonyms_n_1_nc
    add_name = names(:lepiota_rachodes)
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)
    add_version = add_name.version

    selected_name = names(:chlorophyllum_rachodes)
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
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => :show_name)

    assert(add_name.reload.deprecated)
    assert_equal(add_version+1, add_name.version)
    assert_not_nil(add_synonym = add_name.synonym)

    assert(!selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)

    assert(!split_name.reload.deprecated)
    assert_equal(split_version, split_name.version)
    assert_nil(split_name.synonym)

    assert(!names(:lepiota).reload.deprecated)
    assert(!names(:chlorophyllum).reload.deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym with no approved synonyms
  def test_transfer_synonyms_1_n_ns
    add_name = names(:chlorophyllum_rachodes)
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = names(:lepiota_rachodes)
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response('change_synonyms')

    assert(!add_name.reload.deprecated)
    assert_equal(add_version, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    assert(!selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_nil(selected_synonym)

    assert_equal(start_size, add_synonym.names.size)
    assert(!names(:lepiota).reload.deprecated)
    assert(!names(:chlorophyllum).reload.deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym with all approved synonyms
  def test_transfer_synonyms_1_n_s
    add_name = names(:chlorophyllum_rachodes)
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = names(:lepiota_rachodes)
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    synonym_ids = (add_synonym.names.map {|n| n.id}).join('/')
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :approved_synonyms => synonym_ids,
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => "show_name")

    assert(add_name.reload.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    assert(!selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)

    assert_equal(start_size+1, add_synonym.names.size)
    assert(!names(:lepiota).reload.deprecated)
    assert(!names(:chlorophyllum).reload.deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym with all approved synonyms
  def test_transfer_synonyms_1_n_l
    add_name = names(:chlorophyllum_rachodes)
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = names(:lepiota_rachodes)
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    synonym_names = (add_synonym.names.map {|n| n.search_name}).join("\r\n")
    params = {
      :id => selected_name.id,
      :synonym => { :members => synonym_names },
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => "show_name")

    assert(add_name.reload.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    assert(!selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)

    assert_equal(start_size+1, add_synonym.names.size)
    assert(!names(:lepiota).reload.deprecated)
    assert(!names(:chlorophyllum).reload.deprecated)
  end

  # combine two Names that each have Synonyms with no chosen names
  def test_transfer_synonyms_n_n_ns
    add_name = names(:chlorophyllum_rachodes)
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = names(:macrolepiota_rachodes)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response('change_synonyms')

    assert(!add_name.reload.deprecated)
    assert_not_nil(add_synonym = add_name.synonym)
    assert_equal(add_start_size, add_synonym.names.size)

    assert(!selected_name.reload.deprecated)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_not_equal(add_synonym, selected_synonym)
    assert_equal(selected_start_size, selected_synonym.names.size)
  end

  # combine two Names that each have Synonyms with all chosen names
  def test_transfer_synonyms_n_n_s
    add_name = names(:chlorophyllum_rachodes)
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = names(:macrolepiota_rachodes)
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
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => "show_name")

    assert(add_name.reload.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_start_size + selected_start_size, add_synonym.names.size)

    assert(!selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
  end

  # combine two Names that each have Synonyms with all names listed
  def test_transfer_synonyms_n_n_l
    add_name = names(:chlorophyllum_rachodes)
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = names(:macrolepiota_rachodes)
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
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => "show_name")

    assert(add_name.reload.deprecated)
    assert_equal(add_version+1, add_name.version)
    assert_not_nil(add_synonym = add_name.synonym)
    assert_equal(add_start_size + selected_start_size, add_synonym.names.size)

    assert(!selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(add_synonym, selected_synonym)
  end

  # split off a single name from a name with multiple synonyms
  def test_transfer_synonyms_split_3_1
    selected_name = names(:lactarius_alpinus)
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
          existing_synonyms[n.id.to_s] = "1" # Check the rest
        end
      end
    end
    split_version = split_name.version
    kept_version = kept_name.version
    params = {
      :id => selected_name.id,
      :synonym => { :members => "" },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => "show_name")

    assert_equal(selected_version, selected_name.reload.version)
    assert(!selected_name.deprecated)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(selected_start_size - 1, selected_synonym.names.size)

    assert(split_name.reload.deprecated)
    assert_equal(split_version, split_name.version)
    assert_nil(split_name.synonym)

    assert(kept_name.deprecated)
    assert_equal(kept_version, kept_name.version)
  end

  # split 4 synonymized names into two sets of synonyms with two members each
  def test_transfer_synonyms_split_2_2
    selected_name = names(:lactarius_alpinus)
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
          existing_synonyms[n.id.to_s] = "1"
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
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => :show_name)

    assert(!selected_name.reload.deprecated)
    assert_equal(selected_version, selected_name.version)
    assert_not_nil(selected_synonym = selected_name.synonym)
    assert_equal(selected_start_size - 2, selected_synonym.names.size)

    assert(split_names[0].reload.deprecated)
    assert_not_nil(split_synonym = split_names[0].synonym)
    assert(split_names[1].reload.deprecated)
    assert_not_equal(split_names[0], split_names[1])
    assert_equal(split_synonym, split_names[1].synonym)
    assert_equal(2, split_synonym.names.size)
  end

  # take four synonymized names and separate off one
  def test_transfer_synonyms_split_1_3
    selected_name = names(:lactarius_alpinus)
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
      :deprecate => { :all => "1" }
    }
    login('rolf')
    post(:change_synonyms, params)
    assert_response(:action => :show_name)

    assert_equal(selected_version, selected_name.reload.version)
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)

    assert(split_name.reload.deprecated)
    assert_equal(split_version, split_name.version)
    assert_not_nil(split_synonym = split_name.synonym)
    assert_equal(selected_start_size - 1, split_synonym.names.size)
  end

  # ----------------------------
  #  Deprecation.
  # ----------------------------

  # deprecate an existing unique name with another existing name
  def test_do_deprecation
    old_name = names(:lepiota_rachodes)
    assert(!old_name.deprecated)
    assert_nil(old_name.synonym)
    old_past_name_count = old_name.versions.length
    old_version = old_name.version
    old_notes = old_name.notes

    new_name = names(:chlorophyllum_rachodes)
    assert(!new_name.deprecated)
    assert_not_nil(new_name.synonym)
    new_synonym_length = new_name.synonym.names.size
    new_past_name_count = new_name.versions.length
    new_version = new_name.version
    new_notes = new_name.notes

    params = {
      :id => old_name.id,
      :proposed => { :name => new_name.text_name },
      :comment => { :comment => "Don't like this name" }
    }
    post_requires_login(:deprecate_name, params)
    assert_response(:action => :show_name)

    assert(old_name.reload.deprecated)
    assert_equal(old_past_name_count+1, old_name.versions.length)
    assert(old_name.versions.latest.deprecated)
    assert_not_nil(old_synonym = old_name.synonym)
    assert_equal(old_version+1, old_name.version)
    assert_not_equal(old_notes, old_name.notes)

    assert(!new_name.reload.deprecated)
    assert_equal(new_past_name_count, new_name.versions.length)
    assert_not_nil(new_synonym = new_name.synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(new_synonym_length+1, new_synonym.names.size)
    assert_equal(new_version, new_name.version)
    assert_equal(new_notes, new_name.notes)
  end

  # deprecate an existing unique name with an ambiguous name
  def test_do_deprecation_ambiguous
    old_name = names(:lepiota_rachodes)
    assert(!old_name.deprecated)
    assert_nil(old_name.synonym)
    old_past_name_count = old_name.versions.length

    new_name = names(:amanita_baccata_arora) # Ambiguous text name
    assert(!new_name.deprecated)
    assert_nil(new_name.synonym)
    new_past_name_count = new_name.versions.length

    params = {
      :id => old_name.id,
      :proposed => { :name => new_name.text_name },
      :comment => { :comment => ""}
    }
    login('rolf')
    post(:deprecate_name, params)
    assert_response('deprecate_name')
    # Fail since name can't be disambiguated

    assert(!old_name.reload.deprecated)
    assert_equal(old_past_name_count, old_name.versions.length)
    assert_nil(old_name.synonym)

    assert(!new_name.reload.deprecated)
    assert_equal(new_past_name_count, new_name.versions.length)
    assert_nil(new_name.synonym)
  end

  # deprecate an existing unique name with an ambiguous name, but using :chosen_name to disambiguate
  def test_do_deprecation_chosen
    old_name = names(:lepiota_rachodes)
    assert(!old_name.deprecated)
    assert_nil(old_name.synonym)
    old_past_name_count = old_name.versions.length

    new_name = names(:amanita_baccata_arora) # Ambiguous text name
    assert(!new_name.deprecated)
    assert_nil(new_name.synonym)
    new_synonym_length = 0
    new_past_name_count = new_name.versions.length

    params = {
      :id => old_name.id,
      :proposed => { :name => new_name.text_name },
      :chosen_name => { :name_id => new_name.id },
      :comment => { :comment => "Don't like this name"}
    }
    login('rolf')
    post(:deprecate_name, params)
    assert_response(:action => :show_name)

    assert(old_name.reload.deprecated)
    assert_equal(old_past_name_count+1, old_name.versions.length)
    assert(old_name.versions.latest.deprecated)
    assert_not_nil(old_synonym = old_name.synonym)

    assert(!new_name.reload.deprecated)
    assert_equal(new_past_name_count, new_name.versions.length)
    assert_not_nil(new_synonym = new_name.synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(2, new_synonym.names.size)
  end

  # deprecate an existing unique name with an ambiguous name
  def test_do_deprecation_new_name
    old_name = names(:lepiota_rachodes)
    assert(!old_name.deprecated)
    assert_nil(old_name.synonym)
    old_past_name_count = old_name.versions.length

    new_name_str = "New name"

    params = {
      :id => old_name.id,
      :proposed => { :name => new_name_str },
      :comment => { :comment => "Don't like this name" }
    }
    login('rolf')
    post(:deprecate_name, params)
    assert_response('deprecate_name')
    # Fail since new name is not approved

    assert(!old_name.reload.deprecated)
    assert_equal(old_past_name_count, old_name.versions.length)
    assert_nil(old_name.synonym)
  end

  # deprecate an existing unique name with an ambiguous name, but using :chosen_name to disambiguate
  def test_do_deprecation_approved_new_name
    old_name = names(:lepiota_rachodes)
    assert(!old_name.deprecated)
    assert_nil(old_name.synonym)
    old_past_name_count = old_name.versions.length

    new_name_str = "New name"

    params = {
      :id => old_name.id,
      :proposed => { :name => new_name_str },
      :approved_name => new_name_str,
      :comment => { :comment => "Don't like this name" }
    }
    login('rolf')
    post(:deprecate_name, params)
    assert_response(:action => :show_name)

    assert(old_name.reload.deprecated)
    assert_equal(old_past_name_count+1, old_name.versions.length) # past name should have been created
    assert(old_name.versions.latest.deprecated)
    assert_not_nil(old_synonym = old_name.synonym)

    new_name = Name.find_by_text_name(new_name_str)
    assert(!new_name.deprecated)
    assert_not_nil(new_synonym = new_name.synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(2, new_synonym.names.size)
  end

  # ----------------------------
  #  Approval.
  # ----------------------------

  # approve a deprecated name
  def test_do_approval_default
    old_name = names(:lactarius_alpigenes)
    assert(old_name.deprecated)
    assert(old_name.synonym)
    old_past_name_count = old_name.versions.length
    old_version = old_name.version
    approved_synonyms = old_name.approved_synonyms
    old_notes = old_name.notes

    params = {
      :id => old_name.id,
      :deprecate => { :others => '1' },
      :comment => { :comment => "Prefer this name"}
    }
    post_requires_login(:approve_name, params)
    assert_response(:action => :show_name)

    assert(!old_name.reload.deprecated)
    assert_equal(old_past_name_count+1, old_name.versions.length)
    assert(!old_name.versions.latest.deprecated)
    assert_equal(old_version + 1, old_name.version)
    assert_not_equal(old_notes, old_name.notes)

    for n in approved_synonyms
      assert(n.reload.deprecated)
    end
  end

  # approve a deprecated name, but don't deprecate the synonyms
  def test_do_approval_no_deprecate
    old_name = names(:lactarius_alpigenes)
    assert(old_name.deprecated)
    assert(old_name.synonym)
    old_past_name_count = old_name.versions.length
    approved_synonyms = old_name.approved_synonyms

    params = {
      :id => old_name.id,
      :deprecate => { :others => '0' },
      :comment => { :comment => ""}
    }
    login('rolf')
    post(:approve_name, params)
    assert_response(:action => :show_name)

    assert(!old_name.reload.deprecated)
    assert_equal(old_past_name_count+1, old_name.versions.length)
    assert(!old_name.versions.latest.deprecated)

    for n in approved_synonyms
      assert(!n.reload.deprecated)
    end
  end

  # ----------------------------
  #  Naming Notifications.
  # ----------------------------

  def test_email_tracking
    name = names(:coprinus_comatus)
    params = { :id => name.id.to_s }
    requires_login(:email_tracking, params)
    assert_response('email_tracking')
    assert_form_action(:action => 'email_tracking')
  end

  def test_email_tracking_enable_no_note
    name = names(:conocybe_filaris)
    count_before = Notification.all.length
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert_nil(notification)
    params = {
      :id => name.id,
      :commit => :app_enable.t,
      :notification => {
        :note_template => ""
      }
    }
    post_requires_login(:email_tracking, params)
    # This is needed before the next find for some reason
    count_after = Notification.all.length
    assert_equal(count_before+1, count_after)
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert(notification)
    assert_nil(notification.note_template)
    assert_nil(notification.calc_note(:user => @rolf,
                                      :naming => namings(:coprinus_comatus_naming)))
  end

  def test_email_tracking_enable_with_note
    name = names(:conocybe_filaris)
    count_before = Notification.all.length
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert_nil(notification)
    params = {
      :id => name.id,
      :commit => :app_enable.t,
      :notification => {
        :note_template => 'A note about :observation from :observer'
      }
    }
    login('rolf')
    post(:email_tracking, params)
    assert_response(:action => :show_name)
    # This is needed before the next find for some reason
    count_after = Notification.all.length
    assert_equal(count_before+1, count_after)
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert(notification)
    assert(notification.note_template)
    assert(notification.calc_note(:user => @mary,
                                  :naming => namings(:coprinus_comatus_naming)))
  end

  def test_email_tracking_update_add_note
    name = names(:coprinus_comatus)
    count_before = Notification.all.length
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert(notification)
    assert_nil(notification.note_template)
    params = {
      :id => name.id,
      :commit => 'Update',
      :notification => {
        :note_template => 'A note about :observation from :observer'
      }
    }
    login('rolf')
    post(:email_tracking, params)
    assert_response(:action => :show_name)
    # This is needed before the next find for some reason
    count_after = Notification.all.length
    assert_equal(count_before, count_after)
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert(notification)
    assert(notification.note_template)
    assert(notification.calc_note(:user => @rolf,
                                  :naming => namings(:coprinus_comatus_naming)))
  end

  def test_email_tracking_disable
    name = names(:coprinus_comatus)
    count_before = Notification.all.length
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert(notification)
    params = {
      :id => name.id,
      :commit => :app_disable.t,
      :notification => {
        :note_template => 'A note about :observation from :observer'
      }
    }
    login('rolf')
    post(:email_tracking, params)
    assert_response(:action => :show_name)
    # This is needed before the next find for some reason
    # count_after = Notification.all.length
    # assert_equal(count_before - 1, count_after)
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert_nil(notification)
  end

  # ----------------------------
  #  Review status.
  # ----------------------------

  def test_set_review_status_reviewer
    name = names(:coprinus_comatus)
    assert_equal(:unreviewed, name.review_status)
    assert(@rolf.in_group('reviewers'))
    params = {
      :id => name.id,
      :value => 'vetted'
    }
    post_requires_login(:set_review_status, params)
    assert_response(:action => :show_name)
    assert_equal(:vetted, name.reload.review_status)
  end

  def test_set_review_status_non_reviewer
    name = names(:coprinus_comatus)
    assert_equal(:unreviewed, name.review_status)
    assert(!@mary.in_group('reviewers'))
    params = {
      :id => name.id,
      :value => 'vetted'
    }
    post_requires_login(:set_review_status, params, 'mary')
    assert_response(:action => :show_name)
    assert_equal(:unreviewed, name.reload.review_status)
  end

  def test_send_author_request
    params = {
      :id => names(:coprinus_comatus).id,
      :email => {
        :subject => "Author request subject",
        :message => "Message for authors"
      }
    }
    post_requires_login(:author_request, params)
    assert_response(:action => "show_name", :id => names(:coprinus_comatus).id)
    assert_flash(:request_success.t)
  end

  def test_author_request
    id = names(:coprinus_comatus).id
    requires_login(:author_request, :id => id)
    assert_form_action(:action => 'author_request', :id => id)
  end

  # ----------------------------
  #  Interest.
  # ----------------------------

  def test_interest_in_show_name
    peltigera = names(:peltigera)
    login('rolf')

    # No interest in this name yet.
    get(:show_name, :id => peltigera.id)
    assert_response(:success)
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => peltigera.id, :state => 1
    )
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => peltigera.id, :state => -1
    )

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.create(:object => peltigera, :user => @rolf, :state => true)
    get(:show_name, :id => peltigera.id)
    assert_response(:success)
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => peltigera.id, :state => 0
    )
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => peltigera.id, :state => -1
    )

    # Destroy that interest, create new one with interest off.
    Interest.find_all_by_user_id(@rolf.id).last.destroy
    Interest.create(:object => peltigera, :user => @rolf, :state => false)
    get(:show_name, :id => peltigera.id)
    assert_response(:success)
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => peltigera.id, :state => 0
    )
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => peltigera.id, :state => 1
    )
  end
end
