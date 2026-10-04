# frozen_string_literal: true

require("test_helper")

module Projects
  # Each project admin decides for themselves whether to be emailed
  # about what iNaturalist identified (#5416).
  class AlertSubscriptionsControllerTest < FunctionalTestCase
    def setup
      super
      @controller = Projects::AlertSubscriptionsController.new
      @project = projects(:eol_project)
      @admin = @project.admin_group.users.first
      @project_site = ProjectExternalSite.create!(
        project: @project, external_site: external_sites(:inaturalist),
        use_constraints: true, alerting: true
      )
    end

    def subscribe(value, user: @admin)
      login(user.login)
      patch(:update, params: { project_id: @project.id,
                               id: @project_site.id, subscribed: value })
    end

    def test_an_admin_subscribes_themselves
      subscribe("1")

      assert_redirected_to(project_admin_path(project_id: @project.id))
      assert(@project_site.reload.alerts?(@admin))
    end

    # An unchecked box submits the hidden "0".
    def test_an_admin_unsubscribes_themselves
      @project_site.alerts_for(@admin, true)
      subscribe("0")

      assert_not(@project_site.reload.alerts?(@admin))
    end

    def test_a_non_admin_may_not_subscribe
      outsider = users(:zero_user)
      subscribe("1", user: outsider)

      assert_redirected_to(project_path(@project.id))
      assert_flash_error
      assert_not(@project_site.reload.alerts?(outsider))
    end

    # A form held open from before a site admin turned alerting off.
    def test_a_site_not_alerting_takes_no_subscriptions
      @project_site.update!(alerting: false)
      subscribe("1")

      assert_redirected_to(project_admin_path(project_id: @project.id))
      assert_flash_error
      assert_not(@project_site.reload.alerts?(@admin))
    end

    def test_login_required
      patch(:update, params: { project_id: @project.id,
                               id: @project_site.id, subscribed: "1" })

      assert_redirected_to(new_account_login_path)
    end
  end
end
