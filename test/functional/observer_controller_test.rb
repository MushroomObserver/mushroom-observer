# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

class ObserverControllerTest < FunctionalTestCase

  # Test constructing observations in various ways (with minimal namings).
  def generic_construct_observation(params, o_num, g_num, n_num, user = @rolf)
    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    score   = user.reload.contribution

    params[:observation] = {
      :place_name     => 'Right Here, Massachusetts, USA',
      :lat            => '',
      :long           => '',
      :alt            => '',
      'when(1i)'      => '2007',
      'when(2i)'      => '10',
      'when(3i)'      => '31',
      :specimen       => '0',
      :thumb_image_id => '0',
    }.merge(params[:observation] || {})
    params[:vote] = {
      :value => '3',
    }.merge(params[:vote] || {})
    params[:username] = user.login

    post_requires_login(:create_observation, params)
    # either_requires_either(:post, :create_observation, nil, params, :username => user.login)
    if o_num == 0
      assert_response(:success)
    elsif Location.find_by_name(params[:observation][:place_name]) or
          Location.is_unknown?(params[:observation][:place_name]) or
          params[:observation][:place_name].blank?
      assert_response(:action => :show_observation)
    else
      assert_response(:action => :create_location)
    end

    assert_equal(o_count + o_num, Observation.count)
    assert_equal(g_count + g_num, Naming.count)
    assert_equal(n_count + n_num, Name.count)
    assert_equal(score + o_num + 2*g_num + 10*n_num, user.reload.contribution)
    if o_num == 1
      assert_not_equal(0, @controller.instance_variable_get('@observation').thumb_image_id)
    end
  end

################################################################################

  # ----------------------------
  #  General tests.
  # ----------------------------

  def test_page_loads

    get_with_dump(:index)
    assert_response('list_rss_logs')
    assert_link_in_html(:app_intro.t, :action => 'intro')
    assert_link_in_html(:app_create_account.t, :controller => 'account',
                        :action => 'signup')

    get_with_dump(:ask_webmaster_question)
    assert_response('ask_webmaster_question')
    assert_form_action(:action => 'ask_webmaster_question')

    get_with_dump(:color_themes)
    assert_response('color_themes')
    for theme in CSS
      get_with_dump(theme)
      assert_response(theme)
    end

    get_with_dump(:how_to_help)
    assert_response('how_to_help')

    get_with_dump(:how_to_use)
    assert_response('how_to_use')

    get_with_dump(:intro)
    assert_response('intro')

    get_with_dump(:list_observations)
    assert_response('list_observations')

    # Test again, this time specifying page number via an observation id.
    get(:list_observations, :id => 4)
    assert_response('list_observations')

    get_with_dump(:list_rss_logs)
    assert_response('list_rss_logs')

    get_with_dump(:news)
    assert_response('news')

    get_with_dump(:observations_by_name)
    assert_response('list_observations')

    get_with_dump(:rss)
    assert_response('rss')

    get_with_dump(:show_rss_log, :id => 1)
    assert_response('show_rss_log')

    get_with_dump(:users_by_contribution)
    assert_response('users_by_contribution')

    get_with_dump(:show_user, :id => 1)
    assert_response('show_user')

    get_with_dump(:show_site_stats)
    assert_response('show_site_stats')

    get_with_dump(:observations_by_user, :id => 1)
    assert_response('list_observations')

    get_with_dump(:login)
    assert_response(:controller => "account", :action => "login")

    get_with_dump(:textile)
    assert_response('textile_sandbox')

    get_with_dump(:textile_sandbox)
    assert_response('textile_sandbox')
  end

  def test_altering_types_shown_by_rss_log_index
    # Show none.
    post(:index_rss_log)
    assert_response('list_rss_logs')

    # Show one.
    post(:index_rss_log, :show_observations => '1')
    assert_response('list_rss_logs')

    # Show all.
    params = {}
    for type in RssLog.all_types
      params["show_#{type}"] = '1'
    end
    post(:index_rss_log, params)
    assert_response('list_rss_logs')
  end

  def test_prev_and_next_observation
    # Uses default observation query
    get(:next_observation, :id => 4)
    assert_response(:action => "show_observation", :id => 3,
                    :params => @controller.query_params(Query.last))

    get(:prev_observation, :id => 4)
    assert_response(:action => "show_observation", :id => 5,
                    :params => @controller.query_params(Query.last))
  end

  def test_prev_and_next_observation_with_fancy_query
    n1 = names(:agaricus_campestras)
    n2 = names(:agaricus_campestris)
    n3 = names(:agaricus_campestros)
    n4 = names(:agaricus_campestrus)

    n2.transfer_synonym(n1)
    n2.transfer_synonym(n3)
    n2.transfer_synonym(n4)
    n1.correct_spelling = n2
    n1.save_without_our_callbacks

    o1 = n1.observations.first
    o2 = n2.observations.first
    o3 = n3.observations.first
    o4 = n4.observations.first

    # When requesting non-synonym observations of n2, it should include n1,
    # since an observation of n1 was clearly intended to be an observation of
    # n2.
    query = Query.lookup_and_save(:Observation, :of_name, :synonyms => :no,
                                  :name => n2, :by => :name)
    assert_equal(2, query.num_results)

    # Likewise, when requesting *synonym* observations, neither n1 nor n2
    # should be included.
    query = Query.lookup_and_save(:Observation, :of_name, :synonyms => :exclusive,
                                  :name => n2, :by => :name)
    assert_equal(2, query.num_results)

    # But for our prev/next test, lets do the all-inclusive query.
    query = Query.lookup_and_save(:Observation, :of_name, :synonyms => :all,
                                  :name => n2, :by => :name)
    assert_equal(4, query.num_results)
    qp = @controller.query_params(query)

    get(:next_observation, qp.merge(:id => 1))
    assert_response(:action => 'show_observation', :id => 1, :params => qp)
    assert_flash(/can.*t find.*results.*index/i)
    get(:next_observation, qp.merge(:id => o1.id))
    assert_response(:action => 'show_observation', :id => o2.id, :params => qp)
    get(:next_observation, qp.merge(:id => o2.id))
    assert_response(:action => 'show_observation', :id => o3.id, :params => qp)
    get(:next_observation, qp.merge(:id => o3.id))
    assert_response(:action => 'show_observation', :id => o4.id, :params => qp)
    get(:next_observation, qp.merge(:id => o4.id))
    assert_response(:action => 'show_observation', :id => o4.id, :params => qp)
    assert_flash(/no more/i)

    get(:prev_observation, qp.merge(:id => o4.id))
    assert_response(:action => 'show_observation', :id => o3.id, :params => qp)
    get(:prev_observation, qp.merge(:id => o3.id))
    assert_response(:action => 'show_observation', :id => o2.id, :params => qp)
    get(:prev_observation, qp.merge(:id => o2.id))
    assert_response(:action => 'show_observation', :id => o1.id, :params => qp)
    get(:prev_observation, qp.merge(:id => o1.id))
    assert_response(:action => 'show_observation', :id => o1.id, :params => qp)
    assert_flash(/no more/i)
    get(:prev_observation, qp.merge(:id => 1))
    assert_response(:action => 'show_observation', :id => 1, :params => qp)
    assert_flash(/can.*t find.*results.*index/i)
  end

  def test_advanced_search_form
    for model in [ Name, Image, Observation ]
      post('advanced_search_form',
        :search => {
          :name => "Don't know",
          :user => "myself",
          :type => model.name.underscore,
          :content => "Long pink stem and small pink cap",
          :location => "Eastern Oklahoma"
        },
        :commit => "Search"
      )
      assert_response(:controller => model.show_controller,
                      :action => 'advanced_search')
    end
  end

  def test_advanced_search
    query = Query.lookup_and_save(:Observation, :advanced_search,
      :name => "Don't know",
      :user => "myself",
      :content => "Long pink stem and small pink cap",
      :location => "Eastern Oklahoma"
    )
    get(:advanced_search, @controller.query_params(query))
    assert_response('list_observations')
  end

  def test_pattern_search
    params = {:search => {:pattern => '12', :type => 'observation'}}
    get_with_dump(:pattern_search, params)
    assert_response(:controller => 'observer', :action => 'observation_search',
                    :pattern => '12')

    params = {:search => {:pattern => '34', :type => 'image'}}
    get_with_dump(:pattern_search, params)
    assert_response(:controller => 'image', :action => 'image_search',
                    :pattern => '34')

    params = {:search => {:pattern => '56', :type => 'name'}}
    get_with_dump(:pattern_search, params)
    assert_response(:controller => 'name', :action => 'name_search',
                    :pattern => '56')

    params = {:search => {:pattern => '78', :type => 'location'}}
    get_with_dump(:pattern_search, params)
    assert_response(:controller => 'location', :action => 'location_search',
                    :pattern => '78')

    params = {:search => {:pattern => '90', :type => 'comment'}}
    get_with_dump(:pattern_search, params)
    assert_response(:controller => 'comment', :action => 'comment_search',
                    :pattern => '90')

    params = {:search => {:pattern => '12', :type => 'species_list'}}
    get_with_dump(:pattern_search, params)
    assert_response(:controller => 'species_list', :action => 'species_list_search',
                    :pattern => '12')

    params = {:search => {:pattern => '34', :type => 'user'}}
    get_with_dump(:pattern_search, params)
    assert_response(:controller => 'observer', :action => 'user_search',
                    :pattern => '34')
  end

  def test_observation_search
    get_with_dump(:observation_search, :pattern => '120')
    assert_response('list_observations')
    assert_equal(:query_title_pattern_search.t(:types => 'Observations', :pattern => '120'),
                 @controller.instance_variable_get('@title'))

    get_with_dump(:observation_search, :pattern => '120', :page => 2)
    assert_response('list_observations')
    assert_equal(:query_title_pattern_search.t(:types => 'Observations', :pattern => '120'),
                 @controller.instance_variable_get('@title'))
  end

  # Created in response to a bug seen in the wild
  def test_where_search_next_page
    params = { :place_name => 'Burbank', :page => 2 }
    get_with_dump(:observations_at_where, params)
    assert_response('list_observations')
  end

  # Created in response to a bug seen in the wild
  def test_where_search_pattern
    params = { :place_name => "Burbank" }
    get_with_dump(:observations_at_where, params)
    assert_response('list_observations')
  end

  def test_send_webmaster_question
    params = {
      :user => { :email => "rolf@mushroomobserver.org" },
      :question => { :content => "Some content" },
    }
    post(:ask_webmaster_question, params)
    assert_response(:controller => "observer", :action => "list_rss_logs")

    params[:user][:email] = ''
    post(:ask_webmaster_question, params)
    assert_response(:success)
    assert_flash(:runtime_ask_webmaster_need_address.t)

    params[:user][:email] = 'spammer'
    post(:ask_webmaster_question, params)
    assert_response(:success)
    assert_flash(:runtime_ask_webmaster_need_address.t)

    params[:user][:email] = 'bogus@email.com'
    params[:question][:content] = ''
    post(:ask_webmaster_question, params)
    assert_response(:success)
    assert_flash(:runtime_ask_webmaster_need_content.t)

    params[:question][:content] = "Buy <a href='http://junk'>Me!</a>"
    post(:ask_webmaster_question, params)
    assert_response(:success)
    assert_flash(:runtime_ask_webmaster_antispam.t)
  end

  def test_show_observation
    assert_equal(0, Query.count)

    # Test it on obs with no namings first.
    obs_id = observations(:unknown_with_no_naming).id
    get_with_dump(:show_observation, :id => obs_id)
    assert_response('show_observation')
    assert_form_action(:action => 'show_observation', :id => obs_id)

    # Test it on obs with two namings (Rolf's and Mary's), but no one logged in.
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show_observation, :id => obs_id)
    assert_response('show_observation')
    assert_form_action(:action => 'show_observation', :id => obs_id)

    # Test it on obs with two namings, with owner logged in.
    login('rolf')
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show_observation, :id => obs_id)
    assert_response('show_observation')
    assert_form_action(:action => 'show_observation', :id => obs_id)

    # Test it on obs with two namings, with non-owner logged in.
    login('mary')
    obs_id = observations(:coprinus_comatus_obs).id
    get_with_dump(:show_observation, :id => obs_id)
    assert_response('show_observation')
    assert_form_action(:action => 'show_observation', :id => obs_id)

    # Test a naming owned by the observer but the observer has 'No Opinion'.
    # This is a regression test for a bug in _show_namings.rhtml
    # Ensure that rolf owns @obs_with_no_opinion.
    user = login('rolf')
    obs = observations(:strobilurus_diminutivus_obs)
    assert_equal(obs.user, user)
    get(:show_observation, :id => obs.id)
    assert_response('show_observation')

    # Make sure no queries created for show_image links.  (Well, okay, four
    # queries are created for Darvin's new "show species" and "show similar
    # observations" links...)
    assert_equal(4, Query.count)
  end

  def test_show_observation_edit_links
    obs = observations(:detailed_unknown)
    proj = projects(:bolete_project)
    assert_equal(@mary.id, obs.user_id)                        # owned by mary
    assert(obs.projects.include?(proj))                        # owned by bolete project
    assert_equal([@dick.id], proj.user_group.users.map(&:id))  # dick is only member of bolete project

    login('rolf')
    get(:show_observation, :id => obs.id)
    assert_select('a[href*=edit_observation]', :count => 0)
    assert_select('a[href*=destroy_observation]', :count => 0)
    assert_select('a[href*=add_image]', :count => 0)
    assert_select('a[href*=remove_image]', :count => 0)
    assert_select('a[href*=reuse_image]', :count => 0)
    get(:edit_observation, :id => obs.id)
    assert_response(:redirect)
    get(:destroy_observation, :id => obs.id)
    assert_flash_error

    login('mary')
    get(:show_observation, :id => obs.id)
    assert_select('a[href*=edit_observation]', :minimum => 1)
    assert_select('a[href*=destroy_observation]', :minimum => 1)
    assert_select('a[href*=add_image]', :minimum => 1)
    assert_select('a[href*=remove_image]', :minimum => 1)
    assert_select('a[href*=reuse_image]', :minimum => 1)
    get(:edit_observation, :id => obs.id)
    assert_response(:success)

    login('dick')
    get(:show_observation, :id => obs.id)
    assert_select('a[href*=edit_observation]', :minimum => 1)
    assert_select('a[href*=destroy_observation]', :minimum => 1)
    assert_select('a[href*=add_image]', :minimum => 1)
    assert_select('a[href*=remove_image]', :minimum => 1)
    assert_select('a[href*=reuse_image]', :minimum => 1)
    get(:edit_observation, :id => obs.id)
    assert_response(:success)
    get(:destroy_observation, :id => obs.id)
    assert_flash_success
  end

  def test_show_user_no_id
    get_with_dump(:show_user)
    assert_response(:action => 'index_user')
  end

  def test_ask_questions
    id = observations(:coprinus_comatus_obs).id
    requires_login(:ask_observation_question, :id => id)
    assert_form_action(:action => 'ask_observation_question', :id => id)

    id = @mary.id
    requires_login(:ask_user_question, :id => id)
    assert_form_action(:action => 'ask_user_question', :id => id)

    id = images(:in_situ).id
    requires_login(:commercial_inquiry, :id => id)
    assert_form_action(:action => 'commercial_inquiry', :id => id)
  end

  def test_destroy_observation
    assert(obs = observations(:minimal_unknown))
    id = obs.id
    params = { :id => id.to_s }
    assert_equal("mary", obs.user.login)
    requires_user(:destroy_observation, [:show_observation], params, 'mary')
    assert_response(:action => :list_observations)
    assert_raises(ActiveRecord::RecordNotFound) do
      obs = Observation.find(id)
    end
  end

  def test_some_admin_pages
    for (page, response, params) in [
      [ :users_by_name,  'users_by_name',  {} ],
      [ :email_features, 'email_features', {} ],
    ]
      logout
      get(page, params)
      assert_response(:controller => "account", :action => "login")

      login('rolf')
      get(page, params)
      assert_response(:action => "list_rss_logs")
      assert_flash(/denied|only.*admin/i)

      make_admin('rolf')
      get_with_dump(page, params)
      assert_response(response)
    end
  end

  def test_some_admin_pages
    page = :email_features
    params = {:feature_email => {:content => 'test'}}

    logout
    post(page, params)
    assert_response(:controller => "account", :action => "login")

    login('rolf')
    post(page, params)
    assert_response(:controller => "observer", :action => "list_rss_logs")
    assert_flash(/denied|only.*admin/i)

    make_admin('rolf')
    post_with_dump(page, params)
    assert_response(:controller => "observer", :action => :users_by_name)
  end

  def test_send_emails
    image = images(:commercial_inquiry_image)
    params = {
      :id => image.id,
      :commercial_inquiry => {
        :content => "Testing commercial_inquiry"
      }
    }
    post_requires_login(:commercial_inquiry, params)
    assert_response(:controller => :image, :action => :show_image)

    obs = observations(:minimal_unknown)
    params = {
      :id => obs.id,
      :question => {
        :content => "Testing question"
      }
    }
    post_requires_login(:ask_observation_question, params)
    assert_response(:action => :show_observation)
    assert_flash(:runtime_ask_observation_question_success.t)

    user = @mary
    params = {
      :id => user.id,
      :email => {
        :subject => "Email subject",
        :content => "Email content"
      }
    }
    post_requires_login(:ask_user_question, params)
    assert_response(:action => :show_user)
    assert_flash(:runtime_ask_user_question_success.t)
  end

  def test_show_notifications

    # First, create a naming notification email, making sure it has a template,
    # and making sure the person requesting the notifcation is not the same
    # person who created the underlying observation (otherwise nothing happens).
    note = notifications(:coprinus_comatus_notification)
    note.user = @mary
    note.note_template = 'blah!'
    assert(note.save)
    QueuedEmail.queue_emails(true)
    QueuedEmail::NameTracking.create_email(note, namings(:coprinus_comatus_other_naming))

    # Now we can be sure show_notifications is supposed to actually show a
    # non-empty list, and thus that this test is meaningful.
    requires_login(:show_notifications, :id => observations(:coprinus_comatus_obs))
    assert_response('show_notifications')
  end

  def test_author_request
    id = name_descriptions(:coprinus_comatus_desc).id
    requires_login(:author_request, :id => id, :type => 'name_description')
    assert_form_action(:action => 'author_request', :id => id,
                       :type => 'name_description')

    id = location_descriptions(:albion_desc).id
    requires_login(:author_request, :id => id, :type => 'location_description')
    assert_form_action(:action => 'author_request', :id => id,
                       :type => 'location_description')

    params = {
      :id => name_descriptions(:coprinus_comatus_desc).id,
      :type => 'name_description',
      :email => {
        :subject => "Author request subject",
        :message => "Message for authors"
      }
    }
    post_requires_login(:author_request, params)
    assert_response(:controller => 'name', :action => 'show_name_description',
                    :id => name_descriptions(:coprinus_comatus_desc).id)
    assert_flash(:request_success.t)

    params = {
      :id => location_descriptions(:albion_desc).id,
      :type => 'location_description',
      :email => {
        :subject => "Author request subject",
        :message => "Message for authors"
      }
    }
    post_requires_login(:author_request, params)
    assert_response(:controller => 'location', :action => 'show_location_description',
                    :id => location_descriptions(:albion_desc).id)
    assert_flash(:request_success.t)
  end

  def test_review_authors_locatios
    desc = location_descriptions(:albion_desc)
    params = { :id => desc.id, :type => 'LocationDescription' }
    desc.authors.clear
    assert_user_list_equal([], desc.reload.authors)

    # Make sure it lets Rolf and only Rolf see this page.
    assert(!@mary.in_group?('reviewers'))
    assert(@rolf.in_group?('reviewers'))
    requires_user(:review_authors, :show_location, params)
    assert_response('review_authors')

    # Remove Rolf from reviewers group.
    user_groups(:reviewers).users.delete(@rolf)
    @rolf.reload
    assert(!@rolf.in_group?('reviewers'))

    # Make sure it fails to let unauthorized users see page.
    get(:review_authors, params)
    assert_response(:action => :show_location, :id => desc.id)

    # Make Rolf an author.
    desc.add_author(@rolf)
    desc.save
    desc.reload
    assert_user_list_equal([@rolf], desc.authors)

    # Rolf should be able to do it now.
    get(:review_authors, params)
    assert_response('review_authors')

    # Rolf giveth with one hand...
    post(:review_authors, params.merge(:add => @mary.id))
    assert_response('review_authors')
    desc.reload
    assert_user_list_equal([@mary, @rolf], desc.authors)

    # ...and taketh with the other.
    post(:review_authors, params.merge(:remove => @mary.id))
    assert_response('review_authors')
    desc.reload
    assert_user_list_equal([@rolf], desc.authors)
  end

  def test_review_authors_name
    name = names(:peltigera)
    desc = name.description

    params = { :id => desc.id, :type => 'NameDescription' }

    # Make sure it lets reviewers get to page.
    requires_login(:review_authors, params)
    assert_response('review_authors')

    # Remove Rolf from reviewers group.
    user_groups(:reviewers).users.delete(@rolf)
    assert(!@rolf.reload.in_group?('reviewers'))

    # Make sure it fails to let unauthorized users see page.
    get(:review_authors, params)
    assert_response(:action => :show_name, :id => name.id)

    # Make Rolf an author.
    desc.add_author(@rolf)
    assert_user_list_equal([@rolf], desc.reload.authors)

    # Rolf should be able to do it again now.
    get(:review_authors, params)
    assert_response('review_authors')

    # Rolf giveth with one hand...
    post(:review_authors, params.merge(:add => @mary.id))
    assert_response('review_authors')
    assert_user_list_equal([@mary, @rolf], desc.reload.authors)

    # ...and taketh with the other.
    post(:review_authors, params.merge(:remove => @mary.id))
    assert_response('review_authors')
    assert_user_list_equal([@rolf], desc.reload.authors)
  end

  # Test setting export status of names and descriptions.
  def test_set_export_status
    name = names(:petigera)
    params = {
      :id => name.id,
      :type => 'name',
      :value => '1',
    }

    # Require login.
    get('set_export_status', params)
    assert_response(:controller => 'account', :action => 'login')

    # Require reviewer.
    login('dick')
    get('set_export_status', params)
    assert_flash_error
    logout

    # Require correct params.
    login('rolf')
    get('set_export_status', params.merge(:id => 9999))
    assert_flash_error
    get('set_export_status', params.merge(:type => 'bogus'))
    assert_flash_error
    get('set_export_status', params.merge(:value => 'true'))
    assert_flash_error

    # Now check *correct* usage.
    assert_equal(true, name.reload.ok_for_export)
    get('set_export_status', params.merge(:value => '0'))
    assert_response(:controller => 'name', :action => 'show_name', :id => name.id)
    assert_equal(false, name.reload.ok_for_export)
    get('set_export_status', params.merge(:value => '1'))
    assert_response(:controller => 'name', :action => 'show_name', :id => name.id)
    assert_equal(true, name.reload.ok_for_export)
  end

  def test_original_filename_visibility
    login('rolf')
    get(:show_observation, :id => 4)
    assert_true(@response.body.include?('áč€εиts'))

    login('mary')
    get(:show_observation, :id => 4)
    assert_false(@response.body.include?('áč€εиts'))
  end

  # ------------------------------
  #  Test creating observations.
  # ------------------------------

  # Test "get" side of create_observation.
  def test_create_observation
    requires_login(:create_observation)
    assert_form_action(:action => 'create_observation', :approved_name => '')
  end

  def test_construct_observation_approved_place_name
    where = "Albion, California, USA"
    generic_construct_observation({
      :observation => { :place_name => where},
      :name => { :name => "Coprinus comatus"},
      :approved_place_name => ""
    }, 1, 1, 0)
    obs = assigns(:observation)
    assert_equal(where, obs.place_name)
  end

  def test_construct_observation

    # Test a simple observation creation with an approved unique name
    where = "Simple, Massachusetts, USA"
    generic_construct_observation({
      :observation => { :place_name => where, :thumb_image_id => '0' },
      :name => { :name => "Coprinus comatus" }
    }, 1,1,0)
    obs = assigns(:observation)
    nam = assigns(:naming)
    assert_equal(where, obs.where)
    assert_equal(names(:coprinus_comatus).id, nam.name_id)
    assert_equal("2.03659", "%.5f" % obs.vote_cache)
    assert_not_nil(obs.rss_log)
    # This was getting set to zero instead of nil if no images were uploaded
    # when obs was created.
    assert_equal(nil, obs.thumb_image_id)

    # Test a simple observation creation of an unknown
    where = "Unknown, Massachusetts, USA"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 1,0,0)
    obs = assigns(:observation)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_not_nil(obs.rss_log)

    # Test an observation creation with a new name
    generic_construct_observation({
      :name => { :name => "New name" }
    }, 0,0,0)

    # Test an observation creation with an approved new name
    new_name = "Argus arg-arg"
    generic_construct_observation({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 1,1,2)

    # Test an observation creation with an approved new name with extra space
    new_name = "Another new-name"
    generic_construct_observation({
      :name => { :name => new_name + "  " },
      :approved_name => new_name + "  "
    }, 1,1,2)

    # Test an observation creation with an approved section (should fail)
    new_name = "Argus section Argus"
    generic_construct_observation({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 0,0,0)

    # Test an observation creation with an approved junk name
    new_name = "This is a bunch of junk"
    generic_construct_observation({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 0,0,0)

    # Test an observation creation with multiple matches
    generic_construct_observation({
      :name => { :name => "Amanita baccata" }
    }, 0,0,0)

    # Test an observation creation with one of the multiple matches chosen
    generic_construct_observation({
      :name => { :name => "Amanita baccata" },
      :chosen_name => { :name_id => names(:amanita_baccata_arora).id }
    }, 1,1,0)

    # Test an observation creation with one of the multiple matches chosen
    generic_construct_observation({
      :name => { :name => names(:pluteus_petasatus_deprecated).text_name }
    }, 1,1,0)
    nam = assigns(:naming)
    assert_equal(names(:pluteus_petasatus_approved).id, nam.name_id)

    # Test an observation creation with a deprecated name
    generic_construct_observation({
      :name => { :name => "Lactarius subalpinus" }
    }, 0,0,0)

    # Test an observation creation with a deprecated name, but a chosen approved alternative
    new_name = "Lactarius subalpinus"
    generic_construct_observation({
      :name => { :name => new_name },
      :approved_name => new_name,
      :chosen_name => { :name_id => names(:lactarius_alpinus).id }
    }, 1,1,0)
    nam = assigns(:naming)
    assert_equal(nam.name, names(:lactarius_alpinus))

    # Test an observation creation with a deprecated name that has been approved
    new_name = "Lactarius subalpinus"
    generic_construct_observation({
      :name => { :name => new_name },
      :approved_name => new_name,
      :chosen_name => { }
    }, 1,1,0)
    nam = assigns(:naming)
    assert_equal(nam.name, names(:lactarius_subalpinus))

    # Test an observation creation with an approved new name
    new_name = "Agaricus novus"
    Name.find_by_text_name('Agaricus').destroy
    generic_construct_observation({
      :name => { :name => new_name },
      :approved_name => new_name
    }, 1,1,2)
    name = Name.find_by_text_name(new_name)
    assert(name)
    assert_equal(new_name, name.text_name)

    # Test an observation that generates emails
    QueuedEmail.queue_emails(true)
    count_before = QueuedEmail.count
    name = names(:agaricus_campestris)
    notifications = Notification.find_all_by_flavor_and_obj_id(:name, name.id)
    assert_equal(2, notifications.length)

    where = "Simple, Massachusetts, USA"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => name.text_name }
    }, 1,1,0)
    obs = assigns(:observation)
    nam = assigns(:naming)
    assert_equal(where, obs.where) # Make sure it's the right observation
    assert_equal(name.id, nam.name_id) # Make sure it's the right name
    assert_not_nil(obs.rss_log)

    count_after = QueuedEmail.count
    assert_equal(count_before+2, count_after)

    # Test a simple observation creation of an unknown with a lat/long
    lat = 34.1622
    long = -118.3521
    generic_construct_observation({
      :observation => { :place_name => '', :lat => lat, :long => long },
      :name => { :name => "Unknown" },
    }, 1,0,0)
    obs = assigns(:observation)
    assert_equal(lat.to_s, obs.lat.to_s)
    assert_equal(long.to_s, obs.long.to_s)
    assert_objs_equal(Location.unknown, obs.location)
    assert_not_nil(obs.rss_log)

    lat2 = '34°9’43.92”N'
    long2 = '118°21′7.56″W'
    generic_construct_observation({
      :observation => { :place_name => '', :lat => lat2, :long => long2 },
      :name => { :name => "Unknown" },
    }, 1,0,0)
    obs = assigns(:observation)
    assert_equal(lat.to_s, obs.lat.to_s)
    assert_equal(long.to_s, obs.long.to_s)
    assert_objs_equal(Location.unknown, obs.location)
    assert_not_nil(obs.rss_log)

    # Make sure it doesn't accept no location AND no lat/long.
    generic_construct_observation({
      :observation => { :place_name => '', :lat => '', :long => '' },
      :name => { :name => "Unknown" },
    }, 0,0,0)

    # ... unless explicitly tell it "unknown" location.
    generic_construct_observation({
      :observation => { :place_name => 'Earth', :lat => '', :long => '' },
      :name => { :name => "Unknown" },
    }, 1,0,0)

    # Test a simple observation creation of an unknown with various altitudes
    for input, output in [
        [ '500',     500 ],
        [ '500m',    500 ],
        [ '500 ft.', 152 ],
        [ ' 500\' ', 152 ]
      ]
      where = 'Unknown, Massachusetts, USA'
      generic_construct_observation({
        :observation => { :place_name => where, :alt => input },
        :name => { :name => 'Unknown' },
      }, 1,0,0)
      obs = assigns(:observation)
      assert_equal(output, obs.alt)
      assert_equal(where, obs.where) # Make sure it's the right observation
      assert_not_nil(obs.rss_log)
    end
  end

  def test_construct_observation_dubious_place_names
    # Test a reversed name with a scientific user
    where = "USA, Massachusetts, Reversed"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 1,0,0, @roy)

    # Test a reversible order
    where = "Reversible, Massachusetts,USA"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0)
    where = "USA,Massachusetts, Reversible"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0, @roy)

    # Test a bogus country name
    where = "Bogus, Massachusetts, UAS"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0)
    where = "UAS, Massachusetts, Bogus"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0, @roy)

    # Test a bad state name
    where = "Bad State Name, USA"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0)
    where = "USA, Bad State Name"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0, @roy)

    # Test mix of city and county
    where = "Burbank, Los Angeles Co., California, USA"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0)
    where = "USA, California, Los Angeles Co., Burbank"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0, @roy)

    # Test mix of city and county
    where = "Falmouth, Barnstable Co., Massachusetts, USA"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0)
    where = "USA, Massachusetts, Barnstable Co., Falmouth"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0, @roy)

    # Test some bad terms
    where = "Some County, Ohio, USA"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0)
    where = "Old Rd, Ohio, USA"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 0,0,0)
    where = "Old Rd., Ohio, USA"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 1,0,0)

    # Test some acceptable additions
    where = "near Burbank, Southern California, USA"
    generic_construct_observation({
      :observation => { :place_name => where },
      :name => { :name => "Unknown" }
    }, 1,0,0)

  end

  def test_name_resolution
    login('rolf')

    params = {
      :observation => {
        :when => Time.now,
        :place_name => 'Somewhere, Massachusetts, USA',
        :specimen => '0',
        :thumb_image_id => '0',
      },
      :name => {},
      :vote => { :value => "3" },
    }
    expected_page = "create_location"
    # Can we create observation with existing genus?
    agaricus = names(:agaricus)
    params[:name][:name] = 'Agaricus'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp.'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    # Can we create observation with genus and add author?
    params[:name][:name] = 'Agaricus Author'
    params[:approved_name] = 'Agaricus Author'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal('Agaricus sp. Author', agaricus.reload.search_name)
    agaricus.author = nil
    agaricus.search_name = 'Agaricus sp.'
    agaricus.save

    params[:name][:name] = 'Agaricus sp Author'
    params[:approved_name] = 'Agaricus sp Author'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal('Agaricus sp. Author', agaricus.reload.search_name)
    agaricus.author = nil
    agaricus.search_name = 'Agaricus sp.'
    agaricus.save

    params[:name][:name] = 'Agaricus sp. Author'
    params[:approved_name] = 'Agaricus sp. Author'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(agaricus.id, assigns(:observation).name_id)
    assert_equal('Agaricus sp. Author', agaricus.reload.search_name)

    # Can we create observation with genus specifying author?
    params[:name][:name] = 'Agaricus Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    params[:name][:name] = 'Agaricus sp. Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(agaricus.id, assigns(:observation).name_id)

    # Can we create observation with deprecated genus?
    psalliota = names(:psalliota)
    params[:name][:name] = 'Psalliota'
    params[:approved_name] = 'Psalliota'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(psalliota.id, assigns(:observation).name_id)

    params[:name][:name] = 'Psalliota sp'
    params[:approved_name] = 'Psalliota sp'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(psalliota.id, assigns(:observation).name_id)

    params[:name][:name] = 'Psalliota sp.'
    params[:approved_name] = 'Psalliota sp.'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(psalliota.id, assigns(:observation).name_id)

    # Can we create observation with deprecated genus, adding author?
    params[:name][:name] = 'Psalliota Author'
    params[:approved_name] = 'Psalliota Author'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal('Psalliota sp. Author', psalliota.reload.search_name)
    psalliota.author = nil
    psalliota.search_name = 'Psalliota sp.'
    psalliota.save

    params[:name][:name] = 'Psalliota sp Author'
    params[:approved_name] = 'Psalliota sp Author'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal('Psalliota sp. Author', psalliota.reload.search_name)
    psalliota.author = nil
    psalliota.search_name = 'Psalliota sp.'
    psalliota.save

    params[:name][:name] = 'Psalliota sp. Author'
    params[:approved_name] = 'Psalliota sp. Author'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal(psalliota.id, assigns(:observation).name_id)
    assert_equal('Psalliota sp. Author', psalliota.reload.search_name)

    # Can we create new quoted genus?
    params[:name][:name] = '"One"'
    params[:approved_name] = '"One"'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" sp.', assigns(:observation).name.search_name)

    params[:name][:name] = '"Two" sp'
    params[:approved_name] = '"Two" sp'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal('"Two"', assigns(:observation).name.text_name)
    assert_equal('"Two" sp.', assigns(:observation).name.search_name)

    params[:name][:name] = '"Three" sp.'
    params[:approved_name] = '"Three" sp.'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal('"Three"', assigns(:observation).name.text_name)
    assert_equal('"Three" sp.', assigns(:observation).name.search_name)

    params[:name][:name] = '"One"'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal('"One"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" sp'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal('"One"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" sp.'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal('"One"', assigns(:observation).name.text_name)

    # Can we create species under the quoted genus?
    params[:name][:name] = '"One" foo'
    params[:approved_name] = '"One" foo'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal('"One" foo', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" "bar"'
    params[:approved_name] = '"One" "bar"'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal('"One" "bar"', assigns(:observation).name.text_name)

    params[:name][:name] = '"One" Author'
    params[:approved_name] = '"One" Author'
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" sp. Author', assigns(:observation).name.search_name)

    params[:name][:name] = '"One" sp Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" sp. Author', assigns(:observation).name.search_name)

    params[:name][:name] = '"One" sp. Author'
    params[:approved_name] = nil
    post(:create_observation, params)
    assert_response(:action => expected_page)
    assert_equal('"One"', assigns(:observation).name.text_name)
    assert_equal('"One" sp. Author', assigns(:observation).name.search_name)
  end

  # ----------------------------------------------------------------
  #  Test edit_observation and edit_naming, both "get" and "post".
  # ----------------------------------------------------------------

  # (Sorry, these used to all be edit/update_observation, now they're
  # confused because of the naming stuff.)
  def test_edit_observation_get
    obs = observations(:coprinus_comatus_obs)
    assert_equal("rolf", obs.user.login)
    params = { :id => obs.id.to_s }
    requires_user(:edit_observation, ["observer", "show_observation"], params)
    assert_form_action(:action => 'edit_observation', :id => obs.id.to_s)
  end

  def test_edit_observation
    obs = observations(:detailed_unknown)
    modified = obs.rss_log.modified
    new_where = "Somewhere In, Japan"
    new_notes = "blather blather blather"
    new_specimen = false
    params = {
      :id => obs.id.to_s,
      :observation => {
        :place_name => new_where,
        "when(1i)" => "2001",
        "when(2i)" => "2",
        "when(3i)" => "3",
        :notes => new_notes,
        :specimen => new_specimen,
        :thumb_image_id => "0",
      },
      :good_images => '1 2',
      :good_image => {
        '1' => {
          :notes => 'new notes',
          :original_name => 'new name',
          :copyright_holder => 'someone else',
          'when(1i)' => '2012',
          'when(2i)' => '4',
          'when(3i)' => '6',
          :license_id => '3',
        },
      },
      :log_change => { :checked => '1' }
    }
    post_requires_user(:edit_observation, ["observer", "show_observation"], params, 'mary')
    assert_response(:controller => :location, :action => :create_location)
    assert_equal(10, @rolf.reload.contribution)
    obs = assigns(:observation)
    assert_equal(new_where, obs.where)
    assert_equal("2001-02-03", obs.when.to_s)
    assert_equal(new_notes, obs.notes)
    assert_equal(new_specimen, obs.specimen)
    assert_not_equal(modified, obs.rss_log.modified)
    assert_not_equal(0, obs.thumb_image_id)
    img = images(:in_situ).reload
    assert_equal('new notes', img.notes)
    assert_equal('new name', img.original_name)
    assert_equal('someone else', img.copyright_holder)
    assert_equal('2012-04-06', img.when.to_s)
    assert_equal(licenses(:ccwiki30), img.license)
  end

  def test_edit_observation_no_logging
    obs = observations(:detailed_unknown)
    modified = obs.rss_log.modified
    where = "Somewhere, China"
    params = {
      :id => obs.id.to_s,
      :observation => {
        :place_name => where,
        :when => obs.when,
        :notes => obs.notes,
        :specimen => obs.specimen,
      },
      :log_change => { :checked => '0' }
    }
    post_requires_user(:edit_observation, ["observer", "show_observation"], params, 'mary')
    assert_response(:controller => :location, :action => :create_location)
    assert_equal(10, @rolf.reload.contribution)
    obs = assigns(:observation)
    assert_equal(where, obs.where)
    assert_equal(modified, obs.rss_log.modified)
  end

  def test_edit_observation_bad_place_name
    obs = observations(:detailed_unknown)
    modified = obs.rss_log.modified
    new_where = "test_update_observation"
    new_notes = "blather blather blather"
    new_specimen = false
    params = {
      :id => obs.id.to_s,
      :observation => {
        :place_name => new_where,
        "when(1i)" => "2001",
        "when(2i)" => "2",
        "when(3i)" => "3",
        :notes => new_notes,
        :specimen => new_specimen,
        :thumb_image_id => "0",
      },
      :log_change => { :checked => '1' }
    }
    post_requires_user(:edit_observation, ["observer", "show_observation"], params, 'mary')
    assert_response(:success) # Which really means failure
  end

  def test_edit_observation_with_another_users_image
    img1 = images(:in_situ)
    img2 = images(:turned_over)
    img3 = images(:commercial_inquiry_image)

    obs = observations(:detailed_unknown)
    obs.images << img3
    obs.save
    obs.reload

    assert_equal(img1.user_id, obs.user_id)
    assert_equal(img2.user_id, obs.user_id)
    assert_not_equal(img3.user_id, obs.user_id)

    img_ids = obs.images.map(&:id)
    assert_equal([1, 2, 3], img_ids)

    old_img1_notes = img1.notes
    old_img2_notes = img2.notes
    old_img3_notes = img3.notes

    params = {
      :id => obs.id.to_s,
      :observation => {
        :place_name => obs.place_name,
        :when => obs.when,
        :notes => obs.notes,
        :specimen => obs.specimen,
        :thumb_image_id => "0",
      },
      :good_images => img_ids.map(&:to_s).join(' '),
      :good_image => {
        img2.id.to_s => { :notes => 'new notes for two', },
        img3.id.to_s => { :notes => 'new notes for three', },
      },
    }
    login('mary')
    post(:edit_observation, params)
    assert_response(:action => :show_observation)
    assert_flash_success
    assert_equal(old_img1_notes, img1.reload.notes)
    assert_equal('new notes for two', img2.reload.notes)
    assert_equal(old_img3_notes, img3.reload.notes)
  end

  # ----------------------------
  #  Test namings.
  # ----------------------------

  # Now test the naming part of it.
  def test_create_naming_get
    obs = observations(:coprinus_comatus_obs)
    params = {
      :id => obs.id.to_s
    }
    requires_login(:create_naming, params)
    assert_form_action(:action => 'create_naming', :approved_name => '', :id => obs.id.to_s)
  end

  # Now test the naming part of it.
  def test_edit_naming_get
    nam = namings(:coprinus_comatus_naming)
    params = {
      :id => nam.id.to_s
    }
    requires_user(:edit_naming, ["observer", "show_observation"], params)
    assert_form_action(:action => 'edit_naming', :approved_name => nam.text_name, :id => nam.id.to_s)
  end

  def test_update_observation_new_name
    login('rolf')
    nam = namings(:coprinus_comatus_naming)
    old_name = nam.text_name
    new_name = "Easter bunny"
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name }
    }
    post(:edit_naming, params)
    assert_response('edit_naming')
    assert_equal(10, @rolf.reload.contribution)
    obs = assigns(:naming)
    assert_not_equal(new_name, nam.text_name)
    assert_equal(old_name, nam.text_name)
  end

  def test_update_observation_approved_new_name
    login('rolf')
    nam = namings(:coprinus_comatus_naming)
    old_name = nam.text_name
    new_name = "Easter bunny"
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name },
      :approved_name => new_name,
      :vote => { :value => 1 }
    }
    post(:edit_naming, params)
    assert_response(:action => :show_observation)
    # Clones naming, creates Easter sp and E. bunny, but no votes.
    assert_equal(10 + 10*2 + 2, @rolf.reload.contribution)
    nam = assigns(:naming)
    assert_equal(new_name, nam.text_name)
    assert_not_equal(old_name, nam.text_name)
    assert(!nam.name.deprecated)
  end

  def test_update_observation_multiple_match
    login('rolf')
    nam = namings(:coprinus_comatus_naming)
    old_name = nam.text_name
    new_name = "Amanita baccata"
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name }
    }
    post(:edit_naming, params)
    assert_response('edit_naming')
    assert_equal(10, @rolf.reload.contribution)
    nam = assigns(:naming)
    assert_not_equal(new_name, nam.text_name)
    assert_equal(old_name, nam.text_name)
  end

  def test_update_observation_chosen_multiple_match
    login('rolf')
    nam = namings(:coprinus_comatus_naming)
    old_name = nam.text_name
    new_name = "Amanita baccata"
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name },
      :chosen_name => { :name_id => names(:amanita_baccata_arora).id },
      :vote => { :value => 1 }
    }
    post(:edit_naming, params)
    assert_response(:action => :show_observation)
    # Must be cloning naming with no vote.
    assert_equal(12, @rolf.reload.contribution)
    nam = assigns(:naming)
    assert_equal(new_name, nam.name.text_name)
    assert_equal(new_name + " sensu Arora", nam.text_name)
    assert_not_equal(old_name, nam.text_name)
  end

  def test_update_observation_deprecated
    login('rolf')
    nam = namings(:coprinus_comatus_naming)
    old_name = nam.text_name
    new_name = "Lactarius subalpinus"
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name }
    }
    post(:edit_naming, params)
    assert_response('edit_naming')
    assert_equal(10, @rolf.reload.contribution)
    nam = assigns(:naming)
    assert_not_equal(new_name, nam.text_name)
    assert_equal(old_name, nam.text_name)
  end

  def test_update_observation_chosen_deprecated
    login('rolf')
    nam = namings(:coprinus_comatus_naming)
    start_name = nam.name
    new_name = "Lactarius subalpinus"
    chosen_name = names(:lactarius_alpinus)
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_name },
      :approved_name => new_name,
      :chosen_name => { :name_id => chosen_name.id },
      :vote => { :value => 1 }
    }
    post(:edit_naming, params)
    assert_response(:action => :show_observation)
    # Must be cloning naming, with no vote.
    assert_equal(12, @rolf.reload.contribution)
    nam = assigns(:naming)
    assert_not_equal(start_name.id, nam.name_id)
    assert_equal(chosen_name.id, nam.name_id)
  end

  def test_update_observation_accepted_deprecated
    login('rolf')
    nam = namings(:coprinus_comatus_naming)
    start_name = nam.name
    new_text_name = names(:lactarius_subalpinus).text_name
    params = {
      :id => nam.id.to_s,
      :name => { :name => new_text_name },
      :approved_name => new_text_name,
      :chosen_name => { },
      :vote => { :value => 3 },
    }
    post(:edit_naming, params)
    assert_response(:action => :show_observation)
    # Must be cloning the naming, but no votes?
    assert_equal(12, @rolf.reload.contribution)
    nam = assigns(:naming)
    assert_not_equal(start_name.id, nam.name_id)
    assert_equal(new_text_name, nam.name.text_name)
  end

  # ------------------------------------------------------------
  #  Test proposing new names, casting and changing votes, and
  #  setting and changing preferred_namings.
  # ------------------------------------------------------------

  # This is the standard case, nothing unusual or stressful here.
  def test_propose_naming
    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    v_count = Vote.count

    # Make a few assertions up front to make sure fixtures are as expected.
    assert_equal(names(:coprinus_comatus).id, observations(:coprinus_comatus_obs).name_id)
    assert(namings(:coprinus_comatus_naming).user_voted?(@rolf))
    assert(namings(:coprinus_comatus_naming).user_voted?(@mary))
    assert(!namings(:coprinus_comatus_naming).user_voted?(@dick))
    assert(namings(:coprinus_comatus_other_naming).user_voted?(@rolf))
    assert(namings(:coprinus_comatus_other_naming).user_voted?(@mary))
    assert(!namings(:coprinus_comatus_other_naming).user_voted?(@dick))

    # Rolf, the owner of observations(:coprinus_comatus_obs), already has a naming, which
    # he's 80% sure of.  Create a new one (the genus Agaricus) that he's 100%
    # sure of.  (Mary also has a naming with two votes.)
    params = {
      :id => observations(:coprinus_comatus_obs).id,
      :name => { :name => "Agaricus" },
      :vote => { :value => "3" },
      :reason => {
        "1" => { :check => "1", :notes => "Looks good to me." },
        "2" => { :check => "1", :notes => "" },
        "3" => { :check => "0", :notes => "Spore texture." },
        "4" => { :check => "0", :notes => "" }
      }
    }
    login('rolf')
    post(:create_naming, params)
    assert_response(:redirect)

    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.count)
    assert_equal(g_count + 1, Naming.count)
    assert_equal(n_count + 0, Name.count)
    assert_equal(v_count + 1, Vote.count)

    # Make sure contribution is updated correctly.
    assert_equal(12, @rolf.reload.contribution)

    # Make sure everything I need is reloaded.
    observations(:coprinus_comatus_obs).reload

    # Get new objects.
    naming = Naming.last
    vote = Vote.last

    # Make sure observation was updated and referenced correctly.
    assert_equal(3, observations(:coprinus_comatus_obs).namings.length)
    assert_equal(names(:agaricus).id, observations(:coprinus_comatus_obs).name_id)

    # Make sure naming was created correctly and referenced.
    assert_equal(observations(:coprinus_comatus_obs), naming.observation)
    assert_equal(names(:agaricus).id, naming.name_id)
    assert_equal(@rolf, naming.user)
    assert_equal(3, naming.get_reasons.select(&:used?).length)
    assert_equal(1, naming.votes.length)

    # Make sure vote was created correctly.
    assert_equal(naming, vote.naming)
    assert_equal(@rolf, vote.user)
    assert_equal(3, vote.value)

    # Make sure reasons were created correctly.
    nr1, nr2, nr3, nr4 = naming.get_reasons
    assert_equal(1, nr1.num)
    assert_equal(2, nr2.num)
    assert_equal(3, nr3.num)
    assert_equal(4, nr4.num)
    assert_equal("Looks good to me.", nr1.notes)
    assert_equal("", nr2.notes)
    assert_equal("Spore texture.", nr3.notes)
    assert_equal(nil, nr4.notes)
    assert(nr1.used?)
    assert(nr2.used?)
    assert(nr3.used?)
    assert(!nr4.used?)

    # Make sure a few random methods work right, too.
    assert_equal(3, naming.vote_sum)
    assert_equal(vote, naming.users_vote(@rolf))
    assert(naming.user_voted?(@rolf))
    assert(!naming.user_voted?(@mary))
  end

  # Now see what happens when rolf's new naming is less confident than old.
  def test_propose_uncertain_naming
    g_count = Naming.count
    params = {
      :id => observations(:coprinus_comatus_obs).id,
      :name => { :name => "Agaricus" },
      :vote => { :value => "-1" },
    }
    login('rolf')
    post(:create_naming, params)
    assert_response(:redirect)
    assert_equal(12, @rolf.reload.contribution)

    # Make sure everything I need is reloaded.
    observations(:coprinus_comatus_obs).reload
    namings(:coprinus_comatus_naming).reload

    # Get new objects.
    naming = Naming.last

    # Make sure observation was updated right.
    assert_equal(names(:coprinus_comatus).id, observations(:coprinus_comatus_obs).name_id)

    # Sure, check the votes, too, while we're at it.
    assert_equal(3, namings(:coprinus_comatus_naming).vote_sum) # 2+1 = 3
  end

  # Now see what happens when a third party proposes a name, and it wins.
  def test_propose_dicks_naming
    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    v_count = Vote.count

    # Dick proposes "Conocybe filaris" out of the blue.
    params = {
      :id => observations(:coprinus_comatus_obs).id,
      :name => { :name => "Conocybe filaris" },
      :vote => { :value => "3" },
    }
    login("dick")
    post(:create_naming, params)
    assert_response(:redirect)
    assert_equal(12, @dick.reload.contribution)
    naming = Naming.last

    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.count)
    assert_equal(g_count + 1, Naming.count)
    assert_equal(n_count + 0, Name.count)
    assert_equal(v_count + 1, Vote.count)

    # Make sure everything I need is reloaded.
    observations(:coprinus_comatus_obs).reload
    namings(:coprinus_comatus_naming).reload
    namings(:coprinus_comatus_other_naming).reload

    # Check votes.
    assert_equal(3, namings(:coprinus_comatus_naming).vote_sum)
    assert_equal(0, namings(:coprinus_comatus_other_naming).vote_sum)
    assert_equal(3, naming.vote_sum)
    assert_equal(2, namings(:coprinus_comatus_naming).votes.length)
    assert_equal(2, namings(:coprinus_comatus_other_naming).votes.length)
    assert_equal(1, naming.votes.length)

    # Make sure observation was updated right.
    assert_equal(names(:conocybe_filaris).id, observations(:coprinus_comatus_obs).name_id)
  end

  # Test a bug in name resolution: was failing to recognize that
  # "Genus species (With) Author" was recognized even if "Genus species"
  # was already in the database.
  def test_create_naming_with_author_when_name_without_author_already_exists
    params = {
      :id => observations(:coprinus_comatus_obs).id,
      :name => { :name => "Conocybe filaris (With) Author" },
      :vote => { :value => "3" },
    }
    login("dick")
    post(:create_naming, params)
    assert_response(:action => "show_observation", :id => observations(:coprinus_comatus_obs).id)
    # Dick is getting points for the naming, vote, and name change.
    assert_equal(12 + 10, @dick.reload.contribution)
    naming = Naming.last
    assert_equal("Conocybe filaris", naming.name.text_name)
    assert_equal("(With) Author", naming.name.author)
    assert_equal(names(:conocybe_filaris).id, naming.name_id)
  end

  # Test a bug in name resolution: was failing to recognize that
  # "Genus species (With) Author" was recognized even if "Genus species"
  # was already in the database.
  def test_create_naming_fill_in_author
    params = {
      :id => observations(:coprinus_comatus_obs).id,
      :name => { :name => 'Agaricus campestris' },
    }
    login("dick")
    post(:create_naming, params)
    assert_response(:success) # really means failed
    assert_equal('Agaricus campestris L.', @controller.instance_variable_get('@what'))
  end

  # Test a bug in name resolution: was failing to recognize that
  # "Genus species (With) Author" was recognized even if "Genus species"
  # was already in the database.
  def test_create_name_with_quotes
    name = 'Foo "bar" Author'
    params = {
      :id => observations(:coprinus_comatus_obs).id,
      :name => { :name => name },
      :approved_name => name
    }
    login("dick")
    post(:create_naming, params)
    assert_response(:success) # really means failed
    assert(name = Name.find_by_text_name('Foo "bar"'))
    assert_equal('Foo "bar" Author', name.search_name)
  end

  # ----------------------------
  #  Test voting.
  # ----------------------------

  # Now have Dick vote on Mary's name.
  # Votes: rolf=2/-3, mary=1/3, dick=-1/3
  # Rolf prefers naming 3 (vote 2 -vs- -3).
  # Mary prefers naming 9 (vote 1 -vs- 3).
  # Dick now prefers naming 9 (vote 3).
  # Summing, 3 gets 2+1/3=1, 9 gets -3+3+3/4=.75, so 3 gets it.
  def test_cast_vote_dick
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login('dick')
    post(:cast_vote, :value => "3", :id => nam2.id)
    assert_equal(11, @dick.reload.contribution)

    # Check votes.
    assert_equal(3, nam1.reload.vote_sum)
    assert_equal(2, nam1.votes.length)
    assert_equal(3, nam2.reload.vote_sum)
    assert_equal(3, nam2.votes.length)

    # Make sure observation was updated right.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # If Dick votes on the other as well, then his first vote should
    # get demoted and his preference should change.
    # Summing, 3 gets 2+1+3/4=1.5, 9 gets -3+3+2/4=.5, so 3 keeps it.
    obs.change_vote(nam1, 3, @dick)
    assert_equal(12, @dick.reload.contribution)
    assert_equal(3, nam1.reload.users_vote(@dick).value)
    assert_equal(6, nam1.vote_sum)
    assert_equal(3, nam1.votes.length)
    assert_equal(2, nam2.reload.users_vote(@dick).value)
    assert_equal(2, nam2.vote_sum)
    assert_equal(3, nam2.votes.length)
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)
  end

  # Now have Rolf change his vote on his own naming. (no change in prefs)
  # Votes: rolf=3->2/-3, mary=1/3, dick=x/x
  def test_cast_vote_rolf_change
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login('rolf')
    post(:cast_vote, :value => "2", :id => nam1.id)
    assert_equal(10, @rolf.reload.contribution)

    # Make sure observation was updated right.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # Check vote.
    assert_equal(3, nam1.reload.vote_sum)
    assert_equal(2, nam1.votes.length)
  end

  # Now have Rolf increase his vote for Mary's. (changes consensus)
  # Votes: rolf=2/-3->3, mary=1/3, dick=x/x
  def test_cast_vote_rolf_second_greater
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login('rolf')
    post(:cast_vote, :value => "3", :id => nam2.id)
    assert_equal(10, @rolf.reload.contribution)

    # Make sure observation was updated right.
    assert_equal(names(:agaricus_campestris).id, obs.reload.name_id)

    # Check vote.
    assert_equal(6, nam2.reload.vote_sum)
    assert_equal(2, nam2.votes.length)
  end

  # Now have Rolf increase his vote for Mary's insufficiently. (no change)
  # Votes: rolf=2/-3->-1, mary=1/3, dick=x/x
  # Summing, 3 gets 2+1=3, 9 gets -1+3=2, so 3 keeps it.
  def test_cast_vote_rolf_second_lesser
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login('rolf')
    post(:cast_vote,
      :value => "-1",
      :id    => nam2.id
    )
    assert_equal(10, @rolf.reload.contribution)

    # Make sure observation was updated right.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # Check vote.
    assert_equal(3, nam1.reload.vote_sum)
    assert_equal(2, nam2.reload.vote_sum)
    assert_equal(2, nam2.votes.length)
  end

  # Now, have Mary delete her vote against Rolf's naming.  This NO LONGER has the effect
  # of excluding Rolf's naming from the consensus calculation due to too few votes.
  # (Have Dick vote first... I forget what this was supposed to test for, but it's clearly
  # superfluous now).
  # Votes: rolf=2/-3, mary=1->x/3, dick=x/x->3
  # Summing after Dick votes,   3 gets 2+1/3=1, 9 gets -3+3+3/4=.75, 3 keeps it.
  # Summing after Mary deletes, 3 gets 2/2=1,   9 gets -3+3+3/4=.75, 3 still keeps it in this voting algorithm, arg.
  def test_cast_vote_mary
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    login('dick')
    obs.change_vote(nam2, 3, @dick)
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)
    assert_equal(11, @dick.reload.contribution)

    login('mary')
    post(:cast_vote, :value => Vote.delete_vote, :id => nam1.id)
    assert_equal(9, @mary.reload.contribution)

    # Check votes.
    assert_equal(2, nam1.reload.vote_sum)
    assert_equal(1, nam1.votes.length)
    assert_equal(3, nam2.reload.vote_sum)
    assert_equal(3, nam2.votes.length)

    # Make sure observation is changed correctly.
    assert_equal(names(:coprinus_comatus).search_name, obs.reload.name.search_name,
      "Cache for 3: #{nam1.vote_cache}, 9: #{nam2.vote_cache}")
  end

  # Rolf can destroy his naming if Mary deletes her vote on it.
  def test_rolf_destroy_rolfs_naming
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    # First delete Mary's vote for it.
    login('mary')
    obs.change_vote(nam1, Vote.delete_vote, @mary)
    assert_equal(9, @mary.reload.contribution)

    old_naming_id = nam1.id
    old_vote1_id = votes(:coprinus_comatus_owner_vote).id
    old_vote2_id = votes(:coprinus_comatus_other_vote).id rescue nil

    login('rolf')
    get(:destroy_naming, :id => nam1.id)

    # Make sure naming and associated vote and reason were actually destroyed.
    assert_raises(ActiveRecord::RecordNotFound) do
      Naming.find(old_naming_id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      Vote.find(old_vote1_id)
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      Vote.find(old_vote2_id)
    end

    # Make sure observation was updated right.
    assert_equal(names(:agaricus_campestris).id, obs.reload.name_id)

    # Check votes. (should be no change)
    assert_equal(0, nam2.reload.vote_sum)
    assert_equal(2, nam2.votes.length)
  end

  # Make sure Rolf can't destroy his naming if Dick prefers it.
  def test_rolf_destroy_rolfs_naming_when_dick_prefers_it
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    old_naming_id = nam1.id
    old_vote1_id = votes(:coprinus_comatus_owner_vote).id
    old_vote2_id = votes(:coprinus_comatus_other_vote).id

    # Make Dick prefer it.
    login('dick')
    obs.change_vote(nam1, 3, @dick)
    assert_equal(11, @dick.reload.contribution)

    # Have Rolf try to destroy it.
    login('rolf')
    get(:destroy_naming, :id => nam1.id)

    # Make sure naming and associated vote and reason are still there.
    assert(Naming.find(old_naming_id))
    assert(Vote.find(old_vote1_id))
    assert(Vote.find(old_vote2_id))

    # Make sure observation is unchanged.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # Check votes are unchanged.
    assert_equal(6, nam1.reload.vote_sum)
    assert_equal(3, nam1.votes.length)
    assert_equal(0, nam2.reload.vote_sum)
    assert_equal(2, nam2.votes.length)
  end

  # Rolf makes changes to vote and reasons of his naming.  Shouldn't matter
  # whether Mary has voted on it.
  def test_edit_naming_thats_being_used_just_change_reasons
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    v_count = Vote.count

    # Rolf makes superficial changes to his naming.
    login('rolf')
    post(:edit_naming,
      :id => nam1.id,
      :name => { :name => names(:coprinus_comatus).search_name },
      :vote => { :value => "3" },
      :reason => {
        "1" => { :check => "1", :notes => "Change to macro notes." },
        "2" => { :check => "1", :notes => "" },
        "3" => { :check => "0", :notes => "Add some micro notes." },
        "4" => { :check => "0", :notes => "" }
      }
    )
    assert_equal(10, @rolf.reload.contribution)

    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.count)
    assert_equal(g_count + 0, Naming.count)
    assert_equal(n_count + 0, Name.count)
    assert_equal(v_count + 0, Vote.count)

    # Make sure observation is unchanged.
    assert_equal(names(:coprinus_comatus).id, obs.reload.name_id)

    # Check votes.
    assert_equal(4, nam1.reload.vote_sum) # 2+1 -> 3+1
    assert_equal(2, nam1.votes.length)

    # Check new reasons.
    nrs = nam1.get_reasons
    assert_equal(3, nrs.select(&:used?).length)
    assert_equal(1, nrs[0].num)
    assert_equal(2, nrs[1].num)
    assert_equal(3, nrs[2].num)
    assert_equal("Change to macro notes.", nrs[0].notes)
    assert_equal("", nrs[1].notes)
    assert_equal("Add some micro notes.", nrs[2].notes)
    assert_nil(nrs[3].notes)
  end

  # Rolf makes changes to name of his naming.  Shouldn't be allowed to do this
  # if Mary has voted on it.  Should clone naming, vote, and reasons.
  def test_edit_naming_thats_being_used_change_name
    obs  = observations(:coprinus_comatus_obs)
    nam1 = namings(:coprinus_comatus_naming)
    nam2 = namings(:coprinus_comatus_other_naming)

    o_count = Observation.count
    g_count = Naming.count
    n_count = Name.count
    v_count = Vote.count

    # Now, Rolf makes name change to his naming (leave rest the same).
    login('rolf')
    assert_equal(10, @rolf.contribution)
    post(:edit_naming,
      :id => nam1.id,
      :name => { :name => "Conocybe filaris" },
      :vote => { :value => "2" },
      :reason => {
        "1" => { :check => "1", :notes => "Isn't it obvious?" },
        "2" => { :check => "0", :notes => "" },
        "3" => { :check => "0", :notes => "" },
        "4" => { :check => "0", :notes => "" }
      }
    )
    assert_response(:redirect) # redirect indicates success
    assert_equal(12, @rolf.reload.contribution)

    # Make sure the right number of objects were created.
    assert_equal(o_count + 0, Observation.count)
    assert_equal(g_count + 1, Naming.count)
    assert_equal(n_count + 0, Name.count)
    assert_equal(v_count + 1, Vote.count)

    # Get new objects.
    naming = Naming.last
    vote = Vote.last

    # Make sure observation is unchanged.
    assert_equal(names(:conocybe_filaris).id, obs.reload.name_id)

    # Make sure old naming is unchanged.
    assert_equal(names(:coprinus_comatus).id, nam1.reload.name_id)
    assert_equal(1, nam1.get_reasons.select(&:used?).length)
    assert_equal(3, nam1.vote_sum)
    assert_equal(2, nam1.votes.length)

    # Check new naming.
    assert_equal(observations(:coprinus_comatus_obs), naming.observation)
    assert_equal(names(:conocybe_filaris).id, naming.name_id)
    assert_equal(@rolf, naming.user)
    nrs = naming.get_reasons.select(&:used?)
    assert_equal(1, nrs.length)
    assert_equal(1, nrs.first.num)
    assert_equal("Isn't it obvious?", nrs.first.notes)
    assert_equal(2, naming.vote_sum)
    assert_equal(1, naming.votes.length)
    assert_equal(vote, naming.votes.first)
    assert_equal(2, vote.value)
    assert_equal(@rolf, vote.user)
  end

  def test_show_votes
    # First just make sure the page displays.
    get_with_dump(:show_votes, :id => namings(:coprinus_comatus_naming).id)
    assert_response('show_votes')

    # Now try to make somewhat sure the content is right.
    table = namings(:coprinus_comatus_naming).calc_vote_table
    str1 = Vote.agreement(votes(:coprinus_comatus_owner_vote).value)
    str2 = Vote.agreement(votes(:coprinus_comatus_other_vote).value)
    for str in table.keys
      if str == str1 && str1 == str2
        assert_equal(2, table[str][:num])
      elsif str == str1
        assert_equal(1, table[str][:num])
      elsif str == str2
        assert_equal(1, table[str][:num])
      else
        assert_equal(0, table[str][:num])
      end
    end
  end

  # -----------------------------------
  #  Test extended observation forms.
  # -----------------------------------

  def test_javascripty_name_reasons
    login('rolf')

    # If javascript isn't enabled, then checkbox isn't required.
    post(:create_observation,
      :observation => { :place_name => 'Where, Japan', :when => Time.now },
      :name => { :name => names(:coprinus_comatus).text_name },
      :vote => { :value => 3 },
      :reason => {
        "1" => { :check => '0', :notes => ''    },
        "2" => { :check => '0', :notes => 'foo' },
        "3" => { :check => '1', :notes => ''    },
        "4" => { :check => '1', :notes => 'bar' }
      }
    )
    assert_response(:redirect) # redirected = successfully created
    naming = Naming.find(assigns(:naming).id)
    reasons = naming.get_reasons.select(&:used?).map(&:num).sort
    assert_equal([2,3,4], reasons)

    # If javascript IS enabled, then checkbox IS required.
    post(:create_observation,
      :observation => { :place_name => 'Where, Japan', :when => Time.now },
      :name => { :name => names(:coprinus_comatus).text_name },
      :vote => { :value => 3 },
      :reason => {
        "1" => { :check => '0', :notes => ''    },
        "2" => { :check => '0', :notes => 'foo' },
        "3" => { :check => '1', :notes => ''    },
        "4" => { :check => '1', :notes => 'bar' }
      },
      :was_js_on => 'yes'
    )
    assert_response(:redirect) # redirected = successfully created
    naming = Naming.find(assigns(:naming).id)
    reasons = naming.get_reasons.select(&:used?).map(&:num).sort
    assert_equal([3,4], reasons)
  end

  def test_create_with_image_upload
    login('rolf')

    time0 = Time.utc(2000)
    time1 = Time.utc(2001)
    time2 = Time.utc(2002)
    time3 = Time.utc(2003)
    week_ago = 1.week.ago

    setup_image_dirs
    file = "#{RAILS_ROOT}/test/fixtures/images/Coprinus_comatus.jpg"
    file1 = FilePlus.new(file)
    file1.content_type = 'image/jpeg'
    file2 = FilePlus.new(file)
    file2.content_type = 'image/jpeg'
    file3 = FilePlus.new(file)
    file3.content_type = 'image/jpeg'

    new_image_1 = Image.create(
      :copyright_holder => 'holder_1',
      :when => time1,
      :notes => 'notes_1',
      :user_id => 1,
      :image => file1,
      :content_type => 'image/jpeg',
      :created => week_ago,
      :modified => week_ago
    )

    new_image_2 = Image.create(
      :copyright_holder => 'holder_2',
      :when => time2,
      :notes => 'notes_2',
      :user_id => 1,
      :image => file2,
      :content_type => 'image/jpeg',
      :created => week_ago,
      :modified => week_ago
    )

    assert(new_image_1.modified < 1.day.ago)
    assert(new_image_2.modified < 1.day.ago)

    post(:create_observation,
      :observation => {
        :place_name => 'Zzyzx, Japan',
        :when => time0,
        :thumb_image_id => 0,   # (make new image the thumbnail)
        :notes => 'blah',
      },
      :image => {
        '0' => {
          :image => file3,
          :copyright_holder => 'holder_3',
          :when => time3,
          :notes => 'notes_3',
        },
      },
      :good_image => {
        new_image_1.id.to_s => {
        },
        new_image_2.id.to_s => {
          :notes => 'notes_2_new',
        },
      },
      # (attach these two images once observation created)
      :good_images => "#{new_image_1.id} #{new_image_2.id}",
    )
    assert_response(:redirect) # redirected = successfully created

    obs = Observation.find_by_where('Zzyzx, Japan')
    assert_equal(1, obs.user_id)
    assert_equal(time0, obs.when)
    assert_equal('Zzyzx, Japan', obs.place_name)

    new_image_1.reload
    new_image_2.reload
    imgs = obs.images.sort_by(&:id)
    img_ids = imgs.map(&:id)
    assert_equal([new_image_1.id, new_image_2.id, new_image_2.id+1], img_ids)
    assert_equal(new_image_2.id+1, obs.thumb_image_id)
    assert_equal('holder_1', imgs[0].copyright_holder)
    assert_equal('holder_2', imgs[1].copyright_holder)
    assert_equal('holder_3', imgs[2].copyright_holder)
    assert_equal(time1, imgs[0].when)
    assert_equal(time2, imgs[1].when)
    assert_equal(time3, imgs[2].when)
    assert_equal('notes_1',     imgs[0].notes)
    assert_equal('notes_2_new', imgs[1].notes)
    assert_equal('notes_3',     imgs[2].notes)
    assert(imgs[0].modified < 1.day.ago) # notes not changed
    assert(imgs[1].modified > 1.day.ago) # notes changed
  end

  def test_image_upload_when_create_fails
    login('rolf')

    setup_image_dirs
    file = "#{RAILS_ROOT}/test/fixtures/images/Coprinus_comatus.jpg"
    file = FilePlus.new(file)
    file.content_type = 'image/jpeg'

    post(:create_observation,
      :observation => {
        :place_name => '',  # will cause failure
        :when => Time.now,
      },
      :image => { '0' => {
        :image => file,
        :copyright_holder => 'zuul',
        :when => Time.now,
      }}
    )
    assert_response(:success) # success = failure, paradoxically

    # Make sure image was created, but that it is unattached, and that it has
    # been kept in the @good_images array for attachment later.
    img = Image.find_by_copyright_holder('zuul')
    assert(img)
    assert_equal([], img.observations)
    assert_equal([img.id], @controller.instance_variable_get('@good_images').map(&:id))
  end

  def test_project_checkboxes_in_create_observation
    init_for_project_checkbox_tests

    login('rolf')
    get(:create_observation)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)

    login('dick')
    get(:create_observation)
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :unchecked)

    # Should have different default if recently posted observation attached to project.
    obs = Observation.create!
    @proj2.add_observation(obs)
    get(:create_observation)
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :checked)

    # Make sure it remember state of checks if submit fails.
    post(:create_observation,
      :name => {:name => 'Screwy Name'},    # (ensures it will fail)
      :project => {"id_#{@proj1.id}" => ''}
    )
    assert_project_checks(@proj1.id => :no_field, @proj2.id => :unchecked)
  end

  def test_project_checkboxes_in_edit_observation
    init_for_project_checkbox_tests

    login('rolf')
    get(:edit_observation, :id => @obs1.id)
    assert_response(:redirect)
    get(:edit_observation, :id => @obs2.id)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :no_field)
    post(:edit_observation, :id => @obs2.id,
      :observation => { :place_name => 'blah blah blah' },  # (ensures it will fail)
      :project => { "id_#{@proj1.id}" => 'checked' }
    )
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
    post(:edit_observation, :id => @obs2.id,
      :project => { "id_#{@proj1.id}" => 'checked' }
    )
    assert_response(:redirect)
    assert_obj_list_equal([@proj1], @obs2.reload.projects)
    assert_obj_list_equal([@proj1], @img2.reload.projects)

    login('mary')
    get(:edit_observation, :id => @obs2.id)
    assert_project_checks(@proj1.id => :checked, @proj2.id => :no_field)
    get(:edit_observation, :id => @obs1.id)
    assert_project_checks(@proj1.id => :unchecked, @proj2.id => :checked)
    post(:edit_observation, :id => @obs1.id,
      :observation => { :place_name => 'blah blah blah' },  # (ensures it will fail)
      :project => {
        "id_#{@proj1.id}" => 'checked',
        "id_#{@proj2.id}" => '',
      }
    )
    assert_project_checks(@proj1.id => :checked, @proj2.id => :unchecked)
    post(:edit_observation, :id => @obs1.id,
      :project => {
        "id_#{@proj1.id}" => 'checked',
        "id_#{@proj2.id}" => 'checked',
      }
    )
    assert_response(:redirect)
    assert_obj_list_equal([@proj1, @proj2], @obs1.reload.projects.sort_by(&:id))
    assert_obj_list_equal([@proj1, @proj2], @img1.reload.projects.sort_by(&:id))

    login('dick')
    get(:edit_observation, :id => @obs2.id)
    assert_response(:redirect)
    get(:edit_observation, :id => @obs1.id)
    assert_project_checks(@proj1.id => :checked_but_disabled, @proj2.id => :checked)
  end

  def init_for_project_checkbox_tests
    @proj1 = projects(:eol_project)
    @proj2 = projects(:bolete_project)
    @obs1 = observations(:detailed_unknown)
    @obs2 = observations(:coprinus_comatus_obs)
    @img1 = @obs1.images.first
    @img2 = @obs2.images.first
    assert_users_equal(@mary, @obs1.user)
    assert_users_equal(@rolf, @obs2.user)
    assert_users_equal(@mary, @img1.user)
    assert_users_equal(@rolf, @img2.user)
    assert_obj_list_equal([@proj2], @obs1.projects)
    assert_obj_list_equal([], @obs2.projects)
    assert_obj_list_equal([@proj2], @img1.projects)
    assert_obj_list_equal([], @img2.projects)
    assert_obj_list_equal([@rolf, @mary, @katrina], @proj1.user_group.users)
    assert_obj_list_equal([@dick], @proj2.user_group.users)
  end

  def assert_project_checks(project_states)
    for id, state in project_states
      assert_checkbox_state("project_id_#{id}", state)
    end
  end

  def test_list_checkboxes_in_create_observation
    init_for_list_checkbox_tests

    login('rolf')
    get(:create_observation)
    assert_list_checks(@spl1.id => :unchecked, @spl2.id => :no_field)

    login('mary')
    get(:create_observation)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)

    login('katrina')
    get(:create_observation)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :no_field)

    # Dick is on project that owns @spl2.
    login('dick')
    get(:create_observation)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)

    # Should have different default if recently posted observation attached to project.
    obs = Observation.create!
    @spl1.add_observation(obs) # (shouldn't affect anything for create)
    @spl2.add_observation(obs)
    get(:create_observation)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :checked)

    # Make sure it remember state of checks if submit fails.
    post(:create_observation,
      :name => {:name => 'Screwy Name'},    # (ensures it will fail)
      :list => {"id_#{@spl2.id}" => ''}
    )
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :unchecked)
  end

  def test_list_checkboxes_in_edit_observation
    init_for_list_checkbox_tests

    login('rolf')
    get(:edit_observation, :id => @obs1.id)
    assert_list_checks(@spl1.id => :unchecked, @spl2.id => :no_field)
    post(:edit_observation, :id => @obs1.id,
      :observation => { :place_name => 'blah blah blah' },  # (ensures it will fail)
      :list => { "id_#{@spl1.id}" => 'checked' }
    )
    assert_list_checks(@spl1.id => :checked, @spl2.id => :no_field)
    post(:edit_observation, :id => @obs1.id,
      :list => { "id_#{@spl1.id}" => 'checked' }
    )
    assert_response(:redirect)
    assert_obj_list_equal([@spl1], @obs1.reload.species_lists)
    get(:edit_observation, :id => @obs2.id)
    assert_response(:redirect)

    login('mary')
    get(:edit_observation, :id => @obs1.id)
    assert_response(:redirect)
    get(:edit_observation, :id => @obs2.id)
    assert_list_checks(@spl1.id => :no_field, @spl2.id => :checked)
    @spl1.add_observation(@obs2)
    get(:edit_observation, :id => @obs2.id)
    assert_list_checks(@spl1.id => :checked_but_disabled, @spl2.id => :checked)

    login('dick')
    get(:edit_observation, :id => @obs2.id)
    assert_list_checks(@spl1.id => :checked_but_disabled, @spl2.id => :checked)
  end

  def init_for_list_checkbox_tests
    @spl1 = species_lists(:first_species_list)
    @spl2 = species_lists(:unknown_species_list)
    @obs1 = observations(:coprinus_comatus_obs)
    @obs2 = observations(:detailed_unknown)
    assert_users_equal(@rolf, @spl1.user)
    assert_users_equal(@mary, @spl2.user)
    assert_users_equal(@rolf, @obs1.user)
    assert_users_equal(@mary, @obs2.user)
    assert_obj_list_equal([], @obs1.species_lists)
    assert_obj_list_equal([@spl2], @obs2.species_lists)
  end

  def assert_list_checks(list_states)
    for id, state in list_states
      assert_checkbox_state("list_id_#{id}", state)
    end
  end

  # ----------------------------
  #  Interest.
  # ----------------------------

  def test_interest_in_show_observation
    login('rolf')
    minimal_unknown = observations(:minimal_unknown)

    # No interest in this observation yet.
    get(:show_observation, :id => minimal_unknown.id)
    assert_response(:success)
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>[\w\s]*/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => minimal_unknown.id, :state => 1
    )
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>[\w\s]*/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => minimal_unknown.id, :state => -1
    )

    # Turn interest on and make sure there is an icon linked to delete it.
    Interest.create(:target => minimal_unknown, :user => @rolf, :state => true)
    get(:show_observation, :id => minimal_unknown.id)
    assert_response(:success)
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => minimal_unknown.id, :state => 0
    )
    assert_link_in_html(/<img[^>]+ignore\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => minimal_unknown.id, :state => -1
    )

    # Destroy that interest, create new one with interest off.
    Interest.find_all_by_user_id(@rolf.id).last.destroy
    Interest.create(:target => minimal_unknown, :user => @rolf, :state => false)
    get(:show_observation, :id => minimal_unknown.id)
    assert_response(:success)
    assert_link_in_html(/<img[^>]+halfopen\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => minimal_unknown.id, :state => 0
    )
    assert_link_in_html(/<img[^>]+watch\d*.png[^>]+>/,
      :controller => 'interest', :action => 'set_interest',
      :type => 'Observation', :id => minimal_unknown.id, :state => 1
    )
  end

  # ----------------------------
  #  Lookup name.
  # ----------------------------

  def test_lookup_name
    get(:lookup_comment, :id => 1)
    assert_response(:controller => :comment, :action => :show_comment, :id => 1)
    get(:lookup_comment, :id => 10000)
    assert_response(:controller => :comment, :action => :index_comment)
    assert_flash_error

    get(:lookup_image, :id => 1)
    assert_response(:controller => :image, :action => :show_image, :id => 1)
    get(:lookup_image, :id => 10000)
    assert_response(:controller => :image, :action => :index_image)
    assert_flash_error

    get(:lookup_location, :id => 1)
    assert_response(:controller => :location, :action => :show_location, :id => 1)
    get(:lookup_location, :id => 'Burbank, California')
    assert_response(:controller => :location, :action => :show_location, :id => locations(:burbank).id)
    get(:lookup_location, :id => 'California, Burbank')
    assert_response(:controller => :location, :action => :show_location, :id => locations(:burbank).id)
    get(:lookup_location, :id => 'Zyzyx, Califonria')
    assert_response(:controller => :location, :action => :index_location)
    assert_flash_error
    get(:lookup_location, :id => 'California')
    assert_response(:controller => :location, :action => :index_location)
    assert_flash_warning

    get(:lookup_name, :id => 1)
    assert_response(:controller => :name, :action => :show_name, :id => 1)
    get(:lookup_name, :id => names(:coprinus_comatus).id)
    assert_response(:controller => :name, :action => :show_name, :id => names(:coprinus_comatus).id)
    get(:lookup_name, :id => 'Agaricus campestris')
    assert_response(:controller => :name, :action => :show_name, :id => names(:agaricus_campestris).id)
    get(:lookup_name, :id => 'Agaricus newname')
    assert_response(:controller => :name, :action => :index_name)
    assert_flash_error
    get(:lookup_name, :id => 'Amanita baccata sensu Borealis')
    assert_response(:controller => :name, :action => :show_name, :id => names(:amanita_baccata_borealis).id)
    get(:lookup_name, :id => 'Amanita baccata')
    assert_response(:controller => :name, :action => :index_name)
    assert_flash_warning
    get(:lookup_name, :id => 'Agaricus campestris L.')
    assert_response(:controller => :name, :action => :show_name, :id => names(:agaricus_campestris).id)
    get(:lookup_name, :id => 'Agaricus campestris Linn.')
    assert_response(:controller => :name, :action => :show_name, :id => names(:agaricus_campestris).id)

    get(:lookup_project, :id => 1)
    assert_response(:controller => :project, :action => :show_project, :id => 1)
    get(:lookup_project, :id => 'Bolete')
    assert_response(:controller => :project, :action => :show_project, :id => projects(:bolete_project).id)
    get(:lookup_project, :id => 'Bogus')
    assert_response(:controller => :project, :action => :index_project)
    assert_flash_error
    get(:lookup_project, :id => 'project')
    assert_response(:controller => :project, :action => :index_project)
    assert_flash_warning

    get(:lookup_species_list, :id => 1)
    assert_response(:controller => :species_list, :action => :show_species_list, :id => 1)
    get(:lookup_species_list, :id => 'Mysteries')
    assert_response(:controller => :species_list, :action => :show_species_list, :id => species_lists(:unknown_species_list).id)
    get(:lookup_species_list, :id => 'species list')
    assert_response(:controller => :species_list, :action => :index_species_list)
    assert_flash_warning
    get(:lookup_species_list, :id => 'Flibbertygibbets')
    assert_response(:controller => :species_list, :action => :index_species_list)
    assert_flash_error

    get(:lookup_user, :id => 1)
    assert_response(:controller => :observer, :action => :show_user, :id => 1)
    get(:lookup_user, :id => 'mary')
    assert_response(:controller => :observer, :action => :show_user, :id => @mary.id)
    get(:lookup_user, :id => 'Einstein')
    assert_response(:controller => :observer, :action => :index_rss_log)
    assert_flash_error
  end
end
