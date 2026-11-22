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

  def test_importing_needs_a_source
    site = new_site(importing: true)

    assert_not(site.valid?)
    assert(site.errors[:base].any?)
  end

  def test_a_configured_row_may_act
    site = new_site(use_constraints: true, importing: true)

    assert(site.valid?)
    assert(site.acting?)
  end

  # Alerting belongs to the project (#5721), so a row that imports
  # nothing still acts when one of the project's admins subscribed.
  def test_a_row_of_an_alerting_project_acts
    project = projects(:rare_fungi_project)
    project.alerts_for(users(:mary), true)
    site = ProjectExternalSite.new(project: project, external_site: @site,
                                   use_constraints: true)

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
    importing = new_site(use_constraints: true, importing: true)
    importing.save!
    idle = ProjectExternalSite.create!(project: projects(:bolete_project),
                                       external_site: @site,
                                       use_constraints: true)

    assert_includes(ProjectExternalSite.importing, importing)
    assert_not_includes(ProjectExternalSite.importing, idle)
    assert_equal([importing], ProjectExternalSite.acting.to_a)

    alerting = ProjectExternalSite.create!(
      project: projects(:rare_fungi_project), external_site: @site,
      use_constraints: true
    )
    projects(:rare_fungi_project).alerts_for(users(:mary), true)

    assert_equal([importing, alerting].sort_by(&:id),
                 ProjectExternalSite.acting.order(:id).to_a)
  end

  def test_project_destroy_takes_its_rows
    site = new_site(use_constraints: true)
    site.save!

    @project.destroy

    assert_not(ProjectExternalSite.exists?(site.id))
  end
end
