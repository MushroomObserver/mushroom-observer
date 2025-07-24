# frozen_string_literal: true

module PaginationNavHelper
  # Letters used as text in pagination links
  LETTERS = ("A".."Z")

  def add_pagination(pagination_data, args = {})
    content_for(:letters) do
      letter_pagination_nav(pagination_data, args)
    end
    content_for(:numbers) do
      number_pagination_nav(pagination_data, args)
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
    body = capture(&block).to_s

    tag.div(id: html_id, data: { q: get_query_param }) do
      [
        body,
        content_for(:numbers),
        content_for(:letters)
      ].safe_join
    end
  end

  # rubocop:disable Metrics/AbcSize
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
    return safe_empty unless need_letter_pagination_links?(pagination_data)

    args = args.dup
    args[:params] = (args[:params] || {}).dup
    args[:params][pagination_data.number_arg] = nil
    str = LETTERS.map do |letter|
      if pagination_data.used_letters.include?(letter)
        pagination_link(letter, letter, pagination_data.letter_arg, args)
      else
        tag.li(tag.span(letter), class: "disabled")
      end
    end.safe_join(" ")
    tag.ul(str, class: "pagination pagination-sm")
  end
  # rubocop:enable Metrics/AbcSize

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
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def number_pagination_nav_old(pages, args = {})
    return "" unless pages && pages.num_pages > 1

    params = args[:params] ||= {}
    params[pages.letter_arg] = pages.letter if pages.letter_arg && pages.letter

    num = pages.num_pages
    arg = pages.number_arg
    this = pages.number
    this = 1 if this < 1
    this = num if this > num
    size = args[:window_size] || 5
    from = this - size
    to = this + size

    list_args = { num:, arg:, args:, this:, size:, from:, to: }
    number_pagination_nav_list(list_args)
  end

  def number_pagination_nav_list(list_args)
    list_args => { num:, arg:, args:, this:, size:, from:, to: }
    result = []
    pstr = "« #{:PREV.t}"
    nstr = "#{:NEXT.t} »"
    result << pagination_link(pstr, this - 1, arg, args) if this > 1
    result << pagination_link(1, 1, arg, args) if from > 1
    result << tag.li(tag.span("..."), class: "disabled") if from > 2
    (from..to).each do |n|
      if n == this
        result << tag.li(tag.span(n), class: "active")
      elsif n.positive? && n <= num
        result << pagination_link(n, n, arg, args)
      end
    end
    result << tag.li(tag.span("..."), class: "disabled") if to < num - 1
    result << pagination_link(num, num, arg, args) if to < num
    result << pagination_link(nstr, this + 1, arg, args) if this < num

    result = tag.ul(
      result.safe_join(" "), class: "pagination pagination-sm"
    )
  end

  def number_pagination_nav(pages, args = {})
    return "" unless pages && pages.num_pages > 1

    params = args[:params] ||= {}
    params[pages.letter_arg] = pages.letter if pages.letter_arg && pages.letter
    arg = pages.number_arg

    this_page, prev_page, next_page, max_page = number_pagination_pages(pages)
    max_url = pagination_link_url(max_page, arg, args)

    tag.nav(class: "pagination_numbers navbar") do
      tag.div(class: "container-fluid") do
        [
          tag.ul(class: "nav navbar-nav") do
            [
              tag.li { prev_page_link(prev_page, arg, args) },
              tag.li { tag.p(:PAGE.l, class: "navbar-text mx-0") }
            ].safe_join
          end,
          page_input(this_page, max_page),
          tag.ul(class: "nav navbar-nav navbar-left") do
            [
              tag.li { tag.p(:of.l, class: "navbar-text ml-0 mr-2") },
              tag.li do
                tag.p(link_to(max_page, max_url), class: "navbar-text mx-0")
              end,
              tag.li { next_page_link(next_page, max_page, arg, args) }
            ].safe_join
          end
        ].safe_join
      end
      # end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def number_pagination_pages(pages)
    max_page = pages.num_pages
    this_page = pages.number
    this_page = 1 if this_page < 1
    this_page = max_page if this_page > max_page
    prev_page = this_page - 1
    next_page = this_page + 1
    [this_page, prev_page, next_page, max_page]
  end

  def prev_page_link(prev_page, arg, args)
    disabled = (prev_page < 1)

    url = pagination_link_url(prev_page, arg, args)
    icon_link_to(
      :PREV.t, url,
      id: "previous_page_link",
      class: "navbar-link navbar-left px-0 mr-2",
      disabled:, icon: :previous, show_text: false, icon_class: ""
    )
  end

  def prev_page_link_disabled
    link_icon(:previous, title: :PREV.t)
  end

  def next_page_link(next_page, max, arg, args)
    disabled = (next_page > max)

    url = pagination_link_url(next_page, arg, args)
    icon_link_to(
      :NEXT.t, url,
      id: "next_page_link",
      class: "navbar-link navbar-left px-0 ml-2",
      disabled:, icon: :next, show_text: false, icon_class: ""
    )
  end

  # On input change, the form's page param is sanitized by Stimulus.
  def page_input(this_page, max_page)
    form_with(
      url: pagination_current_url, method: :get, local: true,
      class: "navbar-form navbar-left px-0 page_input",
      data: { controller: "page-input", page_input_max_value: max_page }
    ) do |f|
      [
        tag.div(class: "input-group page-input mx-2") do
          [
            f.text_field(
              :page,
              type: :text, value: this_page, class: "form-control text-right",
              size: max_page.digits.count,
              data: { page_input_target: "input",
                      action: "page-input#updateForm" }
            ),
            tag.span(class: "input-group-btn") do
              tag.button(type: :submit,
                         class: "btn btn-outline-default px-2") do
                "•"
              end
            end
          ].safe_join
        end,
        *pagination_hidden_param_fields(f)
      ].safe_join
    end
  end

  # The form won't commit to the form url with the params even if included.
  # We need to re-send the incoming params as part of the form
  # Can't convert to_h without knowing what to permit
  def pagination_hidden_param_fields(form)
    params.except(:controller, :action, :page).keys.map do |key|
      form.hidden_field(key.to_sym, value: params[key])
    end
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
    params = args[:params] || {}
    params[arg] = page
    url = reload_with_args(params)
    if args[:anchor]
      url.sub!(/#.*/, "")
      url += "##{args[:anchor]}"
    end
    url
  end
end
