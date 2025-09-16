# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Projects class to be included in QueryTest
class Query::ProjectsTest < UnitTestCase
  include QueryExtensions

  def test_project_all
    expects = Project.order_by_default
    assert_query(expects, :Project)
  end

  def test_project_order_by_name
    expects = Project.order_by(:name)
    assert_query(expects, :Project, order_by: :name)
  end

  def test_project_order_by_rss_log
    expects = Project.order_by(:rss_log)
    assert_query(expects, :Project, order_by: :rss_log)
  end

  def test_project_order_by_summary
    expects = Project.order_by(:summary)
    assert_query(expects, :Project, order_by: :summary)
  end

  def test_project_in_set
    set = [projects(:eol_project).id]
    assert_query_scope(set,
                       Project.id_in_set(set).order_by_default,
                       :Project, id_in_set: set)
    assert_query([], :Project, id_in_set: [])
  end

  def test_project_members
    assert_query(Project.members(rolf).order_by_default,
                 :Project, members: [rolf])
    assert_query(Project.members(mary).order_by_default,
                 :Project, members: [mary])
    assert_query(Project.members(dick).order_by_default,
                 :Project, members: [dick])
  end

  def test_project_names
    names = [names(:peltigera).search_name]
    scope = Project.names(names).order_by_default
    assert_query(scope, :Project, names: names)
    assert_query(
      [projects(:pinned_date_range_project),
       projects(:unlimited_project),
       projects(:one_genus_two_species_project)],
      :Project, names: names
    )
  end

  def test_project_region
    region = "Albion, California, USA"
    ids = [projects(:albion_project).id,
           projects(:no_start_date_project).id,
           projects(:no_end_date_project).id,
           projects(:past_project).id]
    scope = Project.region(region).order_by_default
    assert_query_scope(ids, scope, :Project, region:)
  end

  def test_project_title_has
    expects = [projects(:news_articles_project)]
    scope = Project.title_has("News Articles")
    assert_query_scope(expects, scope, :Project, title_has: "News Articles")
  end

  def test_project_has_summary
    expects = [projects(:news_articles_project), projects(:empty_project),
               projects(:two_list_project), projects(:lone_wolf_project),
               projects(:open_membership_project), projects(:bolete_project),
               projects(:eol_project)]
    scope = Project.has_summary.order_by_default
    assert_query_scope(expects, scope, :Project, has_summary: "yes")
    scope = Project.has_summary(false).order_by_default
    assert_query(scope, :Project, has_summary: "no")
  end

  def test_project_summary_has
    expects = [projects(:empty_project)]
    scope = Project.summary_has("No Images")
    assert_query_scope(expects, scope, :Project, summary_has: "No Images")
  end

  def test_project_field_slip_prefix_has
    expects = [projects(:eol_project)]
    scope = Project.field_slip_prefix_has("EOL").order_by_default
    assert_query_scope(expects, scope, :Project, field_slip_prefix_has: "EOL")
  end

  def test_project_pattern_search
    assert_query([],
                 :Project, pattern: "no project has this")
    # title
    expects = [projects(:bolete_project)]
    scope = project_pattern_search("bolete")
    assert_query_scope(expects, scope, :Project, pattern: "bolete")
    # summary
    expects = [projects(:two_list_project)]
    scope = project_pattern_search("two lists")
    assert_query_scope(expects, scope, :Project, pattern: "two lists")
    # field_slip_prefix
    expects = [projects(:current_closed_project), projects(:current_project)]
    scope = project_pattern_search("CURR")
    assert_query_scope(expects, scope, :Project, pattern: "CURR")

    expects = Project.order_by_default
    assert_query(expects, :Project, pattern: "")
  end

  def project_pattern_search(pattern)
    Project.pattern(pattern).order_by_default.distinct
  end

  # These next four only handle a `true` condition
  def test_project_has_images
    expects = [projects(:lone_wolf_project), projects(:bolete_project)]
    scope = Project.has_images.order_by_default
    assert_query_scope(expects, scope, :Project, has_images: true)
  end

  def test_project_has_observations
    scope = Project.has_observations.order_by_default
    assert_query(scope, :Project, has_observations: true)
  end

  def test_project_has_species_lists
    expects = Project.joins(:species_lists).distinct.order_by_default
    scope = Project.has_species_lists.order_by_default
    assert_query_scope(expects, scope, :Project, has_species_lists: "yes")
  end

  def test_project_has_comments
    expects = []
    scope = Project.has_comments.order_by_default
    assert_query_scope(expects, scope, :Project, has_comments: "yes")
  end
end
