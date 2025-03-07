# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::NameDescriptions class to be included in QueryTest
class Query::NameDescriptionsTest < UnitTestCase
  include QueryExtensions

  def test_name_description_all
    pelt = names(:peltigera)
    all_descs = NameDescription.all
    all_pelt_descs = NameDescription.names(pelt)
    public_pelt_descs = all_pelt_descs.is_public
    assert(all_pelt_descs.length < all_descs.length)
    assert(public_pelt_descs.length < all_pelt_descs.length)

    assert_query(all_descs, :NameDescription, by: :id)
    assert_query(all_pelt_descs, :NameDescription, by: :id, names: pelt)
    assert_query(public_pelt_descs,
                 :NameDescription, by: :id, names: pelt, is_public: "yes")
  end

  def test_name_description_by_user
    expects = NameDescription.where(user: mary).order(:id)
    assert_query(expects, :NameDescription, by_users: mary, by: :id)

    expects = NameDescription.where(user: katrina).order(:id)
    assert_query(expects, :NameDescription, by_users: katrina, by: :id)

    assert_query([], :NameDescription, by_users: junk, by: :id)
  end

  def test_name_description_by_author
    expects = NameDescription.joins(:name_description_authors).
              where(name_description_authors: { user_id: rolf }).order(:id)
    assert_query(expects, :NameDescription, by_author: rolf, by: :id)

    expects = NameDescription.joins(:name_description_authors).
              where(name_description_authors: { user_id: mary }).order(:id)
    assert_query(expects, :NameDescription, by_author: mary, by: :id)

    assert_query([], :NameDescription, by_author: junk)
  end

  def test_name_description_by_editor
    expects = NameDescription.joins(:name_description_editors).
              where(name_description_editors: { user_id: rolf }).order(:id)
    assert_query(expects, :NameDescription, by_editor: rolf)

    expects = NameDescription.joins(:name_description_editors).
              where(name_description_editors: { user_id: mary }).order(:id)
    assert_query(expects, :NameDescription, by_editor: mary)

    assert_query([], :NameDescription, by_editor: dick)
  end

  def test_name_description_in_set
    assert_query([], :NameDescription, id_in_set: rolf.id)
    assert_query(
      NameDescription.all,
      :NameDescription, id_in_set: NameDescription.pluck(:id)
    )
    assert_query(
      [NameDescription.first.id],
      :NameDescription, id_in_set: [rolf.id, NameDescription.first.id]
    )
  end

  def test_name_description_has_default_description
    assert_query(NameDescription.is_default.index_order,
                 :NameDescription, name_query: { has_default_description: 1 })
    assert_query(NameDescription.is_not_default.index_order,
                 :NameDescription, name_query: { has_default_description: 0 })
  end

  def test_name_description_type_user
    assert_query(NameDescription.types(5).index_order,
                 :NameDescription, types: "user")
  end

  def test_name_description_type_project
    assert_query(NameDescription.types(3).index_order,
                 :NameDescription, types: "project")
  end

  def test_name_description_projects
    assert_query(NameDescription.projects(projects(:eol_project)).index_order,
                 :NameDescription, projects: projects(:eol_project).id)
  end

  # waiting on a new AbstractModel scope for searches,
  # plus a specific NameDescription scope coalescing the fields.
  def test_name_description_content_has
    assert_query(NameDescription.content_has('"some notes"').index_order,
                 :NameDescription, content_has: '"some notes"')
  end

  def test_name_description_ok_for_export
    assert_query(NameDescription.ok_for_export(1).index_order,
                 :NameDescription, ok_for_export: 1)
    assert_query(NameDescription.ok_for_export(0).index_order,
                 :NameDescription, ok_for_export: 0)
  end
end
