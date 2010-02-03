require File.dirname(__FILE__) + '/../boot'

class ImageControllerTest < ControllerTestCase

  def test_list_images
    get_with_dump(:list_images)
    assert_response('list_images')
  end

  def test_images_by_user
    get_with_dump(:images_by_user, :id => @rolf.id)
    assert_response('list_images')
  end

  def test_next_image
    get_with_dump(:next_image, :id => 2)
    assert_response(:action => "show_image", :id => 1)
  end

  def test_next_image_ss
    outer = Query.lookup_and_save(:Observation, :in_set, :ids => [2,1,4,3])
    inner = Query.lookup_and_save(:Image, :inside_observation, :outer => outer,
                                  :observation => 2, :by => :id)

    # Make sure the outer query is working right first.
    outer.this_id = 2
    new_outer = outer.next
    assert_equal(outer, new_outer)
    assert_equal(1, outer.this_id)
    assert_equal(0, outer.this.images.size)
    new_outer = outer.next
    assert_equal(outer, new_outer)
    assert_equal(4, outer.this_id)
    assert_equal(1, outer.this.images.size)
    new_outer = outer.next
    assert_equal(outer, new_outer)
    assert_equal(3, outer.this_id)
    assert_equal(1, outer.this.images.size)
    new_outer = outer.next
    assert_equal(nil, new_outer)

    # No more images for obs #2, so goes to next obs (#1), but this has no
    # images, so goes to next (#4), this has one image (#6).  (Shouldn't
    # care that outer query has changed, inner query remembers where it
    # was when inner query was created.)
    inner.this_id = 2
    assert(new_inner = inner.next)
    assert_not_equal(inner, new_inner)
    assert_equal(6, new_inner.this_id)
    save_query = Query.last
    assert(new_new_inner = new_inner.next)
    assert_not_equal(new_inner, new_new_inner)
    assert_equal(5, new_new_inner.this_id)
    assert_nil(new_new_inner.next)

    params = {
      :id => 2,
      :params => @controller.query_params(inner),
    }.flatten
    get(:next_image, params)
    assert_response(:action => "show_image", :id => 6,
                    :params => @controller.query_params(save_query))
  end

  # Test next_image in the context of a search
  def test_next_image_search
    image = Image.find(5)

    # Create simple index.
    query = Query.lookup_and_save(:Image, :by_user, :user => @rolf)
    assert_equal([6, 5, 4, 3], query.result_ids)

    # See what should happen if we look up an Image search and go to next.
    query.this = image
    assert(new_query = query.next)
    assert_equal(query, new_query)
    assert_equal(4, new_query.this_id)

    # Now do it for real.
    params = {
      :id => 5,
      :params => @controller.query_params(query),
    }.flatten
    get(:next_image, params)
    assert_response(:action => "show_image", :id => 4,
                    :params => @controller.query_params(query))
  end

  def test_prev_image
    get_with_dump(:prev_image, :id => 1)
    assert_response(:action => "show_image", :id => 2)
  end

  def test_prev_image_ss
    outer = Query.lookup_and_save(:Observation, :in_set, :ids => [2,1,4,3])
    inner = Query.lookup_and_save(:Image, :inside_observation, :outer => outer,
                                  :observation => 4, :by => :id)

    # Make sure the outer query is working right first.
    outer.this_id = 4
    new_outer = outer.prev
    assert_equal(outer, new_outer)
    assert_equal(1, outer.this_id)
    assert_equal(0, outer.this.images.size)
    new_outer = outer.prev
    assert_equal(outer, new_outer)
    assert_equal(2, outer.this_id)
    assert_equal(2, outer.this.images.size)
    new_outer = outer.prev
    assert_equal(nil, new_outer)

    # No more images for obs #4, so goes to next obs (#1), but this has no
    # images, so goes to next (#2), this has two images (#1 and #2).
    # (Shouldn't care that outer query has changed, inner query remembers where
    # it was when inner query was created.)
    inner.this_id = 6
    assert(new_inner = inner.prev)
    assert_not_equal(inner, new_inner)
    assert_equal(2, new_inner.this_id)
    assert(new_new_inner = new_inner.prev)
    assert_equal(new_inner, new_new_inner)
    assert_equal(1, new_inner.this_id)
    assert_nil(new_inner.prev)

    params = {
      :id => 6,
      :params => @controller.query_params(inner),
    }.flatten
    get(:prev_image, params)
    assert_response(:action => "show_image", :id => 2,
                    :params => @controller.query_params(Query.last))
  end

  def test_show_image
    get_with_dump(:show_image, :id => 1)
    assert_response('show_image')
  end

  def test_show_original
    get_with_dump(:show_original, :id => 1)
    assert_response('show_original')
  end

  def test_image_search
    get_with_dump(:image_search, :pattern => 'Notes')
    assert_response('list_images')
    assert_equal(:query_title_pattern.t(:types => 'Images', :pattern => 'Notes'),
                 @controller.instance_variable_get('@title'))
    get_with_dump(:image_search, :pattern => 'Notes', :page => 2)
    assert_response('list_images')
    assert_equal(:query_title_pattern.t(:types => 'Images', :pattern => 'Notes'),
                 @controller.instance_variable_get('@title'))
  end

  def test_image_search_next
    get_with_dump(:image_search, :pattern => 'Notes')
    assert_response('list_images')
  end

  def test_image_search_by_number
    get_with_dump(:image_search, :pattern => 3)
    assert_response(:action => "show_image", :id => 3)
  end

  def test_advanced_search
    query = Query.lookup_and_save(:Image, :advanced,
      :name => "Don't know",
      :user => "myself",
      :content => "Long pink stem and small pink cap",
      :location => "Eastern Oklahoma"
    )
    get(:advanced_search, @controller.query_params(query))
    assert_response('list_images')
  end

  def test_add_image
    requires_login(:add_image, :id => observations(:coprinus_comatus_obs).id)
    assert_form_action(:action => 'add_image')
    # Check that image cannot be added to an observation the user doesn't own.
    flash[:params] = nil # (disable the spontaneous logout fix!!!)
    get_with_dump(:add_image, :id => observations(:minimal_unknown).id)
    assert_response(:controller => "observer", :action => "show_observation")
  end

  # Test reusing an image by id number.
  def test_add_image_to_obs
    obs = observations(:coprinus_comatus_obs)
    image = images(:disconnected_coprinus_comatus_image)
    assert(!obs.images.member?(image))
    requires_login(:add_image_to_obs, "obs_id" => obs.id, "id" => image.id)
    assert_response(:controller => :observer, :action => :show_observation)
    assert(obs.reload.images.member?(image))
  end

  def test_license_updater
    requires_login(:license_updater)
    assert_form_action(:action => 'license_updater')
  end

  def test_update_licenses
    example_image    = images(:agaricus_campestris_image)
    user_id          = example_image.user_id
    copyright_holder = example_image.copyright_holder

    target_license = example_image.license
    new_license    = licenses(:ccwiki30)
    assert_not_equal(target_license, new_license)

    target_count = Image.find_all_by_user_id_and_license_id_and_copyright_holder(user_id, target_license.id, copyright_holder).length
    new_count    = Image.find_all_by_user_id_and_license_id_and_copyright_holder(user_id, new_license.id, copyright_holder).length
    assert(target_count > 0)
    assert(new_count == 0)

    params = {
      :updates => {
        target_license.id.to_s => {
          copyright_holder => new_license.id.to_s
        }
      }
    }
    post_requires_login(:license_updater, params)
    assert_response('license_updater')
    assert_equal(10, @rolf.reload.contribution)

    target_count_after = Image.find_all_by_user_id_and_license_id_and_copyright_holder(user_id, target_license.id, copyright_holder).length
    new_count_after    = Image.find_all_by_user_id_and_license_id_and_copyright_holder(user_id, new_license.id, copyright_holder).length
    assert(target_count_after < target_count)
    assert(new_count_after > new_count)
    assert_equal(target_count_after + new_count_after, target_count + new_count)
  end

  def test_delete_images
    obs = observations(:detailed_unknown)
    keep = images(:turned_over)
    remove = images(:in_situ)
    assert(obs.images.member?(keep))
    assert(obs.images.member?(remove))
    assert_equal(remove.id, obs.thumb_image_id)

    selected = {}
    selected[keep.id.to_s] = "no"
    selected[remove.id.to_s] = "yes"
    params = {
      :id => obs.id.to_s,
      :selected => selected
    }
    post_requires_login(:remove_images, params, 'mary')
    assert_response(:controller => :observer, :action => :show_observation)
    assert_equal(10, @mary.reload.contribution)
    assert(obs.reload.images.member?(keep))
    assert(!obs.images.member?(remove))
    assert_equal(keep.id, obs.thumb_image_id)

    selected = {}
    selected[keep.id.to_s] = "yes"
    params = {
      :id => obs.id.to_s,
      :selected => selected
    }
    post(:remove_images, params)
    assert_response(:controller => "observer", :action => "show_observation")
    assert_equal(10, @mary.reload.contribution)
    assert(!obs.reload.images.member?(keep))
    assert_equal(nil, obs.thumb_image_id)
  end

  def test_destroy_image
    image = images(:turned_over)
    obs = image.observations.first
    assert(obs.images.member?(image))
    params = { :id => image.id.to_s }
    assert_equal('mary', image.user.login)
    requires_user(:destroy_image, :show_image, params, 'mary')
    assert_response(:action => :list_images)
    assert_equal(0, @mary.reload.contribution)
    assert(!obs.reload.images.member?(image))
  end

  def test_edit_image
    image = images(:connected_coprinus_comatus_image)
    params = { "id" => image.id.to_s }
    assert("rolf" == image.user.login)
    requires_user(:edit_image, ['image', 'show_image'], params)
    assert_form_action :action => 'edit_image'
  end

  def test_update_image
    image = images(:agaricus_campestris_image)
    obs = image.observations.first
    assert(obs)
    assert(obs.rss_log.nil?)

    params = {
      "id" => image.id,
      "image" => {
        "when(1i)" => "2001",
        "copyright_holder" => "Rolf Singer",
        "when(2i)" => "5",
        "when(3i)" => "12",
        "notes" => ""
      }
    }
    post_requires_login(:edit_image, params)
    assert_response(:action => :show_image)
    assert_equal(10, @rolf.reload.contribution)

    assert(obs.reload.rss_log)
    assert(obs.rss_log.notes.include?('log_image_updated'))
    assert(obs.rss_log.notes.include?("user=#{obs.user.login}"))
    assert(obs.rss_log.notes.include?("name=#{RssLog.escape(image.unique_format_name)}"))
  end

  def test_remove_images
    obs = observations(:coprinus_comatus_obs)
    params = { :id => obs.id }
    assert_equal('rolf', obs.user.login)
    requires_user(:remove_images, [:observer, :show_observation], params)
    assert_form_action(:action => 'remove_images')
  end

  def test_resize_images
    requires_login(:resize_images)
    assert_response(:action => :list_images)
    assert_flash(:image_resize_denied.t)
    # How should real image files be handled?
  end

  def test_reuse_image
    obs = observations(:agaricus_campestris_obs)
    params = { :id => obs.id }
    assert_equal('rolf', obs.user.login)
    requires_user(:reuse_image, [:observer, :show_observation], params)
    assert_form_action(:action => 'reuse_image_by_id', :id => obs.id)
  end

  def test_reuse_image_by_id
    obs = observations(:agaricus_campestris_obs)
    image = images(:commercial_inquiry_image)
    assert(!obs.images.member?(image))
    params = {
      :observation => {
        :id => obs.id,
        :idstr => "3"
      }
    }
    owner = obs.user.login
    assert_not_equal('mary', owner)
    requires_login(:reuse_image_by_id, params, "mary")
    assert_response(:controller => :observer, :action => :show_observation)
    assert(!obs.reload.images.member?(image))

    login(owner)
    get_with_dump(:reuse_image_by_id, params)
    assert_response(:controller => "observer", :action => "show_observation")
    assert(obs.reload.images.member?(image))
  end

  def test_upload_image
    FileUtils.cp_r(IMG_DIR.gsub(/test_images$/, 'setup_images'), IMG_DIR)
    obs = observations(:coprinus_comatus_obs)
    img_count = obs.images.size
    file = FilePlus.new("#{RAILS_ROOT}/test/fixtures/images/Coprinus_comatus.jpg")
    file.content_type = 'image/jpeg'
    params = {
      :id => obs.id,
      :image => {
        "when(1i)" => "2007",
        "when(2i)"=>"3",
        "when(3i)"=>"29",
        :copyright_holder => "Douglas Smith",
        :notes => "Some notes."
      },
      :upload => {
        :image1 => file,
        :image2 => '',
        :image3 => '',
        :image4 => ''
      }
    }
    post_requires_user(:add_image, [:observer, :show_observation], params)
    assert_response(:controller => :observer, :action => :show_observation)
    assert_equal(20, @rolf.reload.contribution)
    assert(obs.reload.images.size == (img_count + 1))
    assert_flash(:profile_uploaded_image.t(:name => "##{obs.images.last.id}"))
  end

  # This is what would happen when user first opens form.
  def test_reuse_image_for_user
    requires_login(:reuse_image_for_user)
    assert_response('reuse_image_for_user')
    assert_form_action(:action => 'reuse_image_for_user')
  end

  # This would happen if user clicked on image.
  def test_reuse_image_for_user_post1
    image = images(:commercial_inquiry_image)
    params = { :id => image.id.to_s }
    requires_login(:reuse_image_for_user, params)
    assert_response(:controller => :observer, :action => :show_user,
                    :id => @rolf.id)
    assert_equal(@rolf.id, session[:user_id])
    assert_equal(image.id, @rolf.reload.image_id)
  end

  # This would happen if user typed in id and submitted.
  def test_reuse_image_for_user_post2
    image = images(:commercial_inquiry_image)
    params = { :id => image.id.to_s }
    post_requires_login(:reuse_image_for_user, params)
    assert_response(:controller => :observer, :action => :show_user,
                    :id => @rolf.id)
    assert_equal(@rolf.id, session[:user_id])
    assert_equal(image.id, @rolf.reload.image_id)
  end
end
