# frozen_string_literal: true

module Header
  module IndexPaginationHelper
    # Letters used as text in pagination links
    LETTERS = ("A".."Z")

    def add_pagination(pagination_data, args = {})
      content_for(:index_pagination_top) do
        index_pagination(pagination_data, args, position: :top)
      end
      return unless pagination_data && pagination_data.num_pages > 1

      content_for(:index_pagination_bottom) do
        index_pagination(pagination_data, args, position: :bottom)
      end
    end

    # Wrap a block in pagination links.  Includes letters if appropriate.
    #
    #   <%= pagination_nav(@pagination_data) do %>
    #     <% @objects.each do |object| %>
    #       <% object_link(object) %><br/>
    #     <% end %>
    #   <% end %>
    # should call content_for the page and letter nav so it can be put anywhere
    def paginated_results(args = {}, &block)
      html_id = args[:html_id] ||= "results"
      results = capture(&block).to_s
      uri = URI.parse(observations_path(q: q_param))
      encoded_q = uri.query

      tag.div(id: html_id, data: { q: encoded_q }) do
        concat(content_for(:index_pagination_top))
        concat(results)
        concat(content_for(:index_pagination_bottom))
      end
    end

    def index_pagination(pagination_data, args = {}, position: :top)
      tag.div(class: "pagination-#{position} navbar-flex mb-2") do
        concat(tag.div(class: "d-flex") do
          concat(content_for(:sorter)) if content_for?(:sorter)
        end)
        concat(tag.div(class: "d-flex") do
          concat(letter_pagination_nav(pagination_data, args))
          concat(number_pagination_nav(pagination_data, args))
        end)
      end
    end

    # Insert letter pagination links.
    #
    #   # In controller:
    #   def action
    #     query = create_query(:Name)
    #     @pagination_data = letter_pagination_data(:letter, :page, 50)
    #     @names = query.paginate(@pagination_data)
    #   end
    #
    #   # In view:
    #   <%= letter_pagination_nav(@pagination_data) %>
    #   <%= number_pagination_nav(@pagination_data) %>
    #
    def letter_pagination_nav(pagination_data, args = {})
      return "" unless need_letter_pagination_links?(pagination_data)

      args = args.dup
      args[:params] = (args[:params] || {}).dup
      args[:params][pagination_data.number_arg] = nil

      this_letter, letters = letter_pagination_pages(pagination_data)

      tag.nav(class: "paginate pagination_letters navbar-flex pl-4") do
        [
          tag.div(:by_letter.l, class: "navbar-text mx-0"),
          letter_input(this_letter, letters)
        ].safe_join
      end
    end

    # pages is a pagination_data object
    def need_letter_pagination_links?(pages)
      return false unless pages

      pages.letter_arg &&
        (pages.letter || pages.num_total > pages.num_per_page) &&
        pages.used_letters && pages.used_letters.length > 1
    end

    # Insert numbered pagination links.
    # (See also letter_pagination_nav above.)
    #
    #   # In controller:
    #   def action
    #     query = create_query(:Name)
    #     @pagination_data = number_pagination_data(:page, 50)
    #     @names = query.paginate(@pagination_data)
    #   end
    #
    #   # In view: (it is wrapped in 'pagination' div already)
    #   <%= number_pagination_nav(@pagination_data) %>
    #
    # rubocop:disable Metrics/AbcSize
    def number_pagination_nav(pages, args = {})
      return "" unless pages && pages.num_pages > 1

      params = args[:params] ||= {}
      if pages.letter_arg && pages.letter
        params[pages.letter_arg] = pages.letter
      end
      arg = pages.number_arg

      this_page, prev_page, next_page, max_page = number_pagination_pages(pages)
      max_url = pagination_link_url(max_page, arg, args)

      tag.nav(class: "paginate pagination_numbers navbar-flex pl-4") do
        [
          prev_page_link(prev_page, arg, args),
          tag.div(:PAGE.l, class: "navbar-text mx-0 hidden-xs"),
          goto_page_input(this_page, max_page),
          tag.div(:of.l, class: "navbar-text ml-0 mr-2 hidden-xs"),
          tag.div(link_to(max_page, max_url), class: "navbar-text mx-0"),
          next_page_link(next_page, max_page, arg, args)
        ].safe_join
      end
    end
    # rubocop:enable Metrics/AbcSize

    def letter_pagination_pages(pagination_data)
      letters = pagination_data.used_letters
      this_letter = pagination_data.letter || ""
      # this_letter_idx = letters.index(this_letter) || 0
      # prev_letter = letters[this_letter_idx - 1]
      # next_letter = letters[this_letter_idx + 1]
      [this_letter, letters]
    end

    def number_pagination_pages(pagination_data)
      max_page = pagination_data.num_pages
      this_page = pagination_data.number
      this_page = 1 if this_page < 1
      this_page = max_page if this_page > max_page
      prev_page = this_page - 1
      next_page = this_page + 1
      [this_page, prev_page, next_page, max_page]
    end

    def prev_page_link(prev_page, arg, args)
      disabled = prev_page < 1 ? "disabled opacity-0" : ""
      # return "" if prev_page < 1

      classes = class_names(
        %w[navbar-link btn btn-lg px-0 previous_page_link], disabled
      )

      url = pagination_link_url(prev_page, arg, args)
      icon_link_to(
        :PREV.t, url,
        class: classes, icon: :prev, show_text: false, icon_class: ""
      )
    end

    def next_page_link(next_page, max, arg, args)
      disabled = next_page > max ? "disabled opacity-0" : ""
      # return "" if next_page > max

      classes = class_names(
        %w[navbar-link btn btn-lg px-0 next_page_link], disabled
      )

      url = pagination_link_url(next_page, arg, args)
      icon_link_to(
        :NEXT.t, url,
        class: classes, icon: :next, show_text: false, icon_class: ""
      )
    end

    def letter_input(this_letter, used_letters)
      form_with(
        url: pagination_current_url, method: :get, local: true,
        class: "navbar-form px-0 page_input",
        data: { controller: "page-input",
                page_input_letters_value: used_letters }
      ) do |f|
        [
          tag.div(class: "input-group page-input ml-2") do
            [
              f.text_field(
                :letter,
                type: :text, value: this_letter,
                class: "form-control text-right",
                size: 1, placeholder: "—",
                data: { page_input_target: "letterInput",
                        action: "page-input#sanitizeLetter" }
              ),
              tag.span(class: "input-group-btn") do
                tag.button(type: :submit,
                           class: "btn btn-outline-default px-2") do
                  link_icon(:goto, title: :GOTO.l)
                end
              end
            ].safe_join
          end,
          *pagination_hidden_param_fields(f, :letter)
        ].safe_join
      end
    end

    # NOTE: On input change, the form's page param is sanitized by Stimulus.
    #
    # NOTE: Because this is a `form_with(method: :get, url: index)` and submits
    # with its own form params, any params in the form's commit url are ignored!
    # In other words we can't submit to `add_q_param(pagination_current_url)`:
    # unless the form sends a value for :q it will not be in the resulting url.
    # That's why we are sending :q params through hidden fields. (It also
    # doesn't work to send the :q string as a single hidden field, the hidden
    # fields must be built iteratively like a fields_for(:q) block.)
    def goto_page_input(this_page, max_page)
      form_with(
        url: pagination_current_url,
        method: :get, local: true,
        class: "navbar-form px-0 page_input",
        data: { controller: "page-input", page_input_max_value: max_page }
      ) do |f|
        [
          page_input_group_with_button(f, this_page, max_page),
          q_param_to_hidden_fields(f) # (Just :q. :id not relevant on next page)
        ].safe_join
      end
    end

    def page_input_group_with_button(frm, this_page, max_page)
      tag.div(class: "input-group page-input mx-2") do
        [
          frm.text_field(
            :page,
            type: :text, value: this_page, class: "form-control text-right",
            size: max_page.digits.count,
            data: { page_input_target: "numberInput",
                    action: "page-input#sanitizeNumber" }
          ),
          tag.span(class: "input-group-btn") do
            tag.button(type: :submit,
                       class: "btn btn-outline-default px-2") do
              link_icon(:goto, title: :GOTO.l)
            end
          end
        ].safe_join
      end
    end

    # We need to re-send the incoming :q param hash as part of the form,
    # so the index the form submits to will have a valid permalink with :q.
    # https://stackoverflow.com/questions/2505902/
    # passing-hash-as-values-in-hidden-field-tag/9488247
    def q_param_to_hidden_fields(form)
      # This flattens the hash as it is in the permalink.
      # Seems safer than trying to parse the incoming URI's query_string.
      query_string = Rack::Utils.build_nested_query(
        { q: q_param(query_from_session) }
      )
      # Sets them up them the way a form would, i.e. fields_for(:q)
      pairs = query_string.split(Rack::Utils::DEFAULT_SEP)
      tags = pairs.map do |pair|
        key, value = pair.split("=", 2).map { |str| Rack::Utils.unescape(str) }
        form.hidden_field(key, value: value)
      end
      tags.safe_join("\n")
    end

    # For the page input form, give form the current url without query string
    def pagination_current_url
      parsed_url = URI.parse(request.url)
      parsed_url.fragment = parsed_url.query = nil
      parsed_url.to_s
    end

    # Render a single pagination link for number_pagination_data above.
    def pagination_link(label, page, arg, args)
      url = pagination_link_url(page, arg, args)
      tag.li(link_to(label, url))
    end

    def pagination_link_url(page, arg, args)
      # Do not pass the :id through to next/prev page.
      params = args[:params].except(:id) || {}
      params[arg] = page
      url = reload_with_args(params)
      if args[:anchor]
        url.sub!(/#.*/, "")
        url += "##{args[:anchor]}"
      end
      url
    end
  end
end
