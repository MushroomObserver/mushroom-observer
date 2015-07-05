# encoding: utf-8
require "test_helper"
require "json"

class AjaxControllerTest < FunctionalTestCase

  # Create test image dirs for tests that do image uploads.
  def setup_image_dirs
    if not FileTest.exist?(MO.local_image_files)
      setup_images = MO.local_image_files.gsub(/test_images$/, "setup_images")
      FileUtils.cp_r(setup_images, MO.local_image_files)
    end
  end

  def good_ajax_request(action, params={})
    ajax_request(action, params, 200)
  end

  def bad_ajax_request(action, params={})
    ajax_request(action, params, 500)
  end

  def ajax_request(action, params, status)
    get(action, params.dup)
    if @response.response_code != status
      url = ajax_request_url(action, params)
      msg = "Expected #{status} from: #{url}\n"
      msg += "Got #{@response.response_code}:\n"
      msg += @response.body
      flunk(msg)
    else
      pass
    end
  end

  def ajax_request_url(action, params)
    url = "/ajax/#{action}"
    url += "/#{params[:type]}" if params[:type]
    url += "/#{params[:id]}"   if params[:id]
    args = []
    for var, val in params
      if var != :type and var != :id
        args << "#{var}=#{val}"
      end
    end
    url += "?" + args.join("&") if args.any?
    return url
  end

################################################################################

  # This is a good place to test this stuff, since the filters are simplified.
  def test_filters
    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,pt;q=0.5"
    good_ajax_request(:test)
    assert_nil(@controller.instance_variable_get("@user"))
    assert_nil(User.current)
    assert_equal(:pt, I18n.locale)
    assert_equal(0, cookies.count)
    assert_equal({"locale"=>"pt"}, session.to_hash)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,xx-xx;q=0.5"
    good_ajax_request(:test)
    assert_equal(:pt, I18n.locale)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,en;q=0.5"
    good_ajax_request(:test)
    assert_equal(:pt, I18n.locale)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "en-xx,en;q=0.5"
    good_ajax_request(:test)
    assert_equal(:en, I18n.locale)

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "zh-*"
    good_ajax_request(:test)
    assert_equal(:en, I18n.locale)
  end

  def test_activate_api_key
    key = ApiKey.new
    key.provide_defaults
    key.verified = nil
    key.user = katrina
    key.notes = "testing"
    key.save!
    assert_nil(key.reload.verified)

    bad_ajax_request(:api_key, type: :activate, id: key.id)
    assert_nil(key.reload.verified)

    login("dick")
    bad_ajax_request(:api_key, type: :activate, id: key.id)
    assert_nil(key.reload.verified)

    login("katrina")
    bad_ajax_request(:api_key, type: :activate)
    bad_ajax_request(:api_key, type: :activate, id: 12345)
    good_ajax_request(:api_key, type: :activate, id: key.id)
    assert_equal("", @response.body)
    assert_not_nil(key.reload.verified)
  end

  def test_edit_api_key
    key = ApiKey.new
    key.provide_defaults
    key.verified = Time.now
    key.user = katrina
    key.notes = "testing"
    key.save!
    assert_equal("testing", key.notes)

    bad_ajax_request(:api_key, type: :edit, id: key.id, value: "new notes")
    assert_equal("testing", key.reload.notes)

    login("dick")
    bad_ajax_request(:api_key, type: :edit, id: key.id, value: "new notes")
    assert_equal("testing", key.reload.notes)

    login("katrina")
    bad_ajax_request(:api_key, type: :edit)
    bad_ajax_request(:api_key, type: :edit, id: 12345)
    bad_ajax_request(:api_key, type: :edit, id: key.id)
    assert_equal("testing", key.reload.notes)
    good_ajax_request(:api_key, type: :edit, id: key.id, value: " new notes ")
    assert_equal("new notes", key.reload.notes)
  end

  def test_auto_complete_location
    mitrula = locations(:mitrula_marsh).name
    reyes = locations(:point_reyes).name
    pipi = observations(:strobilurus_diminutivus_obs).where

    expect = [mitrula, reyes, pipi].sort
    expect.unshift("M")
    good_ajax_request(:auto_complete, type: :location, id: "Modesto")
    assert_equal(expect, @response.body.split("\n"))

    expect = [mitrula, reyes, pipi].map {|x| Location.reverse_name(x)}.sort
    expect.unshift("M")
    good_ajax_request(:auto_complete, type: :location, id: "Modesto", format: "scientific")
    assert_equal(expect, @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :location, id: "Xystus")
    assert_equal(["X"], @response.body.split("\n"))
  end

  def test_auto_complete_name
    expect = Name.all.reject(&:correct_spelling).
                  map(&:text_name).uniq.select {|n| n[0] == "A"}.sort
    expect.unshift("A")
    good_ajax_request(:auto_complete, type: :name, id: "Agaricus")
    assert_equal(expect, @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :name, id: "Xystus")
    assert_equal(["X"], @response.body.split("\n"))
  end

  def test_auto_complete_project
    eol = projects(:eol_project).title
    bolete = projects(:bolete_project).title

    good_ajax_request(:auto_complete, type: :project, id: "Babushka")
    assert_equal(["B", bolete], @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :project, id: "Perfidy")
    assert_equal(["P", bolete, eol], @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :project, id: "Xystus")
    assert_equal(["X"], @response.body.split("\n"))
  end

  def test_auto_complete_species_list
    list1, list2, list3 = SpeciesList.all.map(&:title)
    assert_equal("A Species List", list1)
    assert_equal('Another Species List', list2)
    assert_equal('List of mysteries', list3)

    good_ajax_request(:auto_complete, type: :species_list, id: "List")
    assert_equal(["L", list1, list2, list3], @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :species_list, id: "Mojo")
    assert_equal(["M", list3], @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :species_list, id: "Xystus")
    assert_equal(["X"], @response.body.split("\n"))
  end

  def test_auto_complete_user
    good_ajax_request(:auto_complete, type: :user, id: "Rover")
    assert_equal(["R", 'rolf <Rolf Singer>', 'roy <Roy Halling>'],
                 @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :user, id: "Dodo")
    assert_equal(["D", 'dick <Tricky Dick>'], @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :user, id: "Komodo")
    assert_equal(["K", 'katrina <Katrina>'], @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :user, id: "Xystus")
    assert_equal(["X"], @response.body.split("\n"))
  end

  def test_auto_complete_bogus
    bad_ajax_request(:auto_complete, type: :bogus, id: "bogus")
  end

  def test_export_image
    img = images(:in_situ)
    assert_true(img.ok_for_export) # (default)

    bad_ajax_request(:export, type: :image, id: img.id, value: "0")

    login("rolf")
    good_ajax_request(:export, type: :image, id: img.id, value: "0")
    assert_false(img.reload.ok_for_export)

    good_ajax_request(:export, type: :image, id: img.id, value: "1")
    assert_true(img.reload.ok_for_export)

    bad_ajax_request(:export, type: :image, id: 999, value: "1")
    bad_ajax_request(:export, type: :image, id: img.id, value: "2")
    bad_ajax_request(:export, type: :user, id: 1, value: "1")
  end

  def test_geocode_address
    check_address("North Falmouth, Massachusetts, USA", "postal", true)
    check_address("USA, Massachusetts, North Falmouth", "scientific", true)
    check_address("Foo, Bar, Baz", "postal", false)

    # This address is special since Google only likes in the following order
    address = "North bound Rest Area, State Highway 33, " \
              "between Pomeroy and Athens, Ohio, USA"
    check_address(address, "postal", true)
    check_address(address, "scientific", false)
    check_address(Location.reverse_name(address), "postal", false)
    check_address(Location.reverse_name(address), "scientific", true)
  end

  def check_address(name, format, good)
    p = { name: name, format: format }
    good_ajax_request(:geocode, p)
    assert(@response.body)
    if good
      assert_equal(4, @response.body.split("\n").length)
      @response.body.split("\n").each do |s|
        assert(s.to_f != 0.0)
      end
    else
      assert_equal(0, @response.body.split("\n").length)
    end
  end

  def test_get_pivotal_story
    if MO.pivotal_enabled
      good_ajax_request(:pivotal, type: "story", id: MO.pivotal_test_id)
      assert_match(/This is a test story/, @response.body)
      assert_match(/Posted by.*rolf/, @response.body)
      assert_match(/This is a test comment/, @response.body)
      assert_match(/By:.*mary/, @response.body)
      assert_match(/Post Comment/, @response.body)
    end
  end

  def test_naming_vote
    naming = Naming.find(1)
    assert_nil(naming.users_vote(dick))
    bad_ajax_request(:vote, type: :naming, id: 1, value: 3)

    login("dick")
    good_ajax_request(:vote, type: :naming, id: 1, value: 3)
    assert_equal(3, naming.reload.users_vote(dick).value)

    good_ajax_request(:vote, type: :naming, id: 1, value: 0)
    assert_nil(naming.reload.users_vote(dick))

    bad_ajax_request(:vote, type: :naming, id: 1, value: 99)
    bad_ajax_request(:vote, type: :naming, id: 99, value: 0)
    bad_ajax_request(:vote, type: :phooey, id: 1, value: 0)
  end

  def test_image_vote
    image = Image.find(1)
    assert_nil(image.users_vote(dick))
    bad_ajax_request(:vote, type: :image, id: 1, value: 3)

    login("dick")
    assert_nil(image.users_vote(dick))
    good_ajax_request(:vote, type: :image, id: 1, value: 3)
    assert_equal(3, image.reload.users_vote(dick))

    good_ajax_request(:vote, type: :image, id: 1, value: 0)
    assert_nil(image.reload.users_vote(dick))

    bad_ajax_request(:vote, type: :image, id: 1, value: 99)
    bad_ajax_request(:vote, type: :image, id: 99, value: 0)
  end

  def test_image_vote_renders_partial
    ##Arrange
    login("dick")

    #Act
    good_ajax_request(:vote, type: :image, id: 1, value: 3)

    #Assert
    assert_template layout: nil
    assert_template layout: false
    assert_template partial: 'image/_image_vote_links'
  end

  def test_image_vote_renders_correct_links
    ##Arrange
    login("dick")

    #Act
    good_ajax_request(:vote, type: :image, id: 1, value: 3)

    assert_tag "a", attributes: {
                      href: "/image/show_image/1?vote=0"
                  }
    assert_tag "a", attributes: {
                      href: "/image/show_image/1?vote=1"
                  }
    assert_tag "a", attributes: {
                      href: "/image/show_image/1?vote=2"
                  }
    assert_tag "a", attributes: {
                      href: "/image/show_image/1?vote=4"
                  }
  end

  def test_image_vote_renders_correct_data_attributes
    ##Arrange
    login("dick")

    #Act
    good_ajax_request(:vote, type: :image, id: 1, value: 3)

    assert_select("[data-role='image_vote']", 4)  ##should show four vote links as dick already voted
    assert_select("[data-val]", 4)  ##should show four vote links as dick already voted
  end

  def test_old_translation
    str = TranslationString::Version.find(1)
    bad_ajax_request(:old_translation, id: 0)
    good_ajax_request(:old_translation, id: 1)
    assert_equal(str.text, @response.body)
  end

  def test_upload_image
    #Arrange
    setup_image_dirs
    login("dick")
    file = Rack::Test::UploadedFile.new("#{::Rails.root}/test/images/Coprinus_comatus.jpg",
    "image/jpeg")
    copyright_holder = "Douglas Smith"
    notes = "Some notes."

    params = {
        image: {
            when: {"3i"=> "27", "2i"=> "11", "1i"=> "2014"},
            copyright_holder: copyright_holder,
            notes: notes,
            upload: file
        }
    }

    #Act
    post(:create_image_object, params)
    @json_response = JSON.parse(@response.body)

    #Assert
    assert_response(:success)
    refute_equal(0, @json_response["id"])
    assert_equal(copyright_holder, @json_response["copyright_holder"])
    assert_equal(notes, @json_response["notes"])
    assert_equal("2014-11-27", @json_response["when"])
  end

  def test_get_multi_image_template
    bad_ajax_request(:get_multi_image_template)
    login("dick")
    good_ajax_request(:get_multi_image_template)
  end
end
