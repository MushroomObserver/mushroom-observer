# frozen_string_literal: true

require("test_helper")

# TEMPORARY — HTML parity check for the Components::Navbar conversion
# (PR: Navbar componentization). Each "Old" subclass below overrides
# only the specific private method(s) touched by that PR with their
# pre-conversion bodies (verbatim from the parent commit before the
# Navbar commit), leaving everything else inherited from the real,
# current class. Renders both old and new with identical inputs and
# diffs the relevant fragment via `assert_html_element_equivalent`.
#
# Delete this whole file once the PR is confirmed to introduce no
# HTML drift — see ".claude/rules/phlex_reference.md" parity-harness
# patterns ("Delete the `_Old` copy and the parity test together").
module Views::Layouts
  class NavbarComponentParityTest < ComponentTestCase
    # ---- header/sorter.rb ----------------------------------------------

    class Header::SorterOld < Header::Sorter
      def view_template
        return unless visible?

        ul(class: "list-unstyled navbar-flex pl-3 sorter") do
          li(class: "navbar-text mx-0 hidden-xs") do
            plain("#{:sort_by_header.l}:")
          end
          Dropdown(
            id: "sort_nav_toggle",
            menu_id: "sort_nav_menu",
            label: toggle_title.to_s,
            wrapper_class: "navbar-form px-2",
            toggle_variant: :outline, toggle_size: :sm,
            toggle_class: "font-weight-normal",
            menu_class: "sorts",
            menu_header: mobile_header_html
          ) do |menu|
            menu.section(sort_tuples)
          end
        end
      end
    end

    def test_sorter_parity
      controller.params[:controller] = "names"
      controller.params[:action] = "index"
      controller.define_singleton_method(:controller_model_name) { "Name" }
      sorts = [["created_at", :sort_by_created_at.t]]
      query = ::Query.lookup(:Name, order_by: "created_at")
      query.save
      query.define_singleton_method(:num_results) { 5 }

      old_html = render(Header::SorterOld.new(query: query, sorts: sorts))
      new_html = render(Header::Sorter.new(query: query, sorts: sorts))

      assert_html_element_equivalent(old_html, new_html, selector: "ul",
                                                         label: "sorter")
    end

    # ---- top_nav/search_bar.rb -----------------------------------------

    class TopNav::SearchBarOld < TopNav::SearchBar
      def view_template
        if current_user
          render_logged_in
        else
          strong(class: "navbar-text mx-2 text-nowrap") do
            plain(:app_login_reminder.t)
          end
        end
      end
    end

    def test_search_bar_login_reminder_parity
      controller.define_singleton_method(:current_user) { nil }

      old_html = render(TopNav::SearchBarOld.new(
                          search_help_types: [], search_form_types: []
                        ))
      new_html = render(TopNav::SearchBar.new(
                          search_help_types: [], search_form_types: []
                        ))

      assert_html_element_equivalent(old_html, new_html, selector: "strong",
                                                         label: "search_bar")
    end

    # ---- header/show_prev_next_nav.rb -----------------------------------

    class Header::ShowPrevNextNavOld < Header::ShowPrevNextNav
      OLD_BTN_CLASSES = %w[navbar-link navbar-left btn btn-lg px-0].freeze

      private

      def render_adjacent_link(dir)
        hide = no_more?(dir) ? "disabled opacity-0" : ""
        classes = class_names(OLD_BTN_CLASSES, "#{dir}_object_link", hide)
        adjacent_id = @query.send(:"#{dir}_id")
        href = adjacent_id ? adjacent_path(adjacent_id) : "#"

        Link(type: :icon, content: adjacent_title(dir), path: href,
             icon: dir, class: classes)
      end

      def render_index_link
        classes = class_names(OLD_BTN_CLASSES, %w[mx-1 index_object_link])

        Link(type: :icon, content: index_title, path: index_path,
             icon: index_icon, class: classes)
      end
    end

    def test_show_prev_next_nav_parity
      query = Query.lookup(:Observation, by: :id)
      obs = Observation.find(query.result_ids[2])

      old_html = render(Header::ShowPrevNextNavOld.new(object: obs,
                                                       query: query))
      new_html = render(Header::ShowPrevNextNav.new(object: obs,
                                                    query: query))

      assert_html_element_equivalent(old_html, new_html, selector: "ul",
                                                         label: "prev_next")
    end

    # ---- top_nav.rb -------------------------------------------------------

    class TopNavOld < ::Views::Layouts::TopNav
      private

      def render_search_nav_toggle
        div(class: "navbar-form px-2 px-sm-3") do
          Button(
            variant: :outline, size: :sm,
            class: "top_nav_button",
            data: { toggle: "collapse", target: "#search_nav" },
            aria: { expanded: "false", controls: "search_nav" }
          ) { Icon(type: :search, title: :SEARCH.l) }
        end
      end

      # Same neutralization as `TopNavTest::TopNavWithoutSearchRow` —
      # avoids resolving view paths that aren't on the test
      # controller's `append_view_path`.
      def render_search_row
        nil
      end
    end

    class TopNavNewWithoutSearchRow < ::Views::Layouts::TopNav
      private

      def render_search_row
        nil
      end
    end

    def test_top_nav_search_toggle_parity
      @user = users(:rolf)
      controller.define_singleton_method(:controller_name) { "observations" }
      controller.define_singleton_method(:controller_path) { "observations" }
      [:new, :index, :show].each do |action|
        controller.define_singleton_method(:"#{action}?") { true }
      end

      old_html = render(TopNavOld.new(user: @user))
      new_html = render(TopNavNewWithoutSearchRow.new(user: @user))

      assert_html_element_equivalent(
        old_html, new_html,
        selector: "div.navbar-form", label: "top_nav_search_toggle"
      )
    end

    # ---- header/index_pagination_nav.rb ---------------------------------

    class Header::IndexPaginationNavOld < Header::IndexPaginationNav
      OLD_LINK_CLASSES = %w[navbar-link btn btn-lg px-0].freeze

      private

      def render_letter_pagination_nav
        return unless need_letter_pagination_links?

        this_letter, letters = letter_pagination_pages

        nav(class: "paginate pagination_letters navbar-flex pl-4") do
          div(class: "navbar-text mx-0") { :by_letter.l }
          render_letter_input(this_letter, letters)
        end
      end

      def render_page_label
        div(class: "navbar-text mx-0 hidden-xs") { :PAGE.l }
      end

      def render_max_page_link(max_page)
        max_url = pagination_link_url(max_page)
        div(class: "navbar-text ml-0 mr-2 hidden-xs") { :of.l }
        div(class: "navbar-text mx-0") { a(href: max_url) { max_page.to_s } }
      end

      def render_page_link(direction, disabled:)
        page = instance_variable_get(:"@#{direction}_page")
        classes = class_names(
          OLD_LINK_CLASSES, "#{direction}_page_link",
          ("disabled opacity-0" if disabled)
        )
        url = pagination_link_url(page)
        a(href: url, class: classes) do
          Icon(
            type: direction,
            title: direction.to_s.upcase.to_sym.t,
            html_class: "px-2"
          )
        end
      end

      def render_goto_page_input(this_page, max_page)
        form(
          action: @form_action_url, method: :get,
          class: "navbar-form px-0 page_input",
          data: { controller: "page-input", page_input_max_value: max_page }
        ) do
          render_page_input_group(this_page, max_page)
          render_q_hidden_fields
          render_letter_hidden_field
        end
      end

      def render_letter_input(this_letter, used_letters)
        form(
          action: @form_action_url, method: :get,
          class: "navbar-form px-0 page_input",
          data: { controller: "page-input",
                  page_input_letters_value: used_letters }
        ) do
          div(class: "input-group page-input ml-2") do
            input(
              type: :text, name: :letter, value: this_letter,
              class: "form-control text-right",
              size: 1, placeholder: "—",
              data: { page_input_target: "letterInput",
                      action: "page-input#sanitizeLetter" }
            )
            render_goto_button
          end
          render_q_hidden_fields
        end
      end
    end

    def test_index_pagination_nav_parity
      request_url = "/observations?q%5Bmodel%5D=Observation"
      form_action_url = "http://test.host/observations"
      pagination_data = ::PaginationData.new(
        number: 1, num_per_page: 10, num_total: 50, number_arg: :page
      )
      pagination_data_with_letters = ::PaginationData.new(
        number: 1, num_per_page: 10, num_total: 50, number_arg: :page,
        letter_arg: :letter, used_letters: %w[A B C]
      )

      [pagination_data, pagination_data_with_letters].each do |data|
        old_html = render(Header::IndexPaginationNavOld.new(
                            position: :top, request_url: request_url,
                            form_action_url: form_action_url,
                            pagination_data: data
                          ))
        new_html = render(Header::IndexPaginationNav.new(
                            position: :top, request_url: request_url,
                            form_action_url: form_action_url,
                            pagination_data: data
                          ))

        assert_html_element_equivalent(
          old_html, new_html,
          selector: "div.pagination-top", label: "index_pagination_nav"
        )
      end
    end

    # ---- controllers/observations/identify/form.rb ---------------------

    class IdentifyFormOld <
        ::Views::Controllers::Observations::Identify::Form
      private

      def form_attributes
        {
          id: @attributes[:id],
          class: "navbar-flex flex-grow-1 navbar-form px-0 gap-2",
          data: { controller: initial_controller,
                  type: selected }
        }
      end
    end

    def test_identify_form_parity
      model = FormObject::IdentifyFilter.new(type: nil, term: nil)

      old_html = render(IdentifyFormOld.new(model))
      new_html = render(
        ::Views::Controllers::Observations::Identify::Form.new(model)
      )

      assert_html_element_equivalent(old_html, new_html, selector: "form",
                                                         label: "identify_form")
    end
  end
end
