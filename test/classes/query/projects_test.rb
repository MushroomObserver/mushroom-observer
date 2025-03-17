# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::Projects class to be included in QueryTest
class Query::ProjectsTest < UnitTestCase
  include QueryExtensions

  def test_project_all
    expects = Project.index_order
    assert_query(expects, :Project)
  end

  def test_project_by_rss_log
    expects = Project.order_by_rss_log
    assert_query(expects, :Project, by: :rss_log)
  end

  def test_project_in_set
    assert_query([projects(:eol_project).id],
                 :Project, id_in_set: [projects(:eol_project).id])
    assert_query([], :Project, id_in_set: [])
  end

  def test_project_members
    assert_query(Project.index_order.members(rolf),
                 :Project, members: [rolf])
    assert_query(Project.index_order.members(mary),
                 :Project, members: [mary])
    assert_query(Project.index_order.members(dick),
                 :Project, members: [dick])
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
    scope = Project.has_summary.index_order
    assert_query_scope(expects, scope, :Project, has_summary: "yes")
    scope = Project.has_summary(false).index_order
    assert_query(scope, :Project, has_summary: "no")
  end

  def test_project_summary_has
    expects = [projects(:empty_project)]
    scope = Project.summary_has("No Images")
    assert_query_scope(expects, scope, :Project, summary_has: "No Images")
  end

  def test_project_field_slip_prefix_has
    expects = [projects(:eol_project)]
    scope = Project.field_slip_prefix_has("EOL").index_order
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

    expects = Project.index_order
    assert_query(expects, :Project, pattern: "")
  end

  def project_pattern_search(pattern)
    Project.pattern(pattern).index_order.distinct
  end

  # These next four only handle a `true` condition
  def test_project_has_images
    expects = [projects(:lone_wolf_project), projects(:bolete_project)]
    scope = Project.has_images.index_order
    assert_query_scope(expects, scope, :Project, has_images: true)
  end

  def test_project_has_observations
    scope = Project.has_observations.index_order
    assert_query(scope, :Project, has_observations: true)
  end

  def test_project_has_species_lists
    expects = [projects(:two_list_project), projects(:lone_wolf_project),
               projects(:open_membership_project), projects(:bolete_project),
               projects(:eol_project)]
    scope = Project.has_species_lists.index_order
    assert_query_scope(expects, scope, :Project, has_species_lists: "yes")
  end

  def test_project_has_comments
    expects = []
    scope = Project.has_comments.index_order
    assert_query_scope(expects, scope, :Project, has_comments: "yes")
  end
end
