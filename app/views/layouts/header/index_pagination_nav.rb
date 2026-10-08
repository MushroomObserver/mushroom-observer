# frozen_string_literal: true

# Pagination nav strip rendered at the top and bottom of index
# pages. `anchor:` appends a URL fragment to pagination links (only
# NamesController#index passes it). No `<form>` -- each link carries
# full query state; page-input_controller.js rewrites it client-side.
module Views::Layouts
  class Header::IndexPaginationNav < Views::Base
    include Phlex::Slotable

    slot :sorter
    slot :type_filters

    prop :pagination_data, _Nilable(::PaginationData)
    prop :position, ::Symbol, default: -> { :top }
    prop :anchor, _Nilable(::String), default: nil
    # Passed from the helper which has access to request/params.
    prop :request_url, ::String # Full URL w/ query params, for links

    def view_template
      return unless sorter_slot? || type_filters_slot? ||
                    need_letter_pagination_links? || show_number_pagination?

      div(class: "pagination-#{@position} flex-bar px-card mb-2") do
        div(class: "d-flex") do
          render(sorter_slot) if sorter_slot?
          render(type_filters_slot) if type_filters_slot?
        end
        div(class: "d-flex") do
          render_letter_pagination_nav
          render_number_pagination_nav
        end
      end
    end

    private

    def show_number_pagination?
      @pagination_data && @pagination_data.num_pages > 1
    end

    def render_letter_pagination_nav
      return unless need_letter_pagination_links?

      this_letter, letters = letter_pagination_pages

      nav(class: "paginate pagination_letters flex-bar pl-3") do
        render_letter_label
        render_letter_input(this_letter, letters)
      end
    end

    def render_letter_label
      render(Components::Navbar::Text.new(
               element: :label, for: "letter_input_#{@position}",
               class: "m-0 font-weight-normal text-nowrap"
             )) { :by_letter.l }
    end

    def render_number_pagination_nav
      return unless show_number_pagination?

      setup_letter_params
      setup_page_numbers

      nav(class: "paginate pagination_numbers flex-bar pl-3") do
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
               element: :label, for: "page_input_#{@position}",
               class: class_names("m-0 font-weight-normal text-nowrap",
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

    # No padding on the outer-facing side -- the prev/next arrows
    # should align flush with the content edge, not sit indented
    # from it.
    def render_page_link(direction, disabled:)
      page = instance_variable_get(:"@#{direction}_page")
      padding = direction == :prev ? "pl-0 pr-2" : "pl-2 pr-0"
      classes = class_names(
        padding, "#{direction}_page_link",
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

    # No <form> -- "Goto" is a plain link carrying full query state,
    # like the prev/next/max-page links. page-input_controller.js
    # rewrites its page/letter param client-side as the user types.
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
        id: "page_input_#{@position}",
        type: :text, name: :page, value: this_page,
        class: "form-control text-right",
        size: max_page.digits.count,
        # This `name` is reused identically across every index page,
        # so Chrome accumulates a large saved-value history under it
        # and offers to autofill/suggest from that history as soon as
        # the field is focused -- suppress it.
        autocomplete: "off",
        data: { page_input_target: "numberInput",
                action: "page-input#sanitizeNumber" }
      }
    end

    # goToLink target name is shared by the page and letter widgets --
    # safe since each InputGroup carries its own data-controller, so
    # goToLinkTarget only ever sees the one link in its own DOM scope.
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
      input_id = "letter_input_#{@position}"

      InputGroup(class: "page-input ml-2",
                 data: { controller: "page-input",
                         page_input_letters_value: used_letters }) do
        input(
          id: input_id,
          type: :text, name: :letter, value: this_letter,
          class: "form-control text-right",
          size: 1, placeholder: "—",
          # Same reused-name autofill exposure as the page input above.
          autocomplete: "off",
          data: { page_input_target: "letterInput",
                  action: "page-input#sanitizeLetter" }
        )
        render_goto_link(href: letter_link_url(this_letter),
                         tooltip: :goto_letter_tooltip.t(letter: this_letter))
      end
    end

    # Mirrors pagination_link_url for the letter-jump link: keys on
    # letter_arg instead of page_arg, and always clears the page
    # number, resetting pagination position within the new letter.
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
