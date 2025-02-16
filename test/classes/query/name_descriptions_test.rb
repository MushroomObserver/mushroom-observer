# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::NameDescriptions class to be included in QueryTest
class Query::NameDescriptionsTest < UnitTestCase
  include QueryExtensions

  def test_name_description_all
    pelt = names(:peltigera)
    all_descs = NameDescription.all.to_a
    all_pelt_descs = NameDescription.where(name: pelt).to_a
    public_pelt_descs = NameDescription.where(name: pelt, public: true).to_a
    assert(all_pelt_descs.length < all_descs.length)
    assert(public_pelt_descs.length < all_pelt_descs.length)

    assert_query(all_descs, :NameDescription, by: :id)
    assert_query(all_pelt_descs, :NameDescription, by: :id, names: pelt)
    assert_query(public_pelt_descs, :NameDescription,
                 by: :id, names: pelt, public: "yes")
  end

  def test_name_description_by_user
    expects = NameDescription.where(user: mary).order(:id)
    assert_query(expects, :NameDescription, by_user: mary, by: :id)

    expects = NameDescription.where(user: katrina).order(:id)
    assert_query(expects, :NameDescription, by_user: katrina, by: :id)

    assert_query([], :NameDescription, by_user: junk, by: :id)
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
    assert_query([],
                 :NameDescription, ids: rolf.id)
    assert_query(NameDescription.all,
                 :NameDescription, ids: NameDescription.select(:id).to_a)
    assert_query([NameDescription.first.id],
                 :NameDescription,
                 ids: [rolf.id, NameDescription.first.id])
  end

  def test_name_description_with_default_desc
    assert_query(NameDescription.is_default.index_order,
                 :NameDescription, with_default_desc: 1)
    assert_query(NameDescription.is_not_default.index_order,
                 :NameDescription, with_default_desc: 0)
  end

  def test_name_description_desc_type_user
    assert_query(NameDescription.where(source_type: 5).index_order,
                 :NameDescription, desc_type: "user")
  end

  def test_name_description_desc_type_project
    assert_query(NameDescription.where(source_type: 3).index_order,
                 :NameDescription, desc_type: "project")
  end

  def test_name_description_desc_project
    assert_query(NameDescription.
                 where(project: projects(:eol_project)).index_order,
                 :NameDescription, desc_project: projects(:eol_project).id)
  end

  def test_name_description_desc_creator
    assert_query(NameDescription.where(user: rolf).index_order,
                 :NameDescription, desc_creator: rolf.id)
    assert_query(NameDescription.where(user: mary).index_order,
                 :NameDescription, desc_creator: mary.id)
  end

  # waiting on a new AbstractModel scope for searches,
  # plus a specific NameDescription scope coalescing the fields.
  def test_name_description_desc_content
    assert_query(NameDescription.search_content('"some notes"').index_order,
                 :NameDescription, desc_content: '"some notes"')
  end

  def test_name_description_ok_for_export
    assert_query(NameDescription.where(ok_for_export: 1).index_order,
                 :NameDescription, ok_for_export: 1)
    assert_query(NameDescription.where(ok_for_export: 0).index_order,
                 :NameDescription, ok_for_export: 0)
  end
end
