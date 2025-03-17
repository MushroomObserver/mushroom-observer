# frozen_string_literal: true

require("test_helper")
require("api2_extensions")

class API2::ProjectsTest < UnitTestCase
  include API2Extensions

  def test_basic_project_get
    do_basic_get_test(Project)
  end

  # -----------------------------
  #  :section: Project Requests
  # -----------------------------

  def params_get(**)
    { method: :get, action: :project }.merge(**)
  end

  def prj_sample
    @prj_sample ||= Project.all.sample
  end

  def test_getting_projects_id
    assert_api_pass(params_get(id: prj_sample.id))
    assert_api_results([prj_sample])
  end

  def test_getting_projects_created_at
    projs = Project.where(Project[:created_at].year.eq(2008))
    assert_not_empty(projs)
    assert_api_pass(params_get(created_at: "2008"))
    assert_api_results(projs)
  end

  def test_getting_projects_updated_at
    projs = Project.where(
      (Project[:updated_at].year == 2008).and(Project[:updated_at].month == 9)
    )
    assert_not_empty(projs)
    assert_api_pass(params_get(updated_at: "2008-09"))
    assert_api_results(projs)
  end

  def test_getting_projects_user
    projs = Project.where(user: dick)
    assert_not_empty(projs)
    assert_api_pass(params_get(user: "dick"))
    assert_api_results(projs)
  end

  def test_getting_projects_has_images
    projs = Project.select { |p| p.images.any? }
    assert_not_empty(projs)
    assert_api_pass(params_get(has_images: "yes"))
    assert_api_results(projs)
  end

  def test_getting_projects_has_observations
    projs = Project.select { |p| p.observations.any? }
    assert_not_empty(projs)
    assert_api_pass(params_get(has_observations: "yes"))
    assert_api_results(projs)
  end

  def test_getting_projects_has_species_lists
    projs = Project.select { |p| p.species_lists.any? }
    assert_not_empty(projs)
    assert_api_pass(params_get(has_species_lists: "yes"))
    assert_api_results(projs)
  end

  def test_getting_projects_has_summary
    with    = Project.where(Project[:summary].not_blank)
    without = Project.where(Project[:summary].blank)
    assert_not_empty(with)
    assert_not_empty(without)
    assert_api_pass(params_get(has_summary: "yes"))
    assert_api_results(with)
    assert_api_pass(params_get(has_summary: "no"))
    assert_api_results(without)
  end

  def test_getting_projects_summary_has
    projs = Project.where(Project[:summary].matches("%article%"))
    assert_not_empty(projs)
    assert_api_pass(params_get(summary_has: "article"))
    assert_api_results(projs)
  end

  def test_getting_projects_title_has
    projs = Project.where(Project[:title].matches("%bolete%"))
    assert_not_empty(projs)
    assert_api_pass(params_get(title_has: "bolete"))
    assert_api_results(projs)
  end

  def test_getting_projects_has_comments_comments_has
    Comment.create!(user: katrina, target: prj_sample, summary: "blah")
    projs = Project.select { |p| p.comments.any? }
    assert_not_empty(projs)
    assert_api_pass(params_get(has_comments: "yes"))
    assert_api_results(projs)

    assert_api_pass(params_get(comments_has: "blah"))
    assert_api_results([prj_sample])
  end

  def test_creating_projects
    @title   = "minimal project"
    @summary = ""
    @admins  = [rolf]
    @members = [rolf]
    @user    = rolf
    params = {
      method: :post,
      action: :project,
      api_key: @api_key.key,
      title: @title
    }
    assert_api_fail(params.except(:api_key))
    assert_api_fail(params.except(:title))
    assert_api_pass(params)
    assert_last_project_correct

    @title   = "maximal project"
    @summary = "to do things"
    @admins  = [rolf, mary]
    @members = [rolf, mary, dick]
    params = {
      method: :post,
      action: :project,
      api_key: @api_key.key,
      title: @title,
      summary: @summary,
      admins: "mary",
      members: "dick"
    }
    assert_api_pass(params)
    assert_last_project_correct
  end

  def test_patching_projects
    proj = projects(:eol_project)
    # assert_user_arrays_equal([rolf, mary], proj.admin_group.users)
    # assert_user_arrays_equal([rolf, mary, katrina], proj.user_group.users)
    # assert_empty(proj.images)
    # assert_empty(proj.observations)
    # assert_empty(proj.species_lists)
    params = {
      method: :patch,
      action: :project,
      api_key: @api_key.key,
      id: proj.id
    }

    assert_api_fail(params)
    assert_api_fail(params.except(:api_key))
    @api_key.update!(user: katrina)
    assert_api_fail(params.merge(set_title: "new title"))
    @api_key.update!(user: rolf)
    assert_api_fail(params.merge(set_title: ""))
    assert_api_pass(params.merge(set_title: "new title"))
    assert_equal("new title", proj.reload.title)
    assert_api_pass(params.merge(set_summary: "new summary"))
    assert_equal("new summary", proj.reload.summary)

    assert_api_pass(params.merge(add_admins: "dick, roy"))
    assert_user_arrays_equal([rolf, mary, dick, roy],
                             proj.reload.admin_group.users)
    assert_user_arrays_equal([rolf, mary, katrina],
                             proj.reload.user_group.users)
    assert_api_pass(params.merge(remove_admins: "dick, roy"))
    assert_user_arrays_equal([rolf, mary],
                             proj.reload.admin_group.users)
    assert_user_arrays_equal([rolf, mary, katrina],
                             proj.reload.user_group.users)

    assert_api_pass(params.merge(add_members: "dick, roy"))
    assert_user_arrays_equal([rolf, mary],
                             proj.reload.admin_group.users)
    assert_user_arrays_equal([rolf, mary, katrina, dick, roy],
                             proj.reload.user_group.users)
    assert_api_pass(params.merge(remove_members: "dick, roy"))
    assert_user_arrays_equal([rolf, mary],
                             proj.reload.admin_group.users)
    assert_user_arrays_equal([rolf, mary, katrina],
                             proj.reload.user_group.users)

    imgs = mary.images.first.id
    assert_api_fail(params.merge(add_images: imgs))
    imgs = rolf.images[0..1].map { |img| img.id.to_s }.join(",")
    assert_api_pass(params.merge(add_images: imgs))
    assert_obj_arrays_equal(rolf.images[0..1], proj.reload.images)
    assert_api_pass(params.merge(remove_images: imgs))
    assert_empty(proj.reload.images)

    obses = mary.observations.first.id
    assert_api_fail(params.merge(add_observations: obses))
    obses = rolf.observations[0..1].map { |o| o.id.to_s }.join(",")
    assert_api_pass(params.merge(add_observations: obses))
    assert_equal([], rolf.observations[0..1] - proj.reload.observations)
    assert_api_pass(params.merge(remove_observations: obses))
    remaining = proj.reload.observations
    assert_equal(remaining - rolf.observations[0..1], remaining)

    spls = mary.species_lists.first.id
    assert_api_fail(params.merge(add_species_lists: spls))
    spls = rolf.species_lists[0..1].map { |list| list.id.to_s }.join(",")
    assert_api_pass(params.merge(add_species_lists: spls))
    assert_empty(rolf.species_lists[0..1] - proj.reload.species_lists)
    remaining = proj.reload.species_lists - rolf.species_lists[0..1]
    assert_api_pass(params.merge(remove_species_lists: spls))
    assert_empty(proj.reload.species_lists - remaining)
  end

  def test_deleting_projects
    proj = projects(:eol_project)
    params = {
      method: :delete,
      action: :project,
      api_key: @api_key.key,
      id: proj.id
    }
    # No DELETE requests should be allowed at all.
    assert_api_fail(params)
  end
end
