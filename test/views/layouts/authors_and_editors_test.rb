# frozen_string_literal: true

require "test_helper"

module Views::Layouts
  class AuthorsAndEditorsTest < ComponentTestCase
    # Test double for description objects
    class TestDescription
      attr_reader :authors, :editors, :id, :type_tag

      def initialize(authors:, editors:, id: 1, type_tag: :name_description)
        @authors = authors
        @editors = editors
        @id = id
        @type_tag = type_tag
      end

      # Same rule as Description#can_review_authors?
      def can_review_authors?(user)
        return false unless user

        authors.include?(user) || user.in_group?("reviewers")
      end
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

    # Test double for version objects. Matches the
    # `mo_acts_as_versioned`-wired `belongs_to :user` API the component
    # now reads via `versions.map(&:user)`.
    class TestVersion
      attr_reader :user_id

      def initialize(user_id:)
        @user_id = user_id
      end

      def user
        User.find_by(id: @user_id)
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

      html = render_component(obj: desc, versions: [], user: nil)

      assert_includes(html, "Rolf")
      assert_includes(html, "Mary")
      assert_includes(html, "Dick")
      text = Nokogiri::HTML(html).text
      assert_match(/author/, text)
      assert_match(/[Ee]ditor/, text)
    end

    def test_reviewer_gets_review_link
      desc = TestDescription.new(authors: [users(:mary)], editors: [], id: 123)

      html = render_component(obj: desc, versions: [], user: users(:rolf))

      assert_html(html, "a[href='#{review_path(desc)}']",
                  text: "(#{:review_authors_review_authors.l})")
      assert_no_html(html, "a[href='#{request_path(desc)}']")
    end

    def test_author_gets_review_link
      mary = users(:mary)
      desc = TestDescription.new(authors: [mary], editors: [], id: 123)

      html = render_component(obj: desc, versions: [], user: mary)

      assert_html(html, "a[href='#{review_path(desc)}']")
    end

    def test_other_user_gets_request_link
      desc = TestDescription.new(authors: [users(:dick)], editors: [], id: 123)

      html = render_component(obj: desc, versions: [], user: users(:mary))

      assert_html(html, "a[href='#{request_path(desc)}']",
                  text: "(#{:show_description_author_request.l})")
      assert_no_html(html, "a[href='#{review_path(desc)}']")
    end

    def test_no_authors_link_when_logged_out
      desc = TestDescription.new(authors: [users(:dick)], editors: [], id: 123)

      html = render_component(obj: desc, versions: [], user: nil)

      assert_no_html(html, "a[href='#{review_path(desc)}']")
      assert_no_html(html, "a[href='#{request_path(desc)}']")
    end

    def test_description_with_empty_authors_list
      desc = TestDescription.new(
        authors: [],
        editors: [users(:dick)]
      )

      html = render_component(obj: desc, versions: [], user: nil)

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

      html = render_component(obj: obj, versions: versions, user: nil)

      assert_includes(html, "Rolf")
      assert_includes(html, "Mary")
      assert_includes(html, "Dick")
      assert_includes(html, "Katrina")
      # Should show creator and editors
      assert_match(/[Ee]ditor/, Nokogiri::HTML(html).text)
    end

    def test_non_description_object_without_versions
      rolf = users(:rolf)
      obj = TestObject.new(user: rolf, type_tag: :location)

      html = render_component(obj: obj, versions: [], user: nil)

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

      html = render_component(obj: obj, versions: versions, user: nil)

      assert_includes(html, "Rolf")
      # Rolf should only appear once as creator, not as editor
      assert_equal(1, html.scan("Rolf").length)
      # Mary should appear as editor
      assert_includes(html, "Mary")
    end

    def test_with_real_name_fixture
      name = names(:fungi)
      versions = name.versions.to_a

      html = render_component(obj: name, versions: versions, user: users(:rolf))

      assert_not_nil(html)
      # Should render without errors
    end

    def test_with_real_location_fixture
      location = locations(:albion)
      versions = location.versions.to_a

      html = render_component(obj: location, versions: versions,
                              user: users(:rolf))

      assert_not_nil(html)
    end

    def test_type_tag_detection_for_descriptions
      desc = TestDescription.new(
        authors: [users(:rolf)],
        editors: [],
        type_tag: :name_description
      )

      html = render_component(obj: desc, versions: [], user: nil)

      assert_includes(html, "Rolf")
    end

    def test_type_tag_detection_for_non_descriptions
      obj = TestObject.new(
        user: users(:rolf),
        type_tag: :glossary_term
      )

      html = render_component(obj: obj, versions: [], user: nil)

      assert_includes(html, "Rolf")
    end

    def test_description_with_integer_user_id_in_authors_list
      # Test case where authors list contains an integer user ID
      # instead of a User object (edge case for render_user_link)
      user_id = users(:rolf).id

      desc = TestDescription.new(
        authors: [user_id],
        editors: []
      )

      html = render_component(obj: desc, versions: [], user: nil)

      # Should render "User #<id>" when given an integer
      assert_includes(html, "User ##{user_id}")
      assert_includes(html, "user_link_#{user_id}")
    end

    private

    def render_component(**)
      render(AuthorsAndEditors.new(**))
    end

    def review_path(desc)
      routes.description_authors_path(id: desc.id, type: desc.type_tag)
    end

    def request_path(desc)
      routes.new_description_author_requests_path(id: desc.id,
                                                  type: desc.type_tag)
    end

    def routes
      Rails.application.routes.url_helpers
    end
  end
end
