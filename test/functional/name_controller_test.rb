require File.dirname(__FILE__) + '/../boot'

class NameControllerTest < ControllerTestCase

  def setup
    @auth_pts = 100
    @edit_pts = 10
    @name_pts = 0
  end

  def empty_notes
    result = {}
    for f in NameDescription.all_note_fields
      result[f] = ''
    end
    result
  end

  # Create a draft for a project.
  def create_draft_tester(project, name, user=nil, success=true)
    count = NameDescription.count
    params = {
      :id => name.id,
      :source => 'project',
      :project => project.id,
    }
    requires_login(:create_name_description, params, user.login)
    if success
      assert_response('create_name_description')
      assert_equal(count, NameDescription.count)
    else
      assert_response(:controller => 'project',
                      :action => 'show_project', :id => project.id)
      assert_equal(count, NameDescription.count)
    end
  end

  # Edit a draft for a project (GET).
  def edit_draft_tester(draft, user=nil, success=true, reader=true)
    if user
      assert_not_equal(user, draft.user)
    else
      user = draft.user
    end
    params = {
      :id => draft.id
    }
    requires_login(:edit_name_description, params, user.login)
    if success
      assert_response('edit_name_description')
    elsif reader
      assert_response(:action => "show_name_description", :id => draft.id)
    else
      assert_response(:action => "show_name", :id => draft.name_id)
    end
  end

  # Edit a draft for a project (POST).
  def edit_draft_post_helper(draft, user, params={}, permission=true, success=true)
    gen_desc = "This is a very general description."
    assert_not_equal(gen_desc, draft.gen_desc)
    diag_desc = "This is a diagnostic description"
    assert_not_equal(diag_desc, draft.diag_desc)
    classification = "Family: _Agaricaceae_"
    assert_not_equal(classification, draft.classification)
    params = {
      :id => draft.id,
      :description => {
        :gen_desc => gen_desc,
        :diag_desc => diag_desc,
        :classification => classification,
      }.merge(params)
    }
    post_requires_login(:edit_name_description, params, user.login)
    if permission && !success
      assert_response('edit_name_description')
    elsif draft.is_reader?(user)
      assert_response(:action => 'show_name_description', :id => draft.id)
    else
      assert_response(:action => 'show_name', :id => draft.name_id)
    end
    draft.reload
    if permission && success
      assert_equal(gen_desc, draft.gen_desc)
      assert_equal(diag_desc, draft.diag_desc)
      assert_equal(classification, draft.classification)
    else
      assert_not_equal(gen_desc, draft.gen_desc)
      assert_not_equal(diag_desc, draft.diag_desc)
      assert_not_equal(classification, draft.classification)
    end
  end

#   def publish_draft_helper(draft, user=nil, success=true, action='show_name_description')
#     if user
#       assert_not_equal(draft.user, user)
#     else
#       user = draft.user
#     end
#     draft_gen_desc = draft.gen_desc
#     name_gen_desc = draft.name.gen_desc
#     same_gen_desc = (draft_gen_desc == draft.name.gen_desc)
#     name_id = draft.name_id
#     params = {
#       :id => draft.id
#     }
#     requires_login(:publish_draft, params, user.login)
#     name = Name.find(name_id)
#     if success
#       assert_response(:controller => 'name', :action => 'show_name', :id => name_id)
#       assert_equal(draft_gen_desc, name.gen_desc)
#     else
#       assert_response(:action => action, :id => draft.id)
#       assert_equal(same_gen_desc, draft_gen_desc == draft.name.gen_desc)
#     end
#   end

  # Destroy a draft of a project.
  def destroy_draft_helper(draft, user, success=true)
    assert(draft)
    count = NameDescription.count
    params = {
      :id => draft.id
    }
    requires_login(:destroy_name_description, params, user.login)
    if success
      assert_response(:action => 'show_name', :id => draft.name_id)
      assert_raises(ActiveRecord::RecordNotFound) do
        draft = NameDescription.find(draft.id)
      end
      assert_equal(count - 1, NameDescription.count)
    else
      assert(NameDescription.find(draft.id))
      assert_equal(count, NameDescription.count)
      if draft.is_reader?(user)
        assert_response(:action => 'show_name_description', :id => draft.id)
      else
        assert_response(:action => 'show_name', :id => draft.name_id)
      end
    end
  end

################################################################################

  def test_name_index
    get_with_dump(:list_names)
    assert_response('list_names')
  end

  def test_observation_index
    get_with_dump(:observation_index)
    assert_response('list_names')
  end

  def test_authored_names
    get_with_dump(:authored_names)
    assert_response(:action => 'show_name', :id => 2,
                    :params => @controller.query_params)
  end

  def test_show_name
    assert_equal(0, Query.count)
    get_with_dump(:show_name, :id => 2)
    assert_response('show_name')
    # Creates one for children and all four observations sections.
    assert_equal(5, Query.count)

    reget(:show_name, :id => 2)
    assert_response('show_name')
    # Should re-use all the old queries.
    assert_equal(5, Query.count)

    reget(:show_name, :id => 3)
    assert_response('show_name')
    # Needs new queries this time.
    assert_equal(10, Query.count)
  end

  def test_show_past_name
    get_with_dump(:show_past_name, :id => 2)
    assert_response('show_past_name')
  end

  def test_next_and_prev
    names = Name.all(:order => 'text_name, author')
    name12 = names[12]
    name13 = names[13]
    name14 = names[14]
    get(:next_name, :id => name12.id)
    q = @controller.query_params(Query.last)
    assert_response(:action => 'show_name', :id => name13.id, :params => q)
    get(:next_name, :id => name13.id)
    assert_response(:action => 'show_name', :id => name14.id, :params => q)
    get(:prev_name, :id => name14.id)
    assert_response(:action => 'show_name', :id => name13.id, :params => q)
    get(:prev_name, :id => name13.id)
    assert_response(:action => 'show_name', :id => name12.id, :params => q)
  end

  def test_next_and_prev_2
    query = Query.lookup_and_save(:Name, :pattern, :pattern => 'lactarius')
    q = @controller.query_params(query)

    name1 = names(:lactarius_alpigenes)
    name2 = names(:lactarius_alpinus)
    name3 = names(:lactarius_kuehneri)
    name4 = names(:lactarius_subalpinus)

    get(:next_name, q.merge(:id => name1.id))
    assert_response(:action => 'show_name', :id => name2.id, :params => q)
    get(:next_name, q.merge(:id => name2.id))
    assert_response(:action => 'show_name', :id => name3.id, :params => q)
    get(:next_name, q.merge(:id => name3.id))
    assert_response(:action => 'show_name', :id => name4.id, :params => q)
    get(:next_name, q.merge(:id => name4.id))
    assert_response(:action => 'show_name', :id => name4.id, :params => q)
    assert_flash(/no more/i)

    get(:prev_name, q.merge(:id => name4.id))
    assert_response(:action => 'show_name', :id => name3.id, :params => q)
    get(:prev_name, q.merge(:id => name3.id))
    assert_response(:action => 'show_name', :id => name2.id, :params => q)
    get(:prev_name, q.merge(:id => name2.id))
    assert_response(:action => 'show_name', :id => name1.id, :params => q)
    get(:prev_name, q.merge(:id => name1.id))
    assert_response(:action => 'show_name', :id => name1.id, :params => q)
    assert_flash(/no more/i)
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
    assert_equal(:query_title_pattern.t(:types => 'Names', :pattern => '56'),
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

  def test_show_name_description
    desc = name_descriptions(:peltigera_desc)
    params = { "id" => desc.id.to_s }
    get_with_dump(:show_name_description, params)
    assert_response('show_name_description')
  end

  def test_create_name_description
    name = names(:peltigera)
    params = { "id" => name.id.to_s }
    requires_login(:create_name_description, params)
    assert_form_action(:action => 'create_name_description', :id => name.id)
  end

  def test_edit_name_description
    desc = name_descriptions(:peltigera_desc)
    params = { "id" => desc.id.to_s }
    requires_login(:edit_name_description, params)
    assert_form_action(:action => 'edit_name_description', :id => desc.id)
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

  # None of our standard tests ever actually renders pagination_links
  # or pagination_letters.  This tests all the above.
  def test_pagination

    # Straightforward index of all names, showing first 10.
    query = Query.lookup_and_save(:Name, :all, :by => :name)
    query_params = @controller.query_params(query)
    get(:test_index, { :num_per_page => 10 }.merge(query_params))
    assert_response('list_names')
    name_links = extract_links(:action => 'show_name')
    assert_equal(10, name_links.length)
    expected = Name.all(:order => 'text_name, author', :limit => 10)
    assert_equal(expected.map(&:id), name_links.map(&:id))
    assert_equal(@controller.url_for(:action => 'show_name',
                 :id => expected.first.id, :params => query_params,
                 :only_path => true), name_links.first.url)
    assert_no_link_in_html(1)
    assert_link_in_html(2, :action => :test_index, :num_per_page => 10,
                        :params => query_params, :page => 2)
    assert_no_link_in_html('Z')
    assert_link_in_html('A', :action => :test_index, :num_per_page => 10,
                        :params => query_params, :letter => 'A')

    # Now go to the second page.
    reget(:test_index, { :num_per_page => 10, :page => 2 }.merge(query_params))
    assert_response('list_names')
    name_links = extract_links(:action => 'show_name')
    assert_equal(10, name_links.length)
    expected = Name.all(:order => 'text_name, author', :limit => 10,
                        :offset => 10)
    assert_equal(expected.map(&:id), name_links.map(&:id))
    assert_equal(@controller.url_for(:action => 'show_name',
                 :id => expected.first.id, :params => query_params,
                 :only_path => true), name_links.first.url)
    assert_no_link_in_html(2)
    assert_link_in_html(1, :action => :test_index, :num_per_page => 10,
                        :params => query_params, :page => 1)
    assert_no_link_in_html('Z')
    assert_link_in_html('A', :action => :test_index, :num_per_page => 10,
                        :params => query_params, :letter => 'A')

    # Now try a letter.
    l_names = Name.all(:conditions => 'text_name LIKE "L%"',
                       :order => 'text_name, author')
    reget(:test_index, { :num_per_page => l_names.size,
               :letter => 'L' }.merge(query_params))
    assert_response('list_names')
    name_links = extract_links(:action => 'show_name')
    assert_equal(l_names.size, name_links.length)
    assert_equal(l_names.map(&:id), name_links.map(&:id))
    assert_equal(@controller.url_for(:action => 'show_name',
                 :id => l_names.first.id, :params => query_params,
                 :only_path => true), name_links.first.url)
    assert_no_link_in_html(1)
    assert_no_link_in_html('Z')
    assert_link_in_html('A', :action => :test_index,:params => query_params,
                        :num_per_page => l_names.size, :letter => 'A')

    # Do it again, but make page size exactly one too small.
    last_name = l_names.pop
    reget(:test_index, { :num_per_page => l_names.size,
        :letter => 'L' }.merge(query_params))
    assert_response('list_names')
    name_links = extract_links(:action => 'show_name')
    assert_equal(l_names.size, name_links.length)
    assert_equal(l_names.map(&:id), name_links.map(&:id))
    assert_no_link_in_html(1)
    assert_link_in_html(2, :action => :test_index, :params => query_params,
                        :num_per_page => l_names.size,
                        :letter => 'L', :page => 2)
    assert_no_link_in_html(3)

    # Check second page.
    reget(:test_index, { :num_per_page => l_names.size, :letter => 'L',
        :page => 2 }.merge(query_params))
    assert_response('list_names')
    name_links = extract_links(:action => 'show_name')
    assert_equal(1, name_links.length)
    assert_equal([last_name.id], name_links.map(&:id))
    assert_no_link_in_html(2)
    assert_link_in_html(1, :action => :test_index, :params => query_params,
                        :num_per_page => l_names.size,
                        :letter => 'L', :page => 1)
    assert_no_link_in_html(3)

    # Some cleverness is required to get pagination links to include anchors.
    reget(:test_index, { :num_per_page => 10,
                        :test_anchor => 'blah' }.merge(query_params))
    assert_link_in_html(2, :action => :test_index, :num_per_page => 10,
                        :params => query_params, :page => 2,
                        :test_anchor => 'blah', :anchor => 'blah')
    assert_link_in_html('A', :action => :test_index, :num_per_page => 10,
                        :params => query_params, :letter => 'A',
                        :test_anchor => 'blah', :anchor => 'blah')
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
      },
    }
    post_requires_login(:create_name, params)
    assert_response(:action => :show_name, :id => Name.last.id)
    # Amanita baccata is in there but not Amanita sp., so this creates two names.
    assert_equal(10 + 2 * @name_pts, @rolf.reload.contribution)
    assert(name = Name.find_by_text_name(text_name))
    assert_equal(text_name, name.text_name)
    assert_equal(author, name.author)
    assert_equal(@rolf, name.user)
  end

  def test_create_name_existing
    name = names(:conocybe_filaris)
    text_name = name.text_name
    count = Name.count
    params = {
      :name => {
        :text_name => text_name,
        :author => '',
        :rank => :Species,
        :citation => ''
      },
    }
    login('rolf')
    post(:create_name, params)
    assert_response(:action => :show_name, :id => name.id)
    assert_equal(10, @rolf.reload.contribution)
    name = Name.find_by_text_name(text_name)
    assert_equal(names(:conocybe_filaris), name)
    assert_equal(count, Name.count)
  end

  def test_create_name_bad_name
    text_name = "Amanita Pantherina"
    name = Name.find_by_text_name(text_name)
    assert_nil(name)
    params = {
      :name => {
        :text_name => text_name,
        :rank => :Species
      },
    }
    login('rolf')
    post(:create_name, params)
    assert_response('create_name')
    # Should fail and no name should get created
    assert_nil(Name.find_by_text_name(text_name))
    assert_form_action(:action => 'create_name')
  end

  def test_create_name_alt_rank
    text_name = "Ustilaginomycetes"
    name = Name.find_by_text_name(text_name)
    assert_nil(name)
    params = {
      :name => {
        :text_name => text_name,
        :rank => :Phylum,
      },
    }
    login('rolf')
    post(:create_name, params)
    assert_response(:action => :show_name)
    assert(name = Name.find_by_text_name(text_name))
  end

  def test_create_name_with_many_implicit_creates
    text_name = "Genus species ssp. subspecies v. variety forma form"
    text_name2 = "Genus species subsp. subspecies var. variety f. form"
    name = Name.find_by_text_name(text_name)
    count = Name.count
    assert_nil(name)
    params = {
      :name => {
        :text_name => text_name,
        :rank => :Form,
      },
    }
    login('rolf')
    post(:create_name, params)
    assert_response(:action => :show_name)
    assert(name = Name.find_by_text_name(text_name2))
    assert(count + 5, Name.count)
  end

  # ----------------------------
  #  Edit name.
  # ----------------------------

  def test_edit_name_post
    name = names(:conocybe_filaris)
    assert_equal("Conocybe filaris", name.text_name)
    assert_nil(name.author)
    past_names = name.versions.size
    assert_equal(1, name.version)
    params = {
      :id => name.id,
      :name => {
        :text_name => name.text_name,
        :author => "(Fr.) Kühner",
        :rank => :Species,
        :citation => "__Le Genera Galera__, 139. 1935."
      },
    }
    post_requires_login(:edit_name, params)
    # Must be creating Conocybe sp, too.
    assert_equal(10 + 2 * @name_pts, @rolf.reload.contribution)
    assert_equal("(Fr.) Kühner", name.reload.author)
    assert_equal("**__Conocybe filaris__** (Fr.) Kühner", name.display_name)
    assert_equal("**__Conocybe filaris__** (Fr.) Kühner", name.observation_name)
    assert_equal("Conocybe filaris (Fr.) Kühner", name.search_name)
    assert_equal("__Le Genera Galera__, 139. 1935.", name.citation)
    assert_equal(@rolf, name.user)
  end

  # Test name changes in various ways.
  def test_edit_name_deprecated
    name = names(:lactarius_alpigenes)
    assert(name.deprecated)
    params = {
      :id => name.id,
      :name => {
        :text_name => name.text_name,
        :author => '',
        :rank => :Species,
        :citation => ''
      },
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    # (creates Lactarius since it's not in the fixtures, AND it changes L. alpigenes)
    assert_equal(10 + 2 * @name_pts, @rolf.reload.contribution)
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
      },
    }
    login('rolf')
    post(:edit_name, params)
    # Hmmm, this isn't catching the fact that Rolf shouldn't be allowed to
    # change the name, instead it seems to be doing nothing simply because he's
    # not actually changing anything!
    assert_response(:action => :show_name)
    # (In fact, it is implicitly creating Macrolepiota.)
    assert_equal(10 + @name_pts, @rolf.reload.contribution)
    # (But owner remains.)
    assert_equal(name_owner, name.reload.user)
  end

  def test_edit_name_destructive_merge
    old_name = agaricus_campestrus = names(:agaricus_campestrus)
    new_name  = agaricus_campestris = names(:agaricus_campestris)
    assert_not_equal(old_name, new_name)
    new_versions = new_name.versions.size
    assert_equal(1, new_name.version)
    assert_equal(1, old_name.namings.size)
    old_obs = old_name.namings[0].observation
    assert_equal(2, new_name.namings.size)
    new_obs = new_name.namings[0].observation
    params = {
      :id => old_name.id,
      :name => {
        :text_name => agaricus_campestris.text_name,
        :author => '',
        :rank => :Species
      },
    }

    # Fails because Rolf isn't in admin mode.
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_flash(/admin/)
    assert(Name.find(old_name.id))
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(2, new_name.namings.size)
    assert_equal(agaricus_campestrus, old_obs.reload.name)
    assert_equal(agaricus_campestris, new_obs.reload.name)

    # Try again as an admin.
    make_admin
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      old_name = Name.find(old_name.id)
    end
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(3, new_name.namings.size)
    assert_equal(agaricus_campestris, old_obs.reload.name)
    assert_equal(agaricus_campestris, new_obs.reload.name)
  end

  def test_edit_name_author_merge
    old_name = names(:amanita_baccata_borealis)
    new_name  = names(:amanita_baccata_arora)
    assert_not_equal(old_name, new_name)
    assert_equal(old_name.text_name, new_name.text_name)
    new_author = new_name.author
    assert_not_equal(old_name.author, new_author)
    new_versions = new_name.versions.size
    assert_equal(1, new_name.version)
    params = {
      :id => old_name.id,
      :name => {
        :text_name => old_name.text_name,
        :author => new_name.author,
        :rank => :Species
      },
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      old_name = Name.find(old_name.id)
    end
    assert(new_name.reload)
    assert_equal(new_author, new_name.author)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
  end

  # Make sure misspelling gets transferred when new name merges away.
  def test_edit_name_misspelling_merge
    old_name = names(:suilus)
    wrong_author_name = names(:suillus_by_white)
    new_name = names(:suillus)
    assert_equal(old_name.correct_spelling, wrong_author_name)
    old_correct_spelling_id = old_name.correct_spelling_id
    new_author = new_name.author
    assert_not_equal(wrong_author_name.author, new_author)
    params = {
      :id => wrong_author_name.id,
      :name => {
        :text_name => wrong_author_name.text_name,
        :author => new_name.author,
        :rank => new_name.rank
      },
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      wrong_author_name = Name.find(wrong_author_name.id)
    end
    assert_not_equal(old_correct_spelling_id, old_name.reload.correct_spelling_id)
    assert_equal(old_name.correct_spelling, new_name)
  end

  # Test that merged names end up as not deprecated if the
  # new name is not deprecated.
  def test_edit_name_deprecated_merge
    old_name = names(:lactarius_alpigenes)
    assert(old_name.deprecated)
    new_name = names(:lactarius_alpinus)
    assert(!new_name.deprecated)
    assert_not_equal(old_name, new_name)
    assert_not_equal(old_name.text_name, new_name.text_name)
    new_author = new_name.author
    assert_not_equal(old_name.author, new_author)
    new_versions = new_name.versions.size
    assert_equal(1, new_name.version)
    params = {
      :id => old_name.id,
      :name => {
        :text_name => new_name.text_name,
        :author => new_name.author,
        :rank => :Species
      },
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      old_name = Name.find(old_name.id)
    end
    assert(new_name.reload)
    assert(!new_name.deprecated)
    assert_equal(new_author, new_name.author)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
  end

  # Test that merged names end up as not deprecated even if the
  # new name is deprecated but the old name is not deprecated
  def test_edit_name_deprecated2_merge
    old_name = names(:lactarius_alpinus)
    assert(!old_name.deprecated)
    new_name = names(:lactarius_alpigenes)
    assert(new_name.deprecated)
    assert_not_equal(old_name, new_name)
    assert_not_equal(old_name.text_name, new_name.text_name)
    new_author = new_name.author
    new_text_name = new_name.text_name
    assert_not_equal(old_name.author, new_author)
    new_versions = new_name.versions.size
    assert_equal(1, new_name.version)
    params = {
      :id => old_name.id,
      :name => {
        :text_name => new_name.text_name,
        :author => new_name.author,
        :rank => :Species
      },
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert_raises(ActiveRecord::RecordNotFound) do
      old_name = Name.find(old_name.id)
    end
    assert(new_name.reload)
    assert(!new_name.deprecated)
    assert_equal(new_author, new_name.author)
    assert_equal(new_text_name, new_name.text_name)
    assert_equal(2, new_name.version)
    assert_equal(new_versions+1, new_name.versions.size)
  end

  # Test merge two names where the new name has notes.
  def test_edit_name_merge_matching_notes
    old_name = names(:russula_brevipes_no_author)
    new_name = names(:russula_brevipes_author_notes)
    assert_not_equal(old_name, new_name)
    assert_equal(old_name.text_name, new_name.text_name)
    assert_nil(old_name.author)
    assert_nil(old_name.description)
    assert_not_nil(new_name.author)
    notes = new_name.description.notes
    assert_not_nil(new_name.description)
    params = {
      :id => old_name.id,
      :name => {
        :text_name => old_name.text_name,
        :author => old_name.author,
        :rank => old_name.rank,
        :citation => '',
      },
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert(new_name.reload)
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(old_name.id)
    end
    assert_equal(notes, new_name.description.notes)
  end

  # Test merge two names where the old name had notes.
  def test_edit_name_merge_matching_notes_2
    old_name = names(:russula_brevipes_author_notes)
    new_name = names(:russula_brevipes_no_author)
    assert_not_equal(old_name, new_name)
    assert_equal(old_name.text_name, new_name.text_name)
    assert_not_nil(old_name.author)
    assert_not_nil(old_name.description)
    notes = old_name.description.notes
    assert_nil(new_name.author)
    assert_nil(new_name.description)
    params = {
      :id => old_name.id,
      :name => {
        :text_name => old_name.text_name,
        :author => '',
        :rank => old_name.rank,
        :citation => '',
      },
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert(new_name.reload)
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(old_name.id)
    end
    assert_equal(notes, new_name.description.notes)
  end

  # Test merging two names, only one with observations.  Should work either
  # direction, but always keeping the name with observations.
  def test_edit_name_merge_one_with_observations
    old_name = names(:conocybe_filaris) # no observations
    new_name = names(:coprinus_comatus) # has observations
    assert_not_equal(old_name, new_name)
    params = {
      :id => old_name.id,
      :name => {
        :text_name => new_name.text_name,
        :author => new_name.author,
        :rank => old_name.rank,
        :citation => '',
      },
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name, :id => new_name.id)
    assert(new_name.reload)
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(old_name.id)
    end
  end

  def test_edit_name_merge_one_with_observations_other_direction
    old_name = names(:coprinus_comatus) # has observations
    new_name = names(:conocybe_filaris) # no observations
    assert_not_equal(old_name, new_name)
    params = {
      :id => old_name.id,
      :name => {
        :text_name => new_name.text_name,
        :author => new_name.author,
        :rank => old_name.rank,
        :citation => '',
      },
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name, :id => old_name.id)
    assert(old_name.reload)
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(new_name.id)
    end
  end

  # Test merge two names that both start with notes.
  def test_edit_name_merge_both_notes
    old_name = names(:russula_cremoricolor_no_author_notes)
    new_name = names(:russula_cremoricolor_author_notes)
    assert_not_equal(old_name, new_name)
    assert_equal(old_name.text_name, new_name.text_name)
    assert_nil(old_name.author)
    assert_not_nil(new_name.author)
    assert_not_nil(old_notes = old_name.description.notes)
    assert_not_nil(new_notes = new_name.description.notes)
    assert_not_equal(old_notes, new_notes)
    params = {
      :id => old_name.id,
      :name => {
        :text_name => old_name.text_name,
        :citation => '',
        :author => old_name.author,
        :rank => old_name.rank
      },
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    assert(new_name.reload)
    assert_raises(ActiveRecord::RecordNotFound) do
      Name.find(old_name.id)
    end
    assert_equal(new_notes, new_name.description.notes)
    # Make sure old notes are still around.
    other_desc = (new_name.descriptions - [new_name.description]).first
    assert_equal(old_notes, other_desc.notes)
  end

  def test_edit_name_both_with_notes_and_namings
    old_name = names(:agaricus_campestros)
    new_name = names(:agaricus_campestras)
    assert_not_equal(old_name, new_name)
    assert_not_equal(old_name.text_name, new_name.text_name)
    assert_equal(old_name.author, new_name.author)
    assert_equal(1, new_name.version)
    assert_equal(1, old_name.namings.size)
    assert_equal(1, new_name.namings.size)
    new_versions = new_name.versions.size
    old_obs = old_name.namings[0].observation
    new_obs = new_name.namings[0].observation
    params = {
      :id => old_name.id,
      :name => {
        :text_name => new_name.text_name,
        :author => old_name.author,
        :rank => old_name.rank
      },
    }

    # Fails normally.
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => 'show_name', :id => old_name.id)
    assert(old_name.reload)
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(1, new_name.namings.size)
    assert_equal(1, old_name.namings.size)
    assert_not_equal(new_name.namings[0], old_name.namings[0])

    # Try again in admin mode.
    make_admin
    post(:edit_name, params)
    assert_response(:action => 'show_name', :id => new_name.id)
    assert_raises(ActiveRecord::RecordNotFound) do
      assert(old_name.reload)
    end
    assert(new_name.reload)
    assert_equal(1, new_name.version)
    assert_equal(new_versions, new_name.versions.size)
    assert_equal(2, new_name.namings.size)
  end

  def test_edit_name_add_author
    name = names(:strobilurus_diminutivus_no_author)
    old_text_name = name.text_name
    new_author = 'Desjardin'
    assert(name.namings.length > 0)
    params = {
      :id => name.id,
      :name => {
        :text_name => old_text_name,
        :author => new_author,
        :rank => :Species
      },
      :description => empty_notes
    }
    login('rolf')
    post(:edit_name, params)
    assert_response(:action => :show_name)
    # It seems to be creating Strobilurus sp. as well?
    assert_equal(10 + @name_pts, @rolf.reload.contribution)
    assert_equal(new_author, name.reload.author)
    assert_equal(old_text_name, name.text_name)
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
      :synonym => { :members => '' },
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
      :synonym => { :members => '' },
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
      :synonym => { :members => '' },
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

    new_name = names(:chlorophyllum_rachodes)
    assert(!new_name.deprecated)
    assert_not_nil(new_name.synonym)
    new_synonym_length = new_name.synonym.names.size
    new_past_name_count = new_name.versions.length
    new_version = new_name.version

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

    assert(!new_name.reload.deprecated)
    assert_equal(new_past_name_count, new_name.versions.length)
    assert_not_nil(new_synonym = new_name.synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(new_synonym_length+1, new_synonym.names.size)
    assert_equal(new_version, new_name.version)
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
      :comment => { :comment => ''}
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
      :comment => { :comment => ''}
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
    count_before = Notification.count
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert_nil(notification)
    params = {
      :id => name.id,
      :commit => :ENABLE.t,
      :notification => {
        :note_template => ''
      }
    }
    post_requires_login(:email_tracking, params)
    # This is needed before the next find for some reason
    count_after = Notification.count
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
    count_before = Notification.count
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert_nil(notification)
    params = {
      :id => name.id,
      :commit => :ENABLE.t,
      :notification => {
        :note_template => 'A note about :observation from :observer'
      }
    }
    login('rolf')
    post(:email_tracking, params)
    assert_response(:action => :show_name)
    # This is needed before the next find for some reason
    count_after = Notification.count
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
    count_before = Notification.count
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
    count_after = Notification.count
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
    count_before = Notification.count
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert(notification)
    params = {
      :id => name.id,
      :commit => :DISABLE.t,
      :notification => {
        :note_template => 'A note about :observation from :observer'
      }
    }
    login('rolf')
    post(:email_tracking, params)
    assert_response(:action => :show_name)
    # This is needed before the next find for some reason
    # count_after = Notification.count
    # assert_equal(count_before - 1, count_after)
    notification = Notification.
                find_by_flavor_and_obj_id_and_user_id(:name, name.id, @rolf.id)
    assert_nil(notification)
  end

  # ----------------------------
  #  Review status.
  # ----------------------------

  def test_set_review_status_reviewer
    desc = name_descriptions(:coprinus_comatus_desc)
    assert_equal(:unreviewed, desc.review_status)
    assert(@rolf.in_group?('reviewers'))
    params = {
      :id => desc.id,
      :value => 'vetted'
    }
    post_requires_login(:set_review_status, params)
    assert_response(:action => :show_name)
    assert_equal(:vetted, desc.reload.review_status)
  end

  def test_set_review_status_non_reviewer
    desc = name_descriptions(:coprinus_comatus_desc)
    assert_equal(:unreviewed, desc.review_status)
    assert(!@mary.in_group?('reviewers'))
    params = {
      :id => desc.id,
      :value => 'vetted'
    }
    post_requires_login(:set_review_status, params, 'mary')
    assert_response(:action => :show_name)
    assert_equal(:unreviewed, desc.reload.review_status)
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
    assert_link_in_html('<img[^>]+watch\d*.png[^>]+>',
      :controller => 'interest', :action => 'set_interest',
      :type => 'Name', :id => peltigera.id, :state => 1
    )
    assert_link_in_html('<img[^>]+ignore\d*.png[^>]+>',
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

  # ----------------------------
  #  Test project drafts.
  # ----------------------------

  # Ensure that draft owner can see a draft they own
  def test_show_draft
    draft = name_descriptions(:draft_coprinus_comatus)
    login(draft.user.login)
    get_with_dump(:show_name_description, { :id => draft.id })
    assert_response('show_name_description')
  end

  # Ensure that an admin can see a draft they don't own
  def test_show_draft_admin
    draft = name_descriptions(:draft_coprinus_comatus)
    assert_not_equal(draft.user, @mary)
    login(@mary.login)
    get_with_dump(:show_name_description, { :id => draft.id })
    assert_response('show_name_description')
  end

  # Ensure that an member can see a draft they don't own
  def test_show_draft_member
    draft = name_descriptions(:draft_agaricus_campestris)
    assert_not_equal(draft.user, @katrina)
    login(@katrina.login)
    get_with_dump(:show_name_description, { :id => draft.id })
    assert_response('show_name_description')
  end

  # Ensure that a non-member cannot see a draft
  def test_show_draft_non_member
    project = projects(:eol_project)
    draft = name_descriptions(:draft_agaricus_campestris)
    assert(draft.belongs_to_project?(project))
    assert(!project.is_member?(@dick))
    login(@dick.login)
    get_with_dump(:show_name_description, { :id => draft.id })
    assert_response(:controller => 'project', :action => 'show_project',
                    :id => project.id)
  end

  def test_create_draft_member
    create_draft_tester(projects(:eol_project), names(:coprinus_comatus), @katrina)
  end

  def test_create_draft_admin
    create_draft_tester(projects(:eol_project), names(:coprinus_comatus), @mary)
  end

  def test_create_draft_not_member
    create_draft_tester(projects(:eol_project), names(:agaricus_campestris), @dick, false)
  end

  def test_edit_draft
    edit_draft_tester(name_descriptions(:draft_coprinus_comatus))
  end

  def test_edit_draft_admin
    assert(projects(:eol_project).is_admin?(@mary))
    assert_equal('EOL Project', name_descriptions(:draft_coprinus_comatus).source_name)
    edit_draft_tester(name_descriptions(:draft_coprinus_comatus), @mary)
  end

  def test_edit_draft_member
    assert(projects(:eol_project).is_member?(@katrina))
    assert_equal('EOL Project', name_descriptions(:draft_coprinus_comatus).source_name)
    edit_draft_tester(name_descriptions(:draft_agaricus_campestris), @katrina, false)
  end

  def test_edit_draft_non_member
    assert(!projects(:eol_project).is_member?(@dick))
    assert_equal('EOL Project', name_descriptions(:draft_coprinus_comatus).source_name)
    edit_draft_tester(name_descriptions(:draft_agaricus_campestris), @dick, false, false)
  end

  def test_edit_draft_post_owner
    edit_draft_post_helper(name_descriptions(:draft_coprinus_comatus), @rolf, {})
  end

  def test_edit_draft_post_admin
    edit_draft_post_helper(name_descriptions(:draft_coprinus_comatus), @mary, {})
  end

  def test_edit_draft_post_member
    edit_draft_post_helper(name_descriptions(:draft_agaricus_campestris), @katrina, {}, false)
  end

  def test_edit_draft_post_non_member
    edit_draft_post_helper(name_descriptions(:draft_agaricus_campestris), @dick, {}, false)
  end

  def test_edit_draft_post_bad_classification
    edit_draft_post_helper(name_descriptions(:draft_coprinus_comatus), @rolf,
      { :classification => "**Domain**: Eukarya" }, true, false)
  end

#   def test_publish_draft
#     publish_draft_helper(name_descriptions(:draft_coprinus_comatus))
#   end
# 
#   def test_publish_draft_admin
#     publish_draft_helper(name_descriptions(:draft_coprinus_comatus), @mary)
#   end
# 
#   def test_publish_draft_member
#     publish_draft_helper(name_descriptions(:draft_agaricus_campestris), @katrina, false)
#   end
# 
#   def test_publish_draft_non_member
#     publish_draft_helper(name_descriptions(:draft_agaricus_campestris), @dick, false)
#   end
# 
#   def test_publish_draft_bad_classification
#     publish_draft_helper(name_descriptions(:draft_lactarius_alpinus), nil, false, 'edit_draft')
#   end

  def test_destroy_draft_owner
    destroy_draft_helper(name_descriptions(:draft_coprinus_comatus), @rolf)
  end

  def test_destroy_draft_admin
    destroy_draft_helper(name_descriptions(:draft_coprinus_comatus), @mary)
  end

  def test_destroy_draft_member
    destroy_draft_helper(name_descriptions(:draft_agaricus_campestris), @katrina, false)
  end

  def test_destroy_draft_non_member
    destroy_draft_helper(name_descriptions(:draft_agaricus_campestris), @dick, false)
  end
end
