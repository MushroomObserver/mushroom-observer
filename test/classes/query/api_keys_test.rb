# frozen_string_literal: true

require "test_helper"
require "query_extensions"

# tests of Query::APIKeys class to be included in QueryTest
class Query::APIKeysTest < UnitTestCase
  include QueryExtensions

  def test_api_key_all
    expects = APIKey.all.index_order
    assert_query(expects, :APIKey)
  end

  def test_api_key_notes_has
    expects = APIKey.notes_has("purpose’s").index_order
    assert_query(expects, :APIKey, notes_has: "purpose’s")
  end
end
