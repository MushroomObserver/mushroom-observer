# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::ExternalLinks class to be included in QueryTest
class Query::ExternalSitesTest < UnitTestCase
  include QueryExtensions

  def test_external_link_all
    assert_query(ExternalSite.order_by_default, :ExternalSite)
  end

  def test_external_link_order_by_name
    expects = ExternalSite.order_by(:name)
    assert_query(expects, :ExternalSite, order_by: :name)
  end

  def test_external_link_name_has
    expects = ExternalSite.name_has("MycoPortal")
    assert_query(expects, :ExternalSite, name_has: "MycoPortal")
  end
end
