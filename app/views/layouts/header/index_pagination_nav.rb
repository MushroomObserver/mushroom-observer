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
# The page-number/letter inputs aren't inside a `<form>` -- each
# "Goto" control is a plain link carrying the full current query
# state (via `request_url`), same as the prev/next/max-page links.
# `page-input_controller.js` rewrites a goto link's own `page`/
# `letter` param (and its tooltip text) as the user types, so no
# submission round-trip is needed.
module Views::Layouts
  class Header::IndexPaginationNav < Views::Base
    include Phlex::Slotable

    slot :sorter

    prop :pagination_data, _Nilable(::PaginationData)
    prop :position, ::Symbol, default: -> { :top }
    prop :anchor, _Nilable(::String), default: nil
    # Passed from the helper which has access to request/params.
    prop :request_url, ::String # Full URL w/ query params, for links

    def view_template
      div(class: "pagination-#{@position} flex-bar mb-2") do
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

      nav(class: "paginate pagination_letters flex-bar pl-4") do
        render(Components::Navbar::Text.new(class: "mx-0")) { :by_letter.l }
        render_letter_input(this_letter, letters)
      end
    end

    def render_number_pagination_nav
      return unless @pagination_data && @pagination_data.num_pages > 1

      setup_letter_params
      setup_page_numbers

      nav(class: "paginate pagination_numbers flex-bar pl-4") do
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
      render(Components::Navbar::Text.new(
               class: class_names("mx-0",
                                  Components::Column.mobile_hide_classes)
             )) { :page.ti }
    end

    def render_max_page_link(max_page)
      max_url = pagination_link_url(max_page)
      render(Components::Navbar::Text.new(
               class: class_names("ml-0 mr-2",
                                  Components::Column.mobile_hide_classes)
             )) do
        :of.l
      end
      render(Components::Navbar::Text.new(class: "mx-0")) do
        a(href: max_url) { max_page.to_s }
      end
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

      Link(type: :get, name: direction.to_s.to_sym.ti, target: url,
           icon: direction, button: :link, size: :lg, class: classes)
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

    # No <form> -- the input is a free element, and "Goto" is a plain
    # link like the prev/next/max-page links, carrying the full
    # current query state (via pagination_link_url's request_url base)
    # from the moment it's rendered. page-input_controller.js rewrites
    # the link's own `page`/`letter` param (and its tooltip text) as
    # the user types, so no submission round-trip is needed.
    def render_goto_page_input(this_page, max_page)
      InputGroup(class: "page-input mx-2",
                 data: { controller: "page-input",
                         page_input_max_value: max_page }) do
        input(**page_input_attrs(this_page, max_page))
        render_goto_link(href: pagination_link_url(this_page),
                         tooltip: :goto_page_tooltip.t(number: this_page))
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

    # `goToLink` target name is shared by both the page and letter
    # widgets -- safe since page-input is instantiated once per
    # InputGroup (two separate elements each carry their own
    # data-controller="page-input"), so each instance's
    # `this.goToLinkTarget` sees only the one link in its own DOM
    # scope.
    def render_goto_link(href:, tooltip:)
      render(Components::InputGroup::Addon.new) do
        Link(
          type: :get, name: :goto.ti, target: href, button: :outline,
          class: "px-2", data: { page_input_target: "goToLink" }
        ) { Icon(type: :goto, title: tooltip) }
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
      InputGroup(class: "page-input ml-2",
                 data: { controller: "page-input",
                         page_input_letters_value: used_letters }) do
        input(
          type: :text, name: :letter, value: this_letter,
          class: "form-control text-right",
          size: 1, placeholder: "—",
          data: { page_input_target: "letterInput",
                  action: "page-input#sanitizeLetter" }
        )
        render_goto_link(href: letter_link_url(this_letter),
                         tooltip: :goto_letter_tooltip.t(letter: this_letter))
      end
    end

    # Mirrors pagination_link_url, but for the letter-jump link: keys
    # on letter_arg instead of page_arg, and always clears the page
    # number -- jumping to a new letter resets pagination position
    # within that letter's subset, matching the old form's behavior
    # (it had no page field, so submitting it always dropped whatever
    # page the address bar had).
    def letter_link_url(letter)
      params = { @pagination_data.letter_arg => letter,
                 @pagination_data.number_arg => nil }
      url = add_args_to_url(@request_url, params.merge(id: nil))
      if @anchor
        url.sub!(/#.*/, "")
        url += "##{@anchor}"
      end
      url
    end
  end
end
