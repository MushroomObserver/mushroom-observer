# Test a few representative sessions of a power-user.

require File.dirname(__FILE__) + '/../boot'

class ExpertTest < IntegrationTestCase

  # -----------------------------------------
  #  Test a few kinds of name descriptions.
  # -----------------------------------------

  def test_creating_public_descriptions
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
      form.assert_disabled('source_type')
      form.assert_enabled('source_name')
      form.assert_disabled('public_write')
      form.assert_disabled('public')
    end
    owner.open_form do |form|
      form.assert_disabled('source_type')
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

    
  end
end
