# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

class AjaxControllerTest < FunctionalTestCase

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
      assert_block(msg) {false}
    else
      assert_block('') {true}
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
    url += '?' + args.join('&') if args.any?
    return url
  end

################################################################################

  # This is a good place to test this stuff, since the filters are simplified.
  def test_filters
    @request.env['HTTP_ACCEPT_LANGUAGE'] = "pt-pt,pt;q=0.5"
    good_ajax_request(:test)
    assert_nil(@controller.instance_variable_get('@user'))
    assert_nil(User.current)
    assert_equal(:'pt-BR', Locale.code)
    assert_equal({}, cookies)
    assert_equal({'locale'=>'pt-BR','flash'=>{}}, session.data)
    session.data.delete('locale')

    @request.env['HTTP_ACCEPT_LANGUAGE'] = "pt-pt,xx-xx;q=0.5"
    good_ajax_request(:test)
    assert_equal(:'pt-BR', Locale.code)
    session.data.delete('locale')

    @request.env['HTTP_ACCEPT_LANGUAGE'] = "pt-pt,en;q=0.5"
    good_ajax_request(:test)
    assert_equal(:'en-US', Locale.code)
    session.data.delete('locale')

    @request.env['HTTP_ACCEPT_LANGUAGE'] = "en-xx,en;q=0.5"
    good_ajax_request(:test)
    assert_equal(:'en-US', Locale.code)

    @request.env['HTTP_ACCEPT_LANGUAGE'] = "zh-*"
    good_ajax_request(:test)
    assert_equal(:'en-US', Locale.code)
  end

  def test_auto_complete_location
    mitrula = locations(:mitrula_marsh).name
    reyes = locations(:point_reyes).name
    pipi = observations(:strobilurus_diminutivus_obs).where

    expect = [mitrula, reyes, pipi].sort
    expect.unshift('M')
    good_ajax_request(:auto_complete, :type => :location, :id => 'Modesto')
    assert_equal(expect, @response.body.split("\n"))

    expect = [mitrula, reyes, pipi].map {|x| Location.reverse_name(x)}.sort
    expect.unshift('M')
    good_ajax_request(:auto_complete, :type => :location, :id => 'Modesto', :format => 'scientific')
    assert_equal(expect, @response.body.split("\n"))

    good_ajax_request(:auto_complete, :type => :location, :id => 'Xystus')
    assert_equal(['X'], @response.body.split("\n"))
  end

  def test_auto_complete_name
    expect = Name.all.reject(&:correct_spelling).map(&:text_name).uniq.select {|n| n[0] == 'A'}.sort
    expect.unshift('A')
    good_ajax_request(:auto_complete, :type => :name, :id => 'Agaricus')
    assert_equal(expect, @response.body.split("\n"))

    good_ajax_request(:auto_complete, :type => :name, :id => 'Xystus')
    assert_equal(['X'], @response.body.split("\n"))
  end

  def test_auto_complete_project
    eol = projects(:eol_project).title
    bolete = projects(:bolete_project).title

    good_ajax_request(:auto_complete, :type => :project, :id => 'Babushka')
    assert_equal(['B', bolete], @response.body.split("\n"))

    good_ajax_request(:auto_complete, :type => :project, :id => 'Perfidy')
    assert_equal(['P', bolete, eol], @response.body.split("\n"))

    good_ajax_request(:auto_complete, :type => :project, :id => 'Xystus')
    assert_equal(['X'], @response.body.split("\n"))
  end

  def test_auto_complete_species_list
    list1, list2, list3 = SpeciesList.all.map(&:title)
    assert_equal('A Species List', list1)
    assert_equal('Another Species List', list2)
    assert_equal('List of mysteries', list3)

    good_ajax_request(:auto_complete, :type => :species_list, :id => 'List')
    assert_equal(['L', list1, list2, list3], @response.body.split("\n"))

    good_ajax_request(:auto_complete, :type => :species_list, :id => 'Mojo')
    assert_equal(['M', list3], @response.body.split("\n"))

    good_ajax_request(:auto_complete, :type => :species_list, :id => 'Xystus')
    assert_equal(['X'], @response.body.split("\n"))
  end

  def test_auto_complete_user
    # @rolf    - Rolf Singer
    # @mary    - Mary Newbie
    # @junk    - Junk Box
    # @dick    - Tricky Dick
    # @katrina - Katrina
    # @roy     - Roy Halling

    good_ajax_request(:auto_complete, :type => :user, :id => 'Rover')
    assert_equal(['R', 'rolf <Rolf Singer>', 'roy <Roy Halling>'], @response.body.split("\n"))

    good_ajax_request(:auto_complete, :type => :user, :id => 'Dodo')
    assert_equal(['D', 'dick <Tricky Dick>'], @response.body.split("\n"))

    good_ajax_request(:auto_complete, :type => :user, :id => 'Komodo')
    assert_equal(['K', 'katrina <Katrina>'], @response.body.split("\n"))

    good_ajax_request(:auto_complete, :type => :user, :id => 'Xystus')
    assert_equal(['X'], @response.body.split("\n"))
  end

  def test_auto_complete_bogus
    bad_ajax_request(:auto_complete, :type => :bogus, :id => 'bogus')
  end

  def test_export_image
    img = images(:in_situ)
    assert_true(img.ok_for_export) # (default)

    bad_ajax_request(:export, :type => :image, :id => img.id, :value => '0')

    login('rolf')
    good_ajax_request(:export, :type => :image, :id => img.id, :value => '0')
    assert_false(img.reload.ok_for_export)

    good_ajax_request(:export, :type => :image, :id => img.id, :value => '1')
    assert_true(img.reload.ok_for_export)

    bad_ajax_request(:export, :type => :image, :id => 999, :value => '1')
    bad_ajax_request(:export, :type => :image, :id => img.id, :value => '2')
    bad_ajax_request(:export, :type => :user, :id => 1, :value => '1')
  end

  def test_geocode_address
    check_address("North Falmouth, Massachusetts, USA", "postal", true)
    check_address("USA, Massachusetts, North Falmouth", "scientific", true)
    check_address("Foo, Bar, Baz", "postal", false)

    # This address is special since Google only likes in the following order
    address = "North bound Rest Area, State Highway 33, between Pomeroy and Athens, Ohio, USA"
    check_address(address, "postal", true)
    check_address(address, "scientific", false)
    check_address(Location.reverse_name(address), "postal", false)
    check_address(Location.reverse_name(address), "scientific", true)
  end

  def check_address(name, format, good)
    p = { :name => name, :format => format }
    good_ajax_request(:geocode, p)
    result = @response.body
    assert(result)
    num_strings = result.split("\n")
    if good
      assert_equal(4, num_strings.length)
      num_strings.each do |s|
        assert(s.to_f != 0.0)
      end
    else
      assert_equal(0, num_strings.length)
    end
  end

  def test_image
    # Returns a bogus image no matter what in test mode.
    good_ajax_request(:image, :type => '320', :id => 1)
  end

  def test_get_pivotal_story
    if PIVOTAL_USERNAME != 'username'
      good_ajax_request(:pivotal, :type => 'story', :id => PIVOTAL_TEST_ID)
      assert_match(/This is a test story/, @response.body)
      assert_match(/Posted by.*Rolf Singer/, @response.body)
      assert_match(/this is a test comment/, @response.body)
      assert_match(/By:.*Mary Newbie/, @response.body)
      assert_match(/Post Comment/, @response.body)
    end
  end

  def test_naming_vote
    naming = Naming.find(1)
    assert_nil(naming.users_vote(@dick))
    bad_ajax_request(:vote, :type => :naming, :id => 1, :value => 3)

    login('dick')
    good_ajax_request(:vote, :type => :naming, :id => 1, :value => 3)
    assert_equal(3, naming.reload.users_vote(@dick).value)

    good_ajax_request(:vote, :type => :naming, :id => 1, :value => 0)
    assert_nil(naming.reload.users_vote(@dick))

    bad_ajax_request(:vote, :type => :naming, :id => 1, :value => 99)
    bad_ajax_request(:vote, :type => :naming, :id => 99, :value => 0)
    bad_ajax_request(:vote, :type => :phooey, :id => 1, :value => 0)
  end

  def test_image_vote
    image = Image.find(1)
    assert_nil(image.users_vote(@dick))
    bad_ajax_request(:vote, :type => :image, :id => 1, :value => 3)

    login('dick')
    assert_nil(image.users_vote(@dick))
    good_ajax_request(:vote, :type => :image, :id => 1, :value => 3)
    assert_equal(3, image.reload.users_vote(@dick))

    good_ajax_request(:vote, :type => :image, :id => 1, :value => 0)
    assert_nil(image.reload.users_vote(@dick))

    bad_ajax_request(:vote, :type => :image, :id => 1, :value => 99)
    bad_ajax_request(:vote, :type => :image, :id => 99, :value => 0)
  end

  def test_old_translation
    str = TranslationString::Version.find(1)
    bad_ajax_request(:old_translation, :id => 0)
    good_ajax_request(:old_translation, :id => 1)
    assert_equal(str.text, @response.body)
  end
end
