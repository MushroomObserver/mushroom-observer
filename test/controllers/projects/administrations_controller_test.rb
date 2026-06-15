# frozen_string_literal: true

require("test_helper")

module Projects
  class AdministrationsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def setup
      super
      @project = projects(:eol_project)
      @site_admin = users(:admin)
    end

    def test_create_promotes_site_admin_to_project_admin
      assert_not(@project.admin_group.users.include?(@site_admin))
      assert_not(@project.user_group.users.include?(@site_admin))
      assert_nil(ProjectMember.find_by(project: @project, user: @site_admin))

      login(@site_admin.login)
      email_count = ActionMailer::Base.deliveries.count
      perform_enqueued_jobs do
        post(:create, params: { project_id: @project.id })
      end

      assert_redirected_to(project_path(@project.id))
      assert_flash_text(:project_administration_promoted_flash.t(
                          title: @project.title
                        ))
      assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)

      @project.reload
      assert(@project.admin_group.users.include?(@site_admin))
      assert(@project.user_group.users.include?(@site_admin))
      assert_not_nil(
        ProjectMember.find_by(project: @project, user: @site_admin)
      )
    end

    def test_create_emails_project_owner
      login(@site_admin.login)
      ActionMailer::Base.deliveries.clear

      perform_enqueued_jobs do
        post(:create, params: { project_id: @project.id })
      end

      mail = ActionMailer::Base.deliveries.last
      assert_not_nil(mail)
      assert_includes(mail.to, @project.user.email)
    end

    def test_create_does_not_email_when_site_admin_owns_project
      project = projects(:empty_project)
      project.update!(user: @site_admin)
      login(@site_admin.login)
      ActionMailer::Base.deliveries.clear

      perform_enqueued_jobs do
        post(:create, params: { project_id: project.id })
      end

      assert_empty(ActionMailer::Base.deliveries)
    end

    def test_create_denied_for_non_site_admin
      login("katrina")
      email_count = ActionMailer::Base.deliveries.count
      perform_enqueued_jobs do
        post(:create, params: { project_id: @project.id })
      end

      assert_redirected_to(project_path(@project.id))
      assert_flash_error
      assert_equal(email_count, ActionMailer::Base.deliveries.count)
      assert_not(@project.reload.admin_group.users.include?(users(:katrina)))
    end

    def test_create_redirects_when_already_project_admin
      @project.admin_group.users << @site_admin
      @project.user_group.users << @site_admin
      login(@site_admin.login)
      email_count = ActionMailer::Base.deliveries.count

      perform_enqueued_jobs do
        post(:create, params: { project_id: @project.id })
      end

      assert_equal(email_count, ActionMailer::Base.deliveries.count)
      assert_flash_text(:project_administration_already_admin_flash.t)
    end

    def test_create_requires_login
      post(:create, params: { project_id: @project.id })
      assert_redirected_to(new_account_login_path)
    end

    def test_create_idempotent_on_double_submit
      login(@site_admin.login)
      post(:create, params: { project_id: @project.id })

      assert_no_difference(
        "@project.admin_group.users.reload.count"
      ) do
        post(:create, params: { project_id: @project.id })
      end
    end
  end
end
