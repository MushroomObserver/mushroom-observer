# Test typical sessions of university student who is writing descriptions.

require File.dirname(__FILE__) + '/../boot'

class StudentTest < IntegrationTestCase

  # -----------------------------------
  #  Test creating draft for project.
  # -----------------------------------

  def test_creating_drafts
    name = Name.find_by_text_name('Strobilurus diminutivus')
    gen_desc = 'Mary wrote this draft text.'

    project = projects(:eol_project)
    project.admin_group.users.delete(@mary)

    rolf    = login!(@rolf)     # EOL admin
    mary    = login!(@mary)     # EOL user
    katrina = login!(@katrina)  # another EOL user
    dick    = login!(@dick)     # random user
    lurker  = open_session      # nobody

    # Navigate to Strobilurus diminutivus (no descriptions) and create draft.
    self.current_session = mary
    get('/')
    click(:label => /index a.*z/i)
    click(:label => name.text_name)
    show_name = path
    assert_match(/there are no descriptions/i, response.body)
    click(:label => project.title)
    assert_template('name/create_name_description')

    # Check that initial form is correct.
    open_form do |form|
      form.assert_value('source_type', 'project')
      form.assert_value('source_name', project.title)
      form.assert_value('public_write', false)
      form.assert_value('public', false)
      form.assert_disabled('source_type')
      form.assert_disabled('source_name')
      form.assert_enabled('public_write')
      form.assert_enabled('public')
      form.submit
    end
    assert_flash_success
    assert_template('name/show_name_description')
    show_desc = path

    # Make sure it shows up on main show_name page and that Mary can edit it.
    get(show_name)
    assert_select('a[href*=edit_name_description]', 1)
    assert_select('a[href*=destroy_name_description]', 1)

    # Now give it some text to make sure it *can* (but doesn't) actually get
    # displayed (content, that is) on main show_name page.
    click(:href => /edit_name_description/)
    open_form do |form|
      form.assert_value('source_type', 'project')
      form.assert_value('source_name', project.title)
      form.assert_value('public_write', false)
      form.assert_value('public', false)
      form.assert_disabled('source_type')
      form.assert_disabled('source_name')
      form.assert_enabled('public_write')
      form.assert_enabled('public')
      form.change('gen_desc', gen_desc)
      form.submit
    end
    assert_flash_success
    assert_template('name/show_name_description')

    # Make sure Rolf can view, edit and destroy it.
    rolf.get(show_name)
    rolf.assert_select('a[href*=show_name_description]', 1) do |links|
      rolf.assert_match(:restricted.l, links.first.to_s)
    end
    rolf.assert_not_match(gen_desc, rolf.response.body)
    rolf.assert_select('a[href*=create_name_description]', 1)
    rolf.click(:href => /show_name_description/)
    rolf.assert_template('name/show_name_description')
    rolf.assert_select('a[href*=edit_name_description]')
    rolf.assert_select('a[href*=destroy_name_description]')
    rolf.click(:href => /edit_name_description/)
    rolf.assert_template('name/edit_name_description')
    rolf.open_form do |form|
      form.assert_value('source_type', 'project')
      form.assert_value('source_name', project.title)
      form.assert_value('public_write', false)
      form.assert_value('public', false)
      form.assert_disabled('source_type')
      form.assert_disabled('source_name')
      form.assert_enabled('public_write')
      form.assert_enabled('public')
      form.assert_value('gen_desc', gen_desc)
    end

    # Make sure Katrina can view but not edit.
    katrina.get(show_name)
    katrina.assert_select('a[href*=show_name_description]', 1)
    katrina.assert_select('a[href*=create_name_description]', 1)
    katrina.click(:href => /show_name_description/)
    katrina.assert_template('name/show_name_description')
    katrina.assert_select('a[href*=edit_name_description]', 0)
    katrina.assert_select('a[href*=destroy_name_description]', 0)

    # Make sure Dick knows it exists but can't even view it.
    dick.get(show_name)
    dick.assert_select('a[href*=show_name_description]', 1)
    # (Dick is also a member of the Bolete project.)
    dick.assert_select('a[href*=create_name_description]', 2)
    dick.click(:href => /show_name_description/)
    dick.assert_flash_error
    dick.assert_template('project/show_project')
    dick.assert_nil(dick.assigns(:description))

    # Likewise for lurker.
    lurker.get(show_name)
    lurker.assert_select('a[href*=show_name_description]', 1)
    lurker.assert_select('a[href*=create_name_description]', 0)
    lurker.click(:href => /show_name_description/)
    lurker.assert_flash_error
    lurker.assert_template('project/show_project')
    lurker.assert_nil(lurker.assigns(:description))
  end
end
