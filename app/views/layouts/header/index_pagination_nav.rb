# frozen_string_literal: true

# Pagination nav strip rendered at the top and bottom of index
# pages. Builds letter (A-Z) and number (1-N) paginators around a
# `PaginationData` instance + the request URL.
#
# `anchor:` is the URL fragment to append to every pagination link
# (e.g. `#results` so the browser scrolls to the results block
# after a page load). Only `NamesController#index` currently passes
# it; the rest use the default of nil.
#
# The view reads `q_param(current_query)` directly — index pages
# always have an `@query` set, so this collapses to the same Hash
# the helper used to pass explicitly. Tests stub `current_query`
# (via `controller.define_singleton_method`) when they want to
# verify the q-param hidden fields render.
module Views::Layouts
  class Header::IndexPaginationNav < Views::Base
    include Phlex::Slotable

    slot :sorter

    prop :pagination_data, _Nilable(::PaginationData)
    prop :position, ::Symbol, default: -> { :top }
    prop :anchor, _Nilable(::String), default: nil
    # Passed from the helper which has access to request/params.
    prop :request_url, ::String     # Full URL w/ query params, for links
    prop :form_action_url, ::String # URL w/o query params, for form actions
    prop :letter_param, _Nilable(::String)

    def view_template
      div(class: "pagination-#{@position} navbar-flex mb-2") do
        div(class: "d-flex") { render(sorter_slot) if sorter_slot? }
        div(class: "d-flex") do
          render_letter_pagination_nav
          render_number_pagination_nav
        end
      end
    end

    private

    def render_letter_pagination_nav
      return unless need_letter_pagination_links?

      this_letter, letters = letter_pagination_pages

      nav(class: "paginate pagination_letters navbar-flex pl-4") do
        Navbar(class: "mx-0") { :by_letter.l }
        render_letter_input(this_letter, letters)
      end
    end

    def render_number_pagination_nav
      return unless @pagination_data && @pagination_data.num_pages > 1

      setup_letter_params
      setup_page_numbers

      nav(class: "paginate pagination_numbers navbar-flex pl-4") do
        render_page_link(:prev, disabled: @prev_page < 1)
        render_page_label
        render_goto_page_input(@this_page, @max_page)
        render_max_page_link(@max_page)
        render_page_link(:next, disabled: @next_page > @max_page)
      end
    end

    # Carries the current letter into the per-page-link URL params so
    # the page-number nav stays within the letter-filtered subset.
    def setup_letter_params
      @page_link_params = {}
      return unless @pagination_data.letter_arg && @pagination_data.letter

      @page_link_params[@pagination_data.letter_arg] =
        @pagination_data.letter
    end

    def render_page_label
      Navbar(class: "mx-0 hidden-xs") { :PAGE.l }
    end

    def render_max_page_link(max_page)
      max_url = pagination_link_url(max_page)
      Navbar(class: "ml-0 mr-2 hidden-xs") { :of.l }
      Navbar(class: "mx-0") { a(href: max_url) { max_page.to_s } }
    end

    def setup_page_numbers
      @max_page = @pagination_data.num_pages
      @this_page = @pagination_data.number
      @this_page = 1 if @this_page < 1
      @this_page = @max_page if @this_page > @max_page
      @prev_page = @this_page - 1
      @next_page = @this_page + 1
      @page_arg = @pagination_data.number_arg
    end

    def render_page_link(direction, disabled:)
      page = instance_variable_get(:"@#{direction}_page")
      classes = class_names(
        Components::Navbar::LINK_CLASSES, "#{direction}_page_link",
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

    # Build URL for pagination links (prev/next page, max page link).
    # If `@anchor` is set, appends a URL fragment (e.g., `#results`)
    # so the browser scrolls to that element after page load.
    def pagination_link_url(page)
      params = @page_link_params.dup
      params[@page_arg] = page
      url = add_args_to_url(@request_url, params.merge(id: nil))
      if @anchor
        url.sub!(/#.*/, "")
        url += "##{@anchor}"
      end
      url
    end

    def render_goto_page_input(this_page, max_page)
      form(
        action: @form_action_url, method: :get,
        class: class_names(Components::Navbar::FORM_CLASS, "px-0 page_input"),
        data: { controller: "page-input", page_input_max_value: max_page }
      ) do
        render_page_input_group(this_page, max_page)
        render_q_hidden_fields
        render_letter_hidden_field
      end
    end

    def render_page_input_group(this_page, max_page)
      div(class: "input-group page-input mx-2") do
        input(**page_input_attrs(this_page, max_page))
        render_goto_button
      end
    end

    def page_input_attrs(this_page, max_page)
      {
        type: :text, name: :page, value: this_page,
        class: "form-control text-right",
        size: max_page.digits.count,
        data: { page_input_target: "numberInput",
                action: "page-input#sanitizeNumber" }
      }
    end

    def render_goto_button
      span(class: "input-group-btn") do
        Button(
          type: :submit,
          variant: :outline,
          class: "px-2"
        ) { Icon(type: :goto, title: :GOTO.l) }
      end
    end

    def need_letter_pagination_links?
      return false unless @pagination_data

      @pagination_data.letter_arg &&
        (@pagination_data.letter ||
          @pagination_data.num_total > @pagination_data.num_per_page) &&
        @pagination_data.used_letters &&
        @pagination_data.used_letters.length > 1
    end

    def letter_pagination_pages
      letters = @pagination_data.used_letters
      this_letter = @pagination_data.letter || ""
      [this_letter, letters]
    end

    def render_letter_input(this_letter, used_letters)
      form(
        action: @form_action_url, method: :get,
        class: class_names(Components::Navbar::FORM_CLASS, "px-0 page_input"),
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

    def render_q_hidden_fields
      q_params = q_param(current_query)
      return unless q_params

      query_string = Rack::Utils.build_nested_query({ q: q_params })
      pairs = query_string.split(Rack::Utils::DEFAULT_SEP)
      pairs.each do |pair|
        key, value = pair.split("=", 2).map { |str| Rack::Utils.unescape(str) }
        input(type: :hidden, name: key, value: value)
      end
    end

    def render_letter_hidden_field
      input(
        type: :hidden, name: :letter, value: @letter_param,
        data: { page_input_target: "letterHiddenInput",
                action: "letterUpdated@window->page-input#syncLetter" }
      )
    end
  end
end
