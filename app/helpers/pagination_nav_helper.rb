# frozen_string_literal: true

module PaginationNavHelper
  # Letters used as text in pagination links
  LETTERS = ("A".."Z")

  # Wrap a block in pagination links.  Includes letters if appropriate.
  #
  #   <%= pagination_nav(@pagination_data) do %>
  #     <% @objects.each do |object| %>
  #       <% object_link(object) %><br/>
  #     <% end %>
  #   <% end %>
  #
  def pagination_nav(pages, args = {}, &block)
    html_id = args[:html_id] ||= "results"
    letters = letter_pagination_nav(pages, args)
    numbers = number_pagination_nav(pages, args)
    body = capture(&block).to_s
    tag.div(id: html_id, data: { q: get_query_param }) do
      letters + safe_br + numbers + body + numbers + safe_br + letters
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
  def letter_pagination_nav(pages, args = {}) # rubocop:disable Metrics/AbcSize
    return safe_empty unless need_letter_pagination_links?(pages)

    args = args.dup
    args[:params] = (args[:params] || {}).dup
    args[:params][pages.number_arg] = nil
    str = LETTERS.map do |letter|
      if pages.used_letters.include?(letter)
        pagination_link(letter, letter, pages.letter_arg, args)
      else
        tag.li(tag.span(letter), class: "disabled")
      end
    end.safe_join(" ")
    tag.div(str, class: "pagination pagination-sm")
  end

  def need_letter_pagination_links?(pages)
    return false unless pages

    pages.letter_arg &&
      (pages.letter || pages.num_total > pages.num_per_page) &&
      (pages.used_letters && pages.used_letters.length > 1)
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
  def number_pagination_nav(pages, args = {})
    result = safe_empty
    if pages && pages.num_pages > 1
      params = args[:params] ||= {}
      if pages.letter_arg && pages.letter
        params[pages.letter_arg] = pages.letter
      end

      num = pages.num_pages
      arg = pages.number_arg
      this = pages.number
      this = 1 if this < 1
      this = num if this > num
      size = args[:window_size] || 5
      from = this - size
      to = this + size

      list_args = { num:, arg:, args:, this:, size:, from:, to: }
      result = number_pagination_nav_list(list_args)
    end
    result
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

    result = tag.ul(result.safe_join(" "), class: "pagination pagination-sm")
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  # Render a single pagination link for number_pagination_data above.
  def pagination_link(label, page, arg, args)
    params = args[:params] || {}
    params[arg] = page
    url = reload_with_args(params)
    if args[:anchor]
      url.sub!(/#.*/, "")
      url += "##{args[:anchor]}"
    end
    tag.li(link_to(label, url))
  end
end
