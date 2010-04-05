# Test a few representative sessions of a power-user.

require File.dirname(__FILE__) + '/../boot'

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

    admin    = login!(@dick)     # we'll make him admin
    reviewer = login!(@rolf)     # reviewer
    owner    = login!(@mary)     # random user
    user     = login!(@katrina)  # another random user
    lurker   = open_session      # nobody

    # Make Dick an admin.
    admin.click(:href => /turn_admin_on/)

    # Have random user create a public description.
    owner.get(show_name)
    owner.click(:href => /create_name_description/)
    owner.assert_template('name/create_name_description')
    owner.open_form do |form|
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
    owner.assert_flash_success
    owner.assert_template('name/show_name_description')

    # Admin of course can do anything.
    admin.get(show_name)
    admin.assert_select('a[href*=edit_name_description]')
    admin.assert_select('a[href*=destroy_name_description]')
    admin.click(:href => /edit_name_description/)

    # Reviewer is an admin for public descs, and can edit and destroy.
    reviewer.get(show_name)
    reviewer.assert_select('a[href*=edit_name_description]')
    reviewer.assert_select('a[href*=destroy_name_description]')
    reviewer.click(:href => /edit_name_description/)

    # Owner, surprisingly, is NOT an admin for public descs, and cannot
    # destroy.  But can edit.
    owner.get(show_name)
    owner.assert_select('a[href*=edit_name_description]')
    owner.assert_select('a[href*=destroy_name_description]', 0)
    owner.click(:href => /edit_name_description/)
    owner.assert_template('name/edit_name_description')

    # Other random users end up with the same permissions.
    user.get(show_name)
    user.assert_select('a[href*=edit_name_description]')
    user.assert_select('a[href*=destroy_name_description]', 0)
    user.click(:href => /edit_name_description/)
    user.assert_template('name/edit_name_description')

    # The lurker appears to have same permissions, but will need to login in
    # order to actually do anything.
    lurker.get(show_name)
    lurker.assert_select('a[href*=edit_name_description]')
    lurker.assert_select('a[href*=destroy_name_description]', 0)
    lurker.click(:href => /edit_name_description/)
    lurker.assert_template('account/login')

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

    admin    = login!(@dick)     # we'll make him admin
    reviewer = login!(@rolf)     # reviewer
    owner    = login!(@mary)     # random user
    user     = login!(@katrina)  # another random user
    lurker   = open_session      # nobody

    # Make Dick an admin.
    admin.click(:href => /turn_admin_on/)

    # Have random user create a personal description.
    owner.get(show_name)
    owner.click(:href => /create_name_description/)
    owner.assert_template('name/create_name_description')
    owner.open_form do |form|
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
    owner.assert_flash_success
    owner.assert_template('name/show_name_description')

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
    admin.get(show_name)
    admin.assert_select("a[href*=#{edit_name}]")
    admin.assert_select("a[href*=#{destroy_name}]")
    admin.click(:href => edit_name)

    # Reviewer is nothing in this case.
    reviewer.get(show_name)
    reviewer.assert_select("a[href*=#{edit_name}]", 0)
    reviewer.assert_select("a[href*=#{destroy_name}]", 0)

    # Owner, is an admin and can do anything.
    # destroy.  But can edit.
    owner.get(show_name)
    owner.assert_select("a[href*=#{edit_name}]")
    owner.assert_select("a[href*=#{destroy_name}]")
    owner.click(:href => edit_name)
    owner.assert_template('name/edit_name_description')

    # Other random users are also nobodies.
    user.get(show_name)
    user.assert_select("a[href*=#{edit_name}]", 0)
    user.assert_select("a[href*=#{destroy_name}]", 0)

    # The lurker is nobody.
    lurker.get(show_name)
    lurker.assert_select("a[href*=#{edit_name}]", 0)
    lurker.assert_select("a[href*=#{destroy_name}]", 0)

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
    assert_equal(nil, names.first.author)
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

    login!(@dick)
    get('species_list/create_species_list')
    open_form do |form|
      form.assert_value('list_members', '')
      form.change('list_members', list)
      form.change('title', 'Anything')
      form.change('place_name', 'Anywhere')
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
      'Petigera sp.',
      'Lactarius alpigenes Kühn.',
      'Suillus sp. E.B. White',
      'Amanita baccata sensu Arora',
      'Caloplaca arnoldii subsp. obliterate',
    ].sort, obs.map(&:name).map(&:search_name).sort)
  end
end
