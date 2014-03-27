# encoding: utf-8
# Test typical sessions of university student who is writing descriptions.

require File.expand_path(File.dirname(__FILE__) + '/../boot')

class StudentTest < IntegrationTestCase

  # -----------------------------------
  #  Test creating draft for project.
  # -----------------------------------

  def test_creating_drafts
    name = Name.find_by_text_name('Strobilurus diminutivus')
    gen_desc = 'Mary wrote this draft text.'

    project = projects(:eol_project)
    project.admin_group.users.delete(mary)

    rolf    = new_user_session(rolf)     # EOL admin
    mary    = new_user_session(mary)     # EOL user
    katrina = new_user_session(katrina)  # another EOL user
    dick    = new_user_session(dick)     # random user
    lurker  = new_session                 # nobody

    # Navigate to Strobilurus diminutivus (no descriptions) and create draft.
    in_session(mary) do
      get('/')
      click(:label => /index a.*z/i)
      click(:label => name.text_name)
      @show_name = path
      assert_match(/there are no descriptions/i, response.body)
      click(:label => project.title)
      assert_template('name/create_name_description')

      # Check that initial form is correct.
      open_form do |form|
        form.assert_value('source_type', 'project')
        form.assert_value('source_name', project.title)
        form.assert_value('public_write', false)
        form.assert_value('public', false)
        form.assert_hidden('source_type')
        form.assert_hidden('source_name')
        form.assert_enabled('public_write')
        form.assert_enabled('public')
        form.submit
      end
      assert_flash_success
      assert_template('name/show_name_description')

      # Make sure it shows up on main show_name page and that Mary can edit it.
      get(@show_name)
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
        form.assert_hidden('source_type')
        form.assert_hidden('source_name')
        form.assert_enabled('public_write')
        form.assert_enabled('public')
        form.change('gen_desc', gen_desc)
        form.submit
      end
      assert_flash_success
      assert_template('name/show_name_description')
    end

    # Make sure Rolf can view, edit and destroy it.
    in_session(rolf) do
      get(@show_name)
      assert_select('a[href*=show_name_description]', 1) do |links|
        assert_match(:restricted.l, links.first.to_s)
      end
      assert_not_match(gen_desc, rolf.response.body)
      assert_select('a[href*=create_name_description]', 1)
      click(:href => /show_name_description/)
      assert_template('name/show_name_description')
      assert_select('a[href*=edit_name_description]')
      assert_select('a[href*=destroy_name_description]')
      click(:href => /edit_name_description/)
      assert_template('name/edit_name_description')
      open_form do |form|
        form.assert_value('source_type', 'project')
        form.assert_value('source_name', project.title)
        form.assert_value('public_write', false)
        form.assert_value('public', false)
        form.assert_hidden('source_type')
        form.assert_hidden('source_name')
        form.assert_enabled('public_write')
        form.assert_enabled('public')
        form.assert_value('gen_desc', gen_desc)
      end
    end

    # Make sure Katrina can view but not edit.
    in_session(katrina) do
      get(@show_name)
      assert_select('a[href*=show_name_description]', 1)
      assert_select('a[href*=create_name_description]', 1)
      click(:href => /show_name_description/)
      assert_template('name/show_name_description')
      assert_select('a[href*=edit_name_description]', 0)
      assert_select('a[href*=destroy_name_description]', 0)
    end

    # Make sure Dick knows it exists but can't even view it.
    in_session(dick) do
      get(@show_name)
      assert_select('a[href*=show_name_description]', 1)
      # (Dick is also a member of the Bolete project.)
      assert_select('a[href*=create_name_description]', 2)
      click(:href => /show_name_description/)
      assert_flash_error
      assert_template('project/show_project')
      assert_nil(dick.assigns(:description))
    end

    # Likewise for lurker.
    in_session(lurker) do
      get(@show_name)
      assert_select('a[href*=show_name_description]', 1)
      assert_select('a[href*=create_name_description]', 1)
      click(:href => /show_name_description/)
      assert_flash_error
      assert_template('project/show_project')
      assert_nil(lurker.assigns(:description))
      assert_match(name.text_name, lurker.response.body)
    end
  end
end
