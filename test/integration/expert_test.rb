# encoding: utf-8

# Test a few representative sessions of a power-user.

require File.expand_path(File.dirname(__FILE__) + '/../boot')

class ExpertTest < IntegrationTestCase

  def empty_notes
    hash = {}
    for f in NameDescription.all_note_fields
      hash[f] = nil
    end
    return hash
  end

################################################################################

  # -----------------------------------------
  #  Test standard creation of public desc.
  # -----------------------------------------

  def test_creating_public_description
    name = Name.find_by_text_name('Strobilurus diminutivus')
    assert_equal([], name.descriptions)

    @dick.admin = true
    @dick.save

    show_name = "/name/show_name/#{name.id}"

    admin    = new_user_session(@dick)     # we'll make him admin
    reviewer = new_user_session(@rolf)     # reviewer
    owner    = new_user_session(@mary)     # random user
    user     = new_user_session(@katrina)  # another random user
    lurker   = new_session                 # nobody

    # Make Dick an admin.
    admin.click(:href => /turn_admin_on/)

    # Have random user create a public description.
    in_session(owner) do
      get(show_name)
      click(:href => /create_name_description/)
      assert_template('name/create_name_description')
      open_form do |form|
        form.assert_value('source_type', 'public')
        form.assert_value('source_name', '')
        form.assert_value('public_write', true)
        form.assert_value('public', true)
        form.assert_enabled('source_type')
        form.assert_enabled('source_name')
        # (have to be enabled because user could switch to :source or :user,
        # instead must used javascript to disable these when :public)
        form.assert_enabled('public_write')
        form.assert_enabled('public')
        form.change('notes', 'I like this mushroom.')
        form.submit
      end
      assert_flash_success
      assert_template('name/show_name_description')
    end

    # Admin of course can do anything.
    in_session(admin) do
      get(show_name)
      assert_select('a[href*=edit_name_description]')
      assert_select('a[href*=destroy_name_description]')
      click(:href => /edit_name_description/)
    end

    # Reviewer is an admin for public descs, and can edit and destroy.
    in_session(reviewer) do
      get(show_name)
      assert_select('a[href*=edit_name_description]')
      assert_select('a[href*=destroy_name_description]')
      click(:href => /edit_name_description/)
    end

    # Owner, surprisingly, is NOT an admin for public descs, and cannot
    # destroy.  But can edit.
    in_session(owner) do
      get(show_name)
      assert_select('a[href*=edit_name_description]')
      assert_select('a[href*=destroy_name_description]', 0)
      click(:href => /edit_name_description/)
      assert_template('name/edit_name_description')
    end

    # Other random users end up with the same permissions.
    in_session(user) do
      get(show_name)
      assert_select('a[href*=edit_name_description]')
      assert_select('a[href*=destroy_name_description]', 0)
      click(:href => /edit_name_description/)
      assert_template('name/edit_name_description')
    end

    # The lurker appears to have same permissions, but will need to login in
    # order to actually do anything.
    in_session(lurker) do
      get(show_name)
      assert_select('a[href*=edit_name_description]')
      assert_select('a[href*=destroy_name_description]', 0)
      click(:href => /edit_name_description/)
      assert_template('account/login')
    end

    # Check that all editors can edit the "source_name".
    admin.open_form do |form|
      form.assert_enabled('source_type')
      form.assert_enabled('source_name')
      form.assert_enabled('public_write')
      form.assert_enabled('public')
    end
    reviewer.open_form do |form|
      form.assert_hidden('source_type')
      form.assert_enabled('source_name')
      form.assert_disabled('public_write')
      form.assert_disabled('public')
    end
    owner.open_form do |form|
      form.assert_no_field('source_type')
      form.assert_enabled('source_name')
      form.assert_disabled('public_write')
      form.assert_disabled('public')
    end
    user.open_form do |form|
      form.assert_no_field('source_type')
      form.assert_no_field('source_name')
      form.assert_no_field('public_write')
      form.assert_no_field('public')
    end

    # Verify that permissions and authors and editors are right.
    desc = NameDescription.last
    assert_obj_list_equal([UserGroup.reviewers], desc.admin_groups)
    assert_obj_list_equal([UserGroup.all_users], desc.writer_groups)
    assert_obj_list_equal([UserGroup.all_users], desc.reader_groups)
    assert_user_list_equal([], desc.authors)
    assert_user_list_equal([@mary], desc.editors) # (owner = mary)
    assert_equal('I like this mushroom.', desc.notes)
  end

  # -------------------------------------------
  #  Test standard creation of personal desc.
  # -------------------------------------------

  def test_creating_user_description
    name = Name.find_by_text_name('Peltigera')
    assert_equal(4, name.descriptions.length)

    @dick.admin = true
    @dick.save

    show_name = "/name/show_name/#{name.id}"

    admin    = new_user_session(@dick)     # we'll make him admin
    reviewer = new_user_session(@rolf)     # reviewer
    owner    = new_user_session(@mary)     # random user
    user     = new_user_session(@katrina)  # another random user
    lurker   = new_session                 # nobody

    # Make Dick an admin.
    admin.click(:href => /turn_admin_on/)

    # Have random user create a personal description.
    in_session(owner) do
      get(show_name)
      click(:href => /create_name_description/)
      assert_template('name/create_name_description')
      open_form do |form|
        form.assert_value('source_type', 'public')
        form.assert_value('source_name', '')
        form.assert_value('public_write', true)
        form.assert_value('public', true)
        form.assert_enabled('source_type')
        form.assert_enabled('source_name')
        form.assert_enabled('public_write')
        form.assert_enabled('public')
        form.select('source_type', /user/i)
        form.change('source_name', "Mary's Corner")
        form.uncheck('public_write')
        form.change('gen_desc', 'Leafy felt lichens.')
        form.change('diag_desc', 'Usually with veins and tomentum below.')
        form.change('look_alikes', '_Solorina_ maybe, but not much else.')
        form.submit
      end
      assert_flash_success
      assert_template('name/show_name_description')
    end

    desc = NameDescription.last
    assert_equal(:user, desc.source_type)
    assert_equal("Mary's Corner", desc.source_name)
    assert_equal(false, desc.public_write)
    assert_equal(true, desc.public)
    assert_obj_list_equal([UserGroup.one_user(@mary)], desc.admin_groups)
    assert_obj_list_equal([UserGroup.one_user(@mary)], desc.writer_groups)
    assert_obj_list_equal([UserGroup.all_users], desc.reader_groups)
    assert_user_list_equal([@mary], desc.authors)
    assert_user_list_equal([], desc.editors)
    assert_equal(empty_notes.merge(
      :gen_desc => 'Leafy felt lichens.',
      :diag_desc => 'Usually with veins and tomentum below.',
      :look_alikes => '_Solorina_ maybe, but not much else.'
    ), desc.all_notes)

    edit_name    = "/name/edit_name_description/#{desc.id}"
    destroy_name = "/name/destroy_name_description/#{desc.id}"

    # Admin of course can do anything.
    in_session(admin) do
      admin.get(show_name)
      admin.assert_select("a[href*=#{edit_name}]")
      admin.assert_select("a[href*=#{destroy_name}]")
      admin.click(:href => edit_name)
    end

    # Reviewer is nothing in this case.
    in_session(reviewer) do
      get(show_name)
      assert_select("a[href*=#{edit_name}]", 0)
      assert_select("a[href*=#{destroy_name}]", 0)
    end

    # Owner, is an admin and can do anything.
    # destroy.  But can edit.
    in_session(owner) do
      get(show_name)
      assert_select("a[href*=#{edit_name}]")
      assert_select("a[href*=#{destroy_name}]")
      click(:href => edit_name)
      assert_template('name/edit_name_description')
    end

    # Other random users are also nobodies.
    in_session(user) do
      get(show_name)
      assert_select("a[href*=#{edit_name}]", 0)
      assert_select("a[href*=#{destroy_name}]", 0)
    end

    # The lurker is nobody.
    in_session(lurker) do
      get(show_name)
      assert_select("a[href*=#{edit_name}]", 0)
      assert_select("a[href*=#{destroy_name}]", 0)
    end
  end

  # --------------------------------------------------------
  #  Test passing of arguments around in bulk name editor.
  # --------------------------------------------------------

  def test_bulk_name_editor
    name1 = "Caloplaca arnoldii"
    author1 = "(Wedd.) Zahlbr."
    full_name1 = "#{name1} #{author1}"

    name2 = "Caloplaca arnoldii ssp. obliterate"
    author2 = "(Pers.) Gaya"
    full_name2 = "#{name1} #{author2}"

    name3 = "Acarospora nodulosa var. reagens"
    author3 = "Zahlbr."
    full_name3 = "#{name1} #{author3}"

    name4 = "Lactarius subalpinus"
    name5 = "Lactarius newname"

    list =
      "#{name1} #{author1}\r\n" +
      "#{name2} #{author2}\r\n" +
      "#{name3} #{author3}\r\n" +
      "#{name4} = #{name5}"

    login!(@dick)
    get('name/bulk_name_edit')
    open_form do |form|
      form.assert_value('list_members', '')
      form.change('list_members', list)
      form.submit
    end
    assert_flash_error
    assert_response(:success)
    assert_template('name/bulk_name_edit')

    # Don't mess around, just let it do whatever it does, and make sure it is
    # correct.  I don't want to make any assumptions about how the internals
    # work (e.g., I don't want to make any assertions about the hidden fields)
    # -- all I want to be sure of is that it doesn't f--- up our list of names.
    open_form do |form|
      assert_equal(list.split(/\r\n/).sort,
                   form.get_value!('list_members').split(/\r\n/).sort)
      # field = form.get_field('approved_names')
      form.submit
    end
    assert_flash_success
    assert_template('observer/list_rss_logs')

    assert_not_nil(Name.find_by_text_name('Caloplaca'))

    names = Name.find_all_by_text_name(name1)
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(author1, names.first.author)
    assert_equal(false, names.first.deprecated)

    names = Name.find_all_by_text_name(name2.sub(/ssp/, 'subsp'))
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(author2, names.first.author)
    assert_equal(false, names.first.deprecated)

    names = Name.find_all_by_text_name(name2.sub(/ssp/, 'subsp'))
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(author2, names.first.author)
    assert_equal(false, names.first.deprecated)

    assert_not_nil(Name.find_by_text_name('Acarospora'))
    assert_not_nil(Name.find_by_text_name('Acarospora nodulosa'))

    names = Name.find_all_by_text_name(name3)
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(author3, names.first.author)
    assert_equal(false, names.first.deprecated)

    names = Name.find_all_by_text_name(name4)
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(false, names.first.deprecated)

    names = Name.find_all_by_text_name(name5)
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal('', names.first.author)
    assert_equal(true, names.first.deprecated)

    # I guess this is left alone, even though you would probably
    # expect it to be deprecated.
    names = Name.find_all_by_text_name('Lactarius alpinus')
    assert_equal(1, names.length, names.map(&:search_name).inspect)
    assert_equal(false, names.first.deprecated)
  end

  # ----------------------------------------------------------
  #  Test passing of arguments around in species list forms.
  # ----------------------------------------------------------

  def test_species_list_forms
    names = [
      'Petigera',
      'Lactarius alpigenes',
      'Suillus',
      'Amanita baccata',
      'Caloplaca arnoldii ssp. obliterate',
    ]
    list = names.join("\r\n")

    amanita = Name.find_all_by_text_name('Amanita baccata')
    suillus = Name.find_all_by_text_name('Suillus')

    albion = locations(:albion)
    albion_name = albion.name
    albion_name_reverse = Location.reverse_name(albion.name)

    new_location = 'Somewhere New, California, USA'
    new_location_reverse = 'USA, California, Somewhere New'

    newer_location = 'Somewhere Else, California, USA'
    newer_location_reverse = 'USA, California, Somewhere Else'

    # Good opportunity to test scientific location notation!
    @dick.location_format = :scientific
    @dick.save

    # First attempt at creating a list.
    login!(@dick)
    get('species_list/create_species_list')
    open_form do |form|
      form.assert_value('list_members', '')
      form.change('list_members', list)
      form.change('title', 'List Title')
      form.change('place_name', albion_name_reverse)
      form.change('species_list_notes', 'List notes.')
      form.change('member_notes', 'Member notes.')
      form.check('member_is_collection_location')
      form.check('member_specimen')
      form.submit
    end
    assert_flash_error
    assert_response(:success)
    assert_template('species_list/create_species_list')

    assert_select('div#missing_names', /Caloplaca arnoldii ssp. obliterate/)
    assert_select('div#deprecated_names', /Lactarius alpigenes/)
    assert_select('div#deprecated_names', /Lactarius alpinus/)
    assert_select('div#deprecated_names', /Petigera/)
    assert_select('div#deprecated_names', /Peltigera/)
    assert_select('div#ambiguous_names', /Amanita baccata.*sensu Arora/)
    assert_select('div#ambiguous_names', /Amanita baccata.*sensu Borealis/)
    assert_select('div#ambiguous_names', /Suillus.*Gray/)
    assert_select('div#ambiguous_names', /Suillus.*White/)

    # Fix the ambiguous names: should be good now.
    open_form do |form|
      assert_equal(list.split(/\r\n/).sort,
                   form.get_value!('list_members').split(/\r\n/).sort)
      form.check(/chosen_multiple_names_\d+_#{amanita[0].id}/)
      form.check(/chosen_multiple_names_\d+_#{suillus[1].id}/)
      form.submit
    end
    assert_flash_success
    assert_template('species_list/show_species_list')

    spl = SpeciesList.last
    obs = spl.observations
    assert_equal(5, obs.length, obs.map(&:text_name).inspect)
    assert_equal([
      'Petigera' + Name::SP,
      'Lactarius alpigenes Kühn.',
      'Suillus' + Name::SP + ' E.B. White',
      'Amanita baccata sensu Arora',
      'Caloplaca arnoldii subsp. obliterate',
    ].sort, obs.map(&:name).map(&:search_name).sort)
    assert_equal('List Title', spl.title)
    assert_equal(albion, spl.location)
    assert_equal('List notes.', spl.notes)
    assert_equal(albion, obs.last.location)
    assert_equal('Member notes.', obs.last.notes)
    assert_true(obs.last.is_collection_location)
    assert_true(obs.last.specimen)

    # Try making some edits, too.
    click(:href => /edit_species_list/)
    open_form do |form|
      form.assert_value('list_members', '')
      form.assert_value('title', 'List Title')
      form.assert_value('place_name', albion_name_reverse)
      form.assert_value('species_list_notes', 'List notes.')
      form.assert_value('member_notes', 'Member notes.')
      form.assert_value('member_is_collection_location', true)
      form.assert_value('member_specimen', true)
      form.change('list_members', "Agaricus nova\r\nAmanita baccata\r\n")
      form.change('title', 'Something New')
      form.change('place_name', new_location_reverse)
      form.change('species_list_notes', 'New list notes.')
      form.change('member_notes', 'New member notes.')
      form.uncheck('member_is_collection_location')
      form.uncheck('member_specimen')
      form.submit
    end
    assert_flash_error
    assert_response(:success)
    assert_template('species_list/edit_species_list')

    assert_select('div#missing_names', /Agaricus nova/)
    assert_select('div#ambiguous_names', /Amanita baccata.*sensu Arora/)
    assert_select('div#ambiguous_names', /Amanita baccata.*sensu Borealis/)

    # Fix the ambiguous name.
    open_form do |form|
      form.check(/chosen_multiple_names_\d+_#{amanita[1].id}/)
      form.submit
    end
    assert_flash_success
    assert_template('location/create_location')

    spl.reload
    obs = spl.observations
    assert_equal(7, obs.length, obs.map(&:text_name).inspect)
    assert_equal([
      'Petigera' + Name::SP,
      'Lactarius alpigenes Kühn.',
      'Suillus' + Name::SP + ' E.B. White',
      'Amanita baccata sensu Arora',
      'Caloplaca arnoldii subsp. obliterate',
      'Agaricus nova',
      'Amanita baccata sensu Borealis',
    ].sort, obs.map(&:name).map(&:search_name).sort)
    assert_equal('Something New', spl.title)
    assert_equal(new_location, spl.where)
    assert_equal(nil, spl.location)
    assert_equal('New list notes.', spl.notes)
    assert_equal(nil, obs.last.location)
    assert_equal(new_location, obs.last.where)
    assert_equal(nil, obs.last.location)
    assert_equal('New member notes.', obs.last.notes)
    assert_false(obs.last.is_collection_location)
    assert_false(obs.last.specimen)

    # Should have chained us into create_location.  Define this location
    # and make sure it updates both the observations and the list.
    open_form do |form|
      form.assert_value('location_display_name', new_location_reverse)
      form.change('location_display_name', newer_location_reverse)
      form.change('location_north', '35.6622')
      form.change('location_south', '35.6340')
      form.change('location_east', '-83.0371')
      form.change('location_west', '-83.0745')
      form.submit
    end
    assert_flash_success
    assert_template('species_list/show_species_list')
    assert_select('div#Title', :text => /#{spl.title}/)
    assert_select("a[href*=edit_species_list/#{spl.id}]", :text => /edit/i)

    loc = Location.last
    assert_equal(newer_location, loc.name)
    assert_equal(@dick, User.current)
    assert_equal(newer_location_reverse, loc.display_name)
    spl.reload
    obs = spl.observations
    assert_equal(nil, spl.where)
    assert_equal(loc, spl.location)
    assert_equal(nil, obs.last.where)
    assert_equal(loc, obs.last.location)
    
    # Try adding a comment, just for kicks.
    click(:href => /add_comment/)
    assert_template('comment/add_comment')
    assert_select('div#Title', :text => /#{spl.title}/)
    assert_select("a[href*=show_species_list/#{spl.id}]", :text => /cancel/i)
    open_form do |form|
      form.change('comment_summary', 'Slartibartfast')
      form.change('comment_comment', 'Steatopygia')
      form.submit
    end
    assert_flash_success
    assert_template('species_list/show_species_list')
    assert_select('div#Title', :text => /#{spl.title}/)
    assert_select('p', :text => /Slartibartfast/)
    assert_select('p', :text => /Steatopygia/)
  end
end
