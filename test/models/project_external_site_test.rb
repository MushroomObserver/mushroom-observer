# frozen_string_literal: true

require("test_helper")

# A project's relationship with one external site: where its
# observations may come from there, and what MO may do about them
# (#5416).
class ProjectExternalSiteTest < UnitTestCase
  def setup
    super
    @project = projects(:eol_project)
    @site = external_sites(:inaturalist)
  end

  def new_site(**args)
    ProjectExternalSite.new(project: @project, external_site: @site, **args)
  end

  def test_a_row_needs_neither_shape_nor_action
    assert(new_site.save)
  end

  def test_one_row_per_site_per_project
    new_site(remote_project_id: "169620").save!
    duplicate = new_site(remote_project_id: "169621")

    assert_not(duplicate.valid?)
    assert(duplicate.errors[:external_site_id].any?)
  end

  def test_same_site_for_another_project
    new_site(remote_project_id: "169620").save!
    other = ProjectExternalSite.new(project: projects(:bolete_project),
                                    external_site: @site,
                                    remote_project_id: "169620")

    assert(other.valid?)
  end

  def test_configured_by_either_shape
    assert_not(new_site.configured?)
    assert(new_site(remote_project_id: "169620").configured?)
    assert(new_site(use_constraints: true).configured?)
  end

  def test_acting_needs_a_source
    site = new_site(alerting: true)

    assert_not(site.valid?)
    assert(site.errors[:base].any?)
  end

  def test_a_configured_row_may_act
    site = new_site(use_constraints: true, alerting: true,
                    importing: true,
                    alert_recipient_ids: [users(:mary).id])

    assert(site.valid?)
    assert(site.acting?)
  end

  def test_import_limit_must_be_a_positive_count
    assert_not(new_site(import_limit: 0).valid?)
    assert_not(new_site(import_limit: -1).valid?)
    assert(new_site(import_limit: 1).valid?)
  end

  def test_default_import_limit
    assert_equal(10_000, new_site.tap(&:save!).import_limit)
  end

  def test_remote_url_points_at_the_project_on_the_site
    assert_nil(new_site.remote_url)
    assert_equal("#{Inat::Constants::SITE}/projects/169620",
                 new_site(remote_project_id: "169620").remote_url)
  end

  def test_scopes
    acting = new_site(use_constraints: true, alerting: true,
                      alert_recipient_ids: [users(:mary).id])
    acting.save!
    idle = ProjectExternalSite.create!(project: projects(:bolete_project),
                                       external_site: @site,
                                       use_constraints: true)

    assert_includes(ProjectExternalSite.alerting, acting)
    assert_not_includes(ProjectExternalSite.alerting, idle)
    assert_empty(ProjectExternalSite.importing)
    assert_equal([acting], ProjectExternalSite.acting.to_a)
  end

  def test_project_destroy_takes_its_rows
    site = new_site(use_constraints: true)
    site.save!

    @project.destroy

    assert_not(ProjectExternalSite.exists?(site.id))
  end

  # --- who gets alerted ------------------------------------------------

  def test_a_row_with_no_recipients_alerts_nobody
    assert_empty(new_site.alert_recipients)
    assert_not(new_site.alerts?(users(:mary)))
  end

  def test_an_admin_subscribes_and_unsubscribes_themselves
    row = new_site(use_constraints: true, alerting: true)
    row.save!

    row.alerts_for(users(:mary), true)

    assert(row.alerts?(users(:mary)))
    assert_equal([users(:mary)], row.alert_recipients.to_a)

    row.alerts_for(users(:mary), false)

    assert_not(row.alerts?(users(:mary)))
    assert_empty(row.alert_recipients)
  end

  # Two tabs, or a double submit, should not subscribe twice.
  def test_subscribing_twice_leaves_one_recipient
    row = new_site(use_constraints: true, alerting: true)
    row.save!
    2.times { row.alerts_for(users(:mary), true) }

    assert_equal([users(:mary).id], row.alert_recipient_ids)
  end

  def test_unsubscribing_leaves_the_others_alone
    row = new_site(use_constraints: true, alerting: true)
    row.save!
    row.alerts_for(users(:mary), true)
    row.alerts_for(users(:rolf), true)
    row.alerts_for(users(:mary), false)

    assert_equal([users(:rolf)], row.alert_recipients.to_a)
  end

  # Alerting is a site admin saying the project may be alerted on, not
  # a claim that anyone has asked to hear about it.
  def test_alerting_saves_with_nobody_subscribed
    assert(new_site(use_constraints: true, alerting: true).save)
  end
end
