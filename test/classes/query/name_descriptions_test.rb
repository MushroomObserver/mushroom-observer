# frozen_string_literal: true

require("test_helper")
require("query_extensions")

# tests of Query::NameDescriptions class to be included in QueryTest
class Query::NameDescriptionsTest < UnitTestCase
  include QueryExtensions

  def test_name_description_all
    all_descs = NameDescription.order_by_default
    all_pelt_descs = NameDescription.names(lookup: "Peltigera").order_by_default
    public_pelt_descs = all_pelt_descs.is_public.order_by_default
    assert(all_pelt_descs.length < all_descs.length)
    assert(public_pelt_descs.length < all_pelt_descs.length)

    assert_query(all_descs, :NameDescription)
    assert_query(
      all_pelt_descs,
      :NameDescription, names: { lookup: "Peltigera" }
    )
    assert_query(
      public_pelt_descs,
      :NameDescription, names: { lookup: "Peltigera" }, is_public: "yes"
    )
  end

  def test_name_description_order_by_name
    expects = NameDescription.order_by(:name)
    assert_query(expects, :NameDescription, order_by: :name)
  end

  def test_name_description_by_user
    expects = NameDescription.where(user: mary).order(:id)
    assert_query(expects, :NameDescription, by_users: mary, order_by: :id)

    expects = NameDescription.where(user: katrina).order(:id)
    assert_query(expects, :NameDescription, by_users: katrina, order_by: :id)

    assert_query([], :NameDescription, by_users: junk, order_by: :id)
  end

  def test_name_description_by_author
    expects = NameDescription.joins(:name_description_authors).
              where(name_description_authors: { user_id: rolf }).order(:id)
    assert_query(expects, :NameDescription, by_author: rolf, order_by: :id)

    expects = NameDescription.joins(:name_description_authors).
              where(name_description_authors: { user_id: mary }).order(:id)
    assert_query(expects, :NameDescription, by_author: mary, order_by: :id)

    assert_query([], :NameDescription, by_author: junk)
  end

  def test_name_description_by_editor
    expects = NameDescription.joins(:name_description_editors).
              where(name_description_editors: { user_id: rolf }).order(:id)
    scope = NameDescription.by_editor(rolf)
    assert_query_scope(expects, scope, :NameDescription, by_editor: rolf)

    expects = NameDescription.joins(:name_description_editors).
              where(name_description_editors: { user_id: mary }).order(:id)
    scope = NameDescription.by_editor(mary)
    assert_query_scope(expects, scope, :NameDescription, by_editor: mary)

    assert_query([], :NameDescription, by_editor: dick)
  end

  def test_name_description_in_set
    assert_query([], :NameDescription, id_in_set: rolf.id)
    set = NameDescription.order_by_default.limit(3).map(&:id)
    assert_query_scope(
      set, NameDescription.id_in_set(set),
      :NameDescription, id_in_set: set
    )
    set = [NameDescription.first.id]
    assert_query_scope(
      set, NameDescription.id_in_set(set),
      :NameDescription, id_in_set: set
    )
  end

  def test_name_description_has_default_description
    expects = NameDescription.is_default.order_by_default
    scope = NameDescription.joins(:name).distinct.
            merge(Name.has_default_description).order_by_default
    assert_query_scope(
      expects, scope,
      :NameDescription, name_query: { has_default_description: 1 }
    )
    expects = NameDescription.is_not_default.order_by_default
    scope = NameDescription.joins(:name).distinct.
            merge(Name.has_default_description(false)).order_by_default
    assert_query_scope(
      expects, scope,
      :NameDescription, name_query: { has_default_description: 0 }
    )
  end

  def test_name_description_desc_sources_user
    assert_query(NameDescription.sources("user").order_by_default,
                 :NameDescription, sources: "user")
  end

  def test_name_description_type_project
    assert_query(NameDescription.sources(3).order_by_default,
                 :NameDescription, sources: "project")
  end

  def test_name_description_projects
    project = projects(:eol_project).id
    assert_query(NameDescription.projects(project).order_by_default,
                 :NameDescription, projects: project)
  end

  # waiting on a new AbstractModel scope for searches,
  # plus a specific NameDescription scope coalescing the fields.
  def test_name_description_content_has
    assert_query(NameDescription.content_has('"some notes"').order_by_default,
                 :NameDescription, content_has: '"some notes"')
  end

  def test_name_description_ok_for_export
    assert_query(NameDescription.ok_for_export(1).order_by_default,
                 :NameDescription, ok_for_export: 1)
    assert_query(NameDescription.ok_for_export(0).order_by_default,
                 :NameDescription, ok_for_export: 0)
  end

  def test_name_description_is_public
    assert_query(NameDescription.is_public(1).order_by_default,
                 :NameDescription, is_public: 1)
    assert_query(NameDescription.is_public(0).order_by_default,
                 :NameDescription, is_public: 0)
  end

  def test_name_description_names
    expects = [name_descriptions(:peltigera_alt_desc),
               name_descriptions(:peltigera_source_desc),
               name_descriptions(:peltigera_desc),
               name_descriptions(:peltigera_user_desc)]
    scope = NameDescription.names(lookup: "Peltigera", include_synonyms: true).
            order_by_default
    assert_query_scope(
      expects, scope,
      :NameDescription, names: { lookup: "Peltigera", include_synonyms: true }
    )
  end
end
