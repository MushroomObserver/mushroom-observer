# frozen_string_literal: true

require("test_helper")
require("json")

class AjaxControllerTest < FunctionalTestCase
  def good_ajax_request(action, params = {})
    ajax_request(action, params, 200)
  end

  def bad_ajax_request(action, params = {})
    ajax_request(action, params, 500)
  end

  def ajax_request(action, params, status)
    get(action, params: params.dup)
    if @response.response_code == status
      pass
    else
      url = ajax_request_url(action, params)
      msg = "Expected #{status} from: #{url}\n"
      msg += "Got #{@response.response_code}:\n"
      msg += @response.body
      flunk(msg)
    end
  end

  def ajax_request_url(action, params)
    url = "/ajax/#{action}"
    url += "/#{params[:type]}" if params[:type]
    url += "/#{params[:id]}"   if params[:id]
    args = params.except(:type, :id)
    url += "?#{URI.encode_www_form(args)}" if args.any?
    url
  end

  ##############################################################################

  # This is a good place to test this stuff, since the filters are simplified.
  def test_filters
    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,pt;q=0.5"
    good_ajax_request(:test)
    assert_nil(@controller.instance_variable_get(:@user))
    assert_nil(User.current)
    assert_equal(:pt, I18n.locale)
    assert_equal(0, cookies.count)
    assert_equal({ "locale" => "pt" }, session.to_hash)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,xx-xx;q=0.5"
    good_ajax_request(:test)
    assert_equal(:pt, I18n.locale)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "pt-pt,en;q=0.5"
    good_ajax_request(:test)
    assert_equal(:pt, I18n.locale)
    session.delete("locale")

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "xx-xx,pt-pt"
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
    key = APIKey.new
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
    bad_ajax_request(:api_key, type: :activate, id: 12_345)
    good_ajax_request(:api_key, type: :activate, id: key.id)
    assert_equal("", @response.body)
    assert_not_nil(key.reload.verified)
  end

  def test_edit_api_key
    key = APIKey.new
    key.provide_defaults
    key.verified = Time.zone.now
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
    bad_ajax_request(:api_key, type: :edit, id: 12_345)
    bad_ajax_request(:api_key, type: :edit, id: key.id)
    assert_equal("testing", key.reload.notes)
    good_ajax_request(:api_key, type: :edit, id: key.id, value: " new notes ")
    assert_equal("new notes", key.reload.notes)
  end

  def test_auto_complete_location
    # names of Locations whose names have words starting with "m"
    m_loc_names = Location.where("name REGEXP ?", "\\bM").
                  map(&:name)
    # wheres of Observations whose wheres have words starting with "m"
    # need extra "observation" to avoid confusing sql with bare "where".
    m_obs_wheres = Observation.where("observations.where REGEXP ?", "\\bM").
                   map(&:where)
    m = m_loc_names + m_obs_wheres

    expect = m.sort.uniq
    expect.unshift("M")
    good_ajax_request(:auto_complete, type: :location, id: "Modesto")
    assert_equal(expect, @response.body.split("\n"))

    login("roy") # prefers location_format: :scientific
    expect = m.map { |x| Location.reverse_name(x) }.sort.uniq
    expect.unshift("M")
    good_ajax_request(:auto_complete, type: :location, id: "Modesto")
    assert_equal(expect, @response.body.split("\n"))

    login("mary") # prefers location_format: :postal
    good_ajax_request(:auto_complete, type: :location, id: "Xystus")
    assert_equal(["X"], @response.body.split("\n"))
  end

  def test_auto_complete_name
    expect = Name.all.reject(&:correct_spelling).
             map(&:text_name).uniq.select { |n| n[0] == "A" }.sort
    expect_genera = expect.reject { |n| n.include?(" ") }
    expect_species = expect.select { |n| n.include?(" ") }
    expect = ["A"] + expect_genera + expect_species
    good_ajax_request(:auto_complete, type: :name, id: "Agaricus")
    assert_equal(expect, @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :name, id: "Umbilicaria")
    assert_equal(["U"], @response.body.split("\n"))
  end

  def test_auto_complete_project
    # titles of Projects whose titles have words starting with "p"
    b_titles = Project.where("title REGEXP ?", "\\bb").map(&:title).uniq
    good_ajax_request(:auto_complete, type: :project, id: "Babushka")
    assert_equal((["B"] + b_titles).sort, @response.body.split("\n").sort)

    p_titles = Project.where("title REGEXP ?", "\\bp").map(&:title).uniq
    good_ajax_request(:auto_complete, type: :project, id: "Perfidy")
    assert_equal((["P"] + p_titles).sort, @response.body.split("\n").sort)

    good_ajax_request(:auto_complete, type: :project, id: "Xystus")
    assert_equal(["X"], @response.body.split("\n"))
  end

  def test_auto_complete_species_list
    list1, list2, list3 = SpeciesList.all.order(:title).map(&:title)

    assert_equal("A Species List", list1)
    assert_equal("Another Species List", list2)
    assert_equal("List of mysteries", list3)

    good_ajax_request(:auto_complete, type: :species_list, id: "List")
    assert_equal(["L", list1, list2, list3], @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :species_list, id: "Mojo")
    assert_equal(["M", list3], @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :species_list, id: "Xystus")
    assert_equal(["X"], @response.body.split("\n"))
  end

  def test_auto_complete_user
    good_ajax_request(:auto_complete, type: :user, id: "Rover")
    assert_equal(
      ["R", "rolf <Rolf Singer>", "roy <Roy Halling>",
       "second_roy <Roy Rogers>"],
      @response.body.split("\n")
    )

    good_ajax_request(:auto_complete, type: :user, id: "Dodo")
    assert_equal(["D", "dick <Tricky Dick>"], @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :user, id: "Komodo")
    assert_equal(["K", "#{katrina.login} <#{katrina.name}>"],
                 @response.body.split("\n"))

    good_ajax_request(:auto_complete, type: :user, id: "Xystus")
    assert_equal(["X"], @response.body.split("\n"))
  end

  def test_auto_complete_bogus
    bad_ajax_request(:auto_complete, type: :bogus, id: "bogus")
  end

  def test_export_image
    img = images(:in_situ_image)
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

  def test_get_pivotal_story
    return unless MO.pivotal_enabled

    good_ajax_request(:pivotal, type: "story", id: MO.pivotal_test_id)
    assert_match(/This is a test story/, @response.body)
    assert_match(/Posted by.*rolf/, @response.body)
    assert_match(/This is a test comment/, @response.body)
    assert_match(/By:.*mary/, @response.body)
    assert_match(/Post Comment/, @response.body)
  end

  def test_old_translation
    str = TranslationString::Version.find(1)
    bad_ajax_request(:old_translation, id: 0)
    good_ajax_request(:old_translation, id: 1)
    assert_equal(str.text, @response.body)
  end

  def test_upload_image
    # Arrange
    setup_image_dirs
    login("dick")
    file = Rack::Test::UploadedFile.new(
      Rails.root.join("test/images/Coprinus_comatus.jpg").to_s, "image/jpeg"
    )
    copyright_holder = "Douglas Smith"
    notes = "Some notes."

    params = {
      image: {
        when: { "3i" => "27", "2i" => "11", "1i" => "2014" },
        copyright_holder: copyright_holder,
        notes: notes,
        upload: file
      }
    }

    # Act
    File.stub(:rename, false) do
      post(:create_image_object, params: params)
    end
    @json_response = JSON.parse(@response.body)

    # Assert
    assert_response(:success)
    assert_not_equal(0, @json_response["id"])
    assert_equal(copyright_holder, @json_response["copyright_holder"])
    assert_equal(notes, @json_response["notes"])
    assert_equal("2014-11-27", @json_response["when"])
  end

  def test_multi_image_template
    bad_ajax_request(:multi_image_template)
    login("dick")
    good_ajax_request(:multi_image_template)
  end

  def test_add_external_link
    obs  = observations(:agaricus_campestris_obs) # owned by rolf
    obs2 = observations(:agaricus_campestrus_obs) # owned by rolf
    site = ExternalSite.first
    url  = "http://valid.url"
    params = {
      type: "add",
      id: obs.id,
      site: site.id,
      value: url
    }

    # not logged in
    bad_ajax_request(:external_link, params)

    # dick can't do it
    login("dick")
    bad_ajax_request(:external_link, params)

    # rolf can because he owns it
    login("rolf")
    good_ajax_request(:external_link, params)
    assert_equal(@response.body, ExternalLink.last.id.to_s)
    assert_users_equal(rolf, ExternalLink.last.user)
    assert_objs_equal(obs, ExternalLink.last.observation)
    assert_objs_equal(site, ExternalLink.last.external_site)
    assert_equal(url, ExternalLink.last.url)

    # bad url
    login("mary")
    bad_ajax_request(:external_link, params.merge(value: "bad url"))

    # mary can because she's a member of the external site's project
    login("mary")
    good_ajax_request(:external_link, params.merge(id: obs2.id))
    assert_equal(@response.body, ExternalLink.last.id.to_s)
    assert_users_equal(mary, ExternalLink.last.user)
    assert_objs_equal(obs2, ExternalLink.last.observation)
    assert_objs_equal(site, ExternalLink.last.external_site)
    assert_equal(url, ExternalLink.last.url)
  end

  def test_edit_external_link
    # obs owned by rolf, mary created link and is member of site's project
    link    = ExternalLink.first
    new_url = "http://another.valid.url"
    params = {
      type: "edit",
      id: link.id,
      value: new_url
    }

    # not logged in
    bad_ajax_request(:external_link, params)

    # dick doesn't have permission
    login("dick")
    bad_ajax_request(:external_link, params)

    # mary can
    login("mary")
    good_ajax_request(:external_link, params)
    assert_equal(new_url, link.reload.url)

    # rolf can, too
    login("rolf")
    good_ajax_request(:external_link, params)

    # bad url
    bad_ajax_request(:external_link, params.merge(value: "bad url"))
  end

  def test_remove_external_link
    # obs owned by rolf, mary created link and is member of site's project
    link   = ExternalLink.first
    params = {
      type: "remove",
      id: link.id
    }

    # not logged in
    bad_ajax_request(:external_link, params)

    # dick doesn't have permission
    login("dick")
    bad_ajax_request(:external_link, params)

    # mary can
    login("mary")
    good_ajax_request(:external_link, params)
    assert_nil(ExternalLink.safe_find(link.id))
  end

  def test_check_link_permission
    # obs owned by rolf, mary member of site project
    site = external_sites(:mycoportal)
    obs  = observations(:coprinus_comatus_obs)
    link = external_links(:coprinus_comatus_obs_mycoportal_link)
    @controller.instance_variable_set(:@user, rolf)
    assert_link_allowed(link)
    assert_link_allowed(obs, site)
    @controller.instance_variable_set(:@user, mary)
    assert_link_allowed(link)
    assert_link_allowed(obs, site)
    @controller.instance_variable_set(:@user, dick)
    assert_link_forbidden(link)
    assert_link_forbidden(obs, site)

    dick.update(admin: true)
    assert_link_allowed(link)
    assert_link_allowed(obs, site)
  end

  def assert_link_allowed(*args)
    assert_nothing_raised do
      @controller.send(:check_link_permission!, *args)
    end
  end

  def assert_link_forbidden(*args)
    assert_raises(RuntimeError) do
      @controller.send(:check_link_permission!, *args)
    end
  end

  def test_name_primer
    # This name is not deprecated and is used by an observation or two.
    name1 = names(:boletus_edulis)
    item1 = build_name_primer_item(name1)

    # This name is not deprecated and not used by an observation, but a
    # synonym *is* used by an observation, so it should be included.
    name2 = names(:chlorophyllum_rhacodes)
    item2 = build_name_primer_item(name2)

    # This name is deprecated but is used by an observation so it should
    # be included.
    name3 = names(:coprinus_comatus)
    name3.update_attribute(:deprecated, true)
    name3.reload
    item3 = build_name_primer_item(name3)

    get(:name_primer)
    # These assertions may not be stable, in which case we may need to parse
    # the respond body as JSON structure, and test that the structure contains
    # the right elements.
    assert(@response.body.include?(item1),
           "Expected #{@response.body} to include #{item1}.")
    assert(@response.body.include?(item2),
           "Expected #{@response.body} to include #{item2}.")
    assert(@response.body.include?(item3),
           "Expected #{@response.body} to include #{item3}.")
    assert_not(@response.body.include?("Lactarius alpigenes"),
               "Didn't expect primer to include Lactarius alpigenes.")
  end

  def build_name_primer_item(name)
    { id: name.id,
      text_name: name.text_name,
      author: name.author,
      deprecated: name.deprecated,
      synonym_id: name.synonym_id }.to_json
  end

  def test_location_primer
    loc = locations(:burbank)
    item = { id: loc.id, name: loc.name }.to_json
    get(:location_primer)
    assert(@response.body.include?(item),
           "Expected #{@response.body} to include #{item}.")
  end

  def test_visual_group_flip_status
    login
    visual_group = visual_groups(:visual_group_one)
    image = images(:agaricus_campestris_image)
    vgi = visual_group.visual_group_images.find_by(image_id: image.id)
    new_status = !vgi.included
    get(:visual_group_status,
        params: { id: visual_group.id, imgid: image.id, value: new_status })
    vgi.reload
    assert_equal(new_status, vgi.included)
  end

  def test_visual_group_delete_relationship
    login
    visual_group = visual_groups(:visual_group_one)
    image = images(:agaricus_campestris_image)
    count = VisualGroupImage.count
    get(:visual_group_status,
        params: { id: visual_group.id, imgid: image.id, value: "" })
    assert_equal(count - 1, VisualGroupImage.count)
  end

  def test_visual_group_add_relationship
    login
    visual_group = visual_groups(:visual_group_one)
    image = images(:peltigera_image)
    count = VisualGroupImage.count
    get(:visual_group_status,
        params: { id: visual_group.id, imgid: image.id, value: "true" })
    assert_equal(count + 1, VisualGroupImage.count)
  end
end
