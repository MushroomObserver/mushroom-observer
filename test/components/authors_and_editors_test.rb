# frozen_string_literal: true

require "test_helper"

class AuthorsAndEditorsTest < UnitTestCase
  include ComponentTestHelper

  # Test double for description objects
  class TestDescription
    attr_reader :authors, :editors, :id, :type_tag

    def initialize(authors:, editors:, id: 1, type_tag: :name_description)
      @authors = authors
      @editors = editors
      @id = id
      @type_tag = type_tag
    end

    def admin?(user)
      user&.admin?
    end

    alias is_admin? admin?
  end

  # Test double for non-description objects
  class TestObject
    attr_reader :user, :user_id, :type_tag

    def initialize(user:, user_id: nil, type_tag: :name)
      @user = user
      @user_id = user_id || user&.id
      @type_tag = type_tag
    end
  end

  # Test double for version objects
  class TestVersion
    attr_reader :user_id

    def initialize(user_id:)
      @user_id = user_id
    end
  end

  def test_description_with_authors_and_editors
    rolf = users(:rolf)
    mary = users(:mary)
    dick = users(:dick)

    desc = TestDescription.new(
      authors: [rolf, mary],
      editors: [dick]
    )

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: desc,
                              versions: [],
                              user: nil
                            ))

    assert_includes(html, "Rolf")
    assert_includes(html, "Mary")
    assert_includes(html, "Dick")
    assert_match(/author/, html)
    assert_match(/[Ee]ditor/, html)
  end

  def test_description_with_admin_user
    rolf = users(:rolf)
    mary = users(:mary)

    desc = TestDescription.new(
      authors: [mary],
      editors: [],
      id: 123
    )

    # Make rolf an admin for this test
    def rolf.admin?
      true
    end

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: desc,
                              versions: [],
                              user: rolf
                            ))

    assert_includes(html, "Mary")
    # Component should render successfully for admin users
    assert_not_nil(html)
  end

  def test_description_with_non_author_user
    rolf = users(:rolf)
    mary = users(:mary)

    desc = TestDescription.new(
      authors: [mary],
      editors: [],
      id: 123
    )

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: desc,
                              versions: [],
                              user: rolf
                            ))

    assert_includes(html, "Mary")
    # Component should render successfully for non-author users
    assert_not_nil(html)
  end

  def test_description_with_author_user_no_extra_link
    rolf = users(:rolf)
    mary = users(:mary)

    desc = TestDescription.new(
      authors: [rolf, mary],
      editors: [],
      id: 123
    )

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: desc,
                              versions: [],
                              user: rolf
                            ))

    assert_includes(html, "Rolf")
    assert_includes(html, "Mary")
    # Should not have review/request link since user is an author
    assert_not_includes(html, "Review")
  end

  def test_description_with_empty_authors_list
    desc = TestDescription.new(
      authors: [],
      editors: [users(:dick)]
    )

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: desc,
                              versions: [],
                              user: nil
                            ))

    # Should render without error even with no authors
    assert_not_nil(html)
    assert_includes(html, "Dick")
  end

  def test_non_description_object_with_versions
    rolf = users(:rolf)
    mary = users(:mary)
    dick = users(:dick)
    katrina = users(:katrina)

    obj = TestObject.new(user: rolf, type_tag: :name)
    versions = [
      TestVersion.new(user_id: rolf.id),
      TestVersion.new(user_id: mary.id),
      TestVersion.new(user_id: dick.id),
      TestVersion.new(user_id: katrina.id)
    ]

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: obj,
                              versions: versions,
                              user: nil
                            ))

    assert_includes(html, "Rolf")
    assert_includes(html, "Mary")
    assert_includes(html, "Dick")
    assert_includes(html, "Katrina")
    # Should show creator and editors
    assert_match(/[Ee]ditor/, html)
  end

  def test_non_description_object_without_versions
    rolf = users(:rolf)
    obj = TestObject.new(user: rolf, type_tag: :location)

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: obj,
                              versions: [],
                              user: nil
                            ))

    assert_includes(html, "Rolf")
    # Should show user who defined/created the object
    # Should have no editors
    assert_not_includes(html, "Editor")
  end

  def test_non_description_object_filters_out_creator_from_editors
    rolf = users(:rolf)
    mary = users(:mary)

    obj = TestObject.new(user: rolf, type_tag: :name)
    versions = [
      TestVersion.new(user_id: rolf.id),
      TestVersion.new(user_id: rolf.id), # Same user edited multiple times
      TestVersion.new(user_id: mary.id)
    ]

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: obj,
                              versions: versions,
                              user: nil
                            ))

    assert_includes(html, "Rolf")
    # Rolf should only appear once as creator, not as editor
    assert_equal(1, html.scan("Rolf").length)
    # Mary should appear as editor
    assert_includes(html, "Mary")
  end

  def test_with_real_name_fixture
    name = names(:fungi)
    versions = name.versions.to_a

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: name,
                              versions: versions,
                              user: users(:rolf)
                            ))

    assert_not_nil(html)
    # Should render without errors
  end

  def test_with_real_location_fixture
    location = locations(:albion)
    versions = location.versions.to_a

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: location,
                              versions: versions,
                              user: users(:rolf)
                            ))

    assert_not_nil(html)
  end

  def test_with_collection_proxy_versions
    name = names(:fungi)
    # Pass the collection proxy directly
    versions = name.versions

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: name,
                              versions: versions,
                              user: users(:rolf)
                            ))

    assert_not_nil(html)
    # Should handle ActiveRecord::Associations::CollectionProxy
  end

  def test_type_tag_detection_for_descriptions
    desc = TestDescription.new(
      authors: [users(:rolf)],
      editors: [],
      type_tag: :name_description
    )

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: desc,
                              versions: [],
                              user: nil
                            ))

    assert_includes(html, "Rolf")
  end

  def test_type_tag_detection_for_non_descriptions
    obj = TestObject.new(
      user: users(:rolf),
      type_tag: :glossary_term
    )

    html = render_component(Components::AuthorsAndEditors.new(
                              obj: obj,
                              versions: [],
                              user: nil
                            ))

    assert_includes(html, "Rolf")
  end
end
