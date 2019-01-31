module PaginationHelper
  # Wrap a block in pagination links.  Includes letters if appropriate.
  #
  #   <%= paginate_block(@pages) do %>
  #     <% for object in @objects %>
  #       <% object_link(object) %><br/>
  #     <% end %>
  #   <% end %>
  #
  def paginate_block(pages, args = {}, &block) # #TODO: Depreciate / REMOVE
    letters = pagination_letters(pages, args)
    numbers = pagination_numbers(pages, args)
    body = capture(&block).to_s
    content_tag(:div, class: "results") do
      letters + safe_br + numbers + body + numbers + safe_br + letters
    end
  end

  # Insert letter pagination links.
  #
  #   # In controller:
  #   def action
  #     query = create_query(:Name)
  #     @pages = paginate_letters(:letter, :page, 50)
  #     @names = query.paginate(@pages, letter_field: 'names.sort_name')
  #   end
  #
  #   # In view:
  #   <%= pagination_letters(@pages) %>
  #   <%= pagination_numbers(@pages) %>
  #
  def pagination_letters(pages, args = {})
    if pages &&
       pages.letter_arg &&
       (pages.letter || pages.num_total > pages.num_per_page) &&
       (!pages.used_letters || pages.used_letters.length > 1)
      args = args.dup
      args[:params] = (args[:params] || {}).dup
      args[:params][pages.number_arg] = nil
      str = %w[A B C D E F G H I J K L M N O P Q R S T U V W X Y Z].map do |letter|
        if !pages.used_letters || pages.used_letters.include?(letter)
          pagination_link(letter, letter, pages.letter_arg, args)
        else
          content_tag(:li, content_tag(:span, letter), class: "disabled")
        end
      end.safe_join(" ")
      content_tag(:div, str, class: "pagination pagination-sm")
    else
      safe_empty
    end
  end

  # Insert numbered pagination links.  I've thrown out the Rails plugin
  # pagination_letters because it is no longer giving us enough to be worth it.
  # (See also pagination_letters above.)
  #
  #   # In controller:
  #   def action
  #     query = create_query(:Name)
  #     @pages = paginate_numbers(:page, 50)
  #     @names = query.paginate(@pages)
  #   end
  #
  #   # In view: (it is wrapped in 'pagination' div already)
  #   <%= pagination_numbers(@pages) %>
  #
  def pagination_numbers(pages, args = {})
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

      result = []
      pstr = "« #{:PREV.t}"
      nstr = "#{:NEXT.t} »"
      result << pagination_link(pstr, this - 1, arg, args) if this > 1
      result << pagination_link(1, 1, arg, args) if from > 1
      result << content_tag(:li, content_tag(:span, "..."), class: "disabled") if from > 2
      for n in from..to
        if n == this
          result << content_tag(:li, content_tag(:span, n), class: "active")
        elsif n.positive? && n <= num
          result << pagination_link(n, n, arg, args)
        end
      end
      result << content_tag(:li, content_tag(:span, "..."), class: "disabled") if to < num - 1
      result << pagination_link(num, num, arg, args) if to < num
      result << pagination_link(nstr, this + 1, arg, args) if this < num

      result = content_tag(:ul, result.safe_join(" "), class: "pagination pagination-sm")
    end
    result
  end

  # Render a single pagination link for paginate_numbers above.
  def pagination_link(label, page, arg, args)
    params = args[:params] || {}
    params[arg] = page
    url = reload_with_args(params)
    if args[:anchor]
      url.sub!(/#.*/, "")
      url += '#' + args[:anchor]
    end
    "<li>#{link_to(label, url)}</li>".html_safe
  end
end
