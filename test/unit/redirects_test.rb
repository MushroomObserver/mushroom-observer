# frozen_string_literal: true

require("test_helper")

# Test existence of redirect routes
class RedirectsTest < UnitTestCase
  # Test existence of correct routes from MO old-style CRUDISH actions
  # to normalized, resourceful Crud
  def test_redirect_old_crud_actions
    routes = `rails routes`
    [
      { methods: "GET",
        from: "/article(.:format)",
        to: "/articles" },
      { methods: "GET",
        from: "/article/index_article(.:format)",
        to: "/articles" },
      { methods: "GET",
        from: "/article/list_article(.:format)",
        to: "/articles" },
      { methods: "GET",
        from: "/article/show_article/:id(.:format)",
        to: "/articles/%{id}" },
      { methods: "GET|POST",
        from: "/article/create_article(.:format)",
        to: "/articles/new" },
      { methods: "GET|POST",
        from: "/article/edit_article/:id(.:format)",
        to: "/articles/%{id}/edit" },
      { methods: "PATCH|POST|PUT",
        from: "/article/destroy_article/:id(.:format)",
        to: "/articles/%{id}" }
    ].each do |route|
      assert(/
              #{Regexp.escape(route[:methods])} \s+
              #{Regexp.escape(route[:from])} \s+
              #{Regexp.escape("redirect(301, #{route[:to]})")}
             /x =~ routes,
             "Missing route: \n #{route}")
    end
  end
end
