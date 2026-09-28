# frozen_string_literal: true

require("test_helper")

# Where a project's observations may come from on an external site, and
# what MO may do about them (#5416).
class ProjectExternalSourceTest < UnitTestCase
  def setup
    super
    @project = projects(:eol_project)
    @site = external_sites(:inaturalist)
    @admin = users(:rolf)
  end

  def new_source(**args)
    ProjectExternalSource.new(project: @project, external_site: @site, **args)
  end

  def approved_source(**args)
    source = new_source(**args)
    source.approved_at = Time.zone.now
    source.approved_by = @admin
    source
  end

  def test_a_source_needs_neither_shape_nor_action
    assert(new_source.save)
  end

  def test_one_source_per_site_per_project
    new_source(remote_project_id: "169620").save!
    duplicate = new_source(remote_project_id: "169621")

    assert_not(duplicate.valid?)
    assert(duplicate.errors[:external_site_id].any?)
  end

  def test_same_site_for_another_project
    new_source(remote_project_id: "169620").save!
    other = ProjectExternalSource.new(project: projects(:bolete_project),
                                      external_site: @site,
                                      remote_project_id: "169620")

    assert(other.valid?)
  end

  def test_configured_by_either_shape
    assert_not(new_source.configured?)
    assert(new_source(remote_project_id: "169620").configured?)
    assert(new_source(use_criteria: true).configured?)
  end

  def test_acting_needs_a_source
    source = approved_source(alerting: true)

    assert_not(source.valid?)
    assert(source.errors[:base].any?)
  end

  def test_acting_needs_approval
    source = new_source(use_criteria: true, importing: true)

    assert_not(source.valid?)
    assert(source.errors[:base].any?)
  end

  def test_an_approved_configured_source_may_act
    source = approved_source(use_criteria: true, alerting: true,
                             importing: true)

    assert(source.valid?)
    assert(source.acting?)
  end

  def test_import_limit_must_be_a_positive_count
    assert_not(new_source(import_limit: 0).valid?)
    assert_not(new_source(import_limit: -1).valid?)
    assert(new_source(import_limit: 1).valid?)
  end

  def test_default_import_limit
    assert_equal(10_000, new_source.tap(&:save!).import_limit)
  end

  def test_approve_records_who_and_when
    source = new_source(use_criteria: true)
    source.save!

    assert(source.approve(@admin))
    assert(source.approved?)
    assert_equal(@admin, source.approved_by)
    assert_not_nil(source.approved_at)
  end

  def test_revoke_turns_both_flags_off
    source = approved_source(use_criteria: true, alerting: true,
                             importing: true)
    source.save!

    assert(source.revoke)
    assert_not(source.approved?)
    assert_nil(source.approved_by)
    assert_not(source.alerting?)
    assert_not(source.importing?)
  end

  def test_scopes
    acting = approved_source(use_criteria: true, alerting: true)
    acting.save!
    idle = ProjectExternalSource.create!(project: projects(:bolete_project),
                                         external_site: @site,
                                         use_criteria: true)

    assert_includes(ProjectExternalSource.approved, acting)
    assert_not_includes(ProjectExternalSource.approved, idle)
    assert_includes(ProjectExternalSource.alerting, acting)
    assert_empty(ProjectExternalSource.importing)
    assert_equal([acting], ProjectExternalSource.acting.to_a)
  end

  def test_project_destroy_takes_its_sources
    source = new_source(use_criteria: true)
    source.save!

    @project.destroy

    assert_not(ProjectExternalSource.exists?(source.id))
  end
end
