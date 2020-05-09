module PaginationHelper
  # Letters used as text in pagination links
  LETTERS = ("A".."Z").freeze

  # Wrap a block in pagination links.  Includes letters if appropriate.
  #
  #   <%= paginate_block(@pages) do %>
  #     <% for object in @objects %>
  #       <% object_link(object) %><br/>
  #     <% end %>
  #   <% end %>
  #
  def paginate_block(pages, args = {}, &block) #

    if !pages
      puts "Nothing to paginate"
      return
    end
    
    letters = pagination_letters(pages, args)
    numbers = pagination_numbers(pages, args)
    body = capture(&block).to_s
    letters + safe_br + numbers + body + numbers + safe_br + letters

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
    return safe_empty unless need_letter_pagination_links?(pages)

    args = args.dup
    args[:params] = (args[:params] || {}).dup
    args[:params][pages.number_arg] = nil
    array = LETTERS.map do |letter|
      if !pages.used_letters || pages.used_letters.include?(letter)
        pagination_link(letter, letter, pages.letter_arg, args)
      else
        content_tag(:li, content_tag(:span, letter), class: "disabled")
      end
    end
    str = safe_join(array, " ")
    content_tag(:ul,
                str,
                class: "pagination")
  end

  def need_letter_pagination_links?(pages)
    return unless pages

    pages.letter_arg &&
      (pages.letter || pages.num_total > pages.num_per_page) &&
      (!pages.used_letters || pages.used_letters.length > 1)
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
      prev_str = "« #{:PREV.t}"
      next_str = "#{:NEXT.t} »"
      if this > 1
        args[:style] = "page-item flex-fill"
        result << pagination_link(prev_str, this - 1, arg, args)
      end
      if from > 1
        args[:style] = "page-item"
        result << pagination_link(1, 1, arg, args)
      end
      if from > 2
        result << pagination_link_disabled()
      end
      for n in from..to
        if n == this
          result << pagination_link_active(n)
        elsif n.positive? && n <= num
          args[:style] = "page-item"
          result << pagination_link(n, n, arg, args)
        end
      end
      if to < num - 1
        result << pagination_link_disabled()
      end
      if to < num
        args[:style] = "page-item"
        result << pagination_link(num, num, arg, args)
      end
      if this < num
        args[:style] = "page-item flex-fill text-right"
        result << pagination_link(next_str, this + 1, arg, args)
      end
    end

    tag.nav aria: { label: "Page navigation".t } do
      tag.ul class: "pagination" do
        safe_join(result, " ")
      end
    end

  end

  # Render a single pagination link for paginate_numbers above.
  def pagination_link(label, page, arg, args)
    params = args[:params] || {}
    params[arg] = page
    url = reload_with_args(params)
    if args[:anchor]
      url.sub!(/#.*/, "")
      url += "#" + args[:anchor]
    end
    tag.li class: args[:style] do
      link_to(label, url, class: 'page-link')
    end
  end

  # Render an active-item pagination link.
  def pagination_link_active(label)
    # content_tag(:li, content_tag(:span, label), class: "active")
    tag.li class: "page-item active" do
      tag.span class: "page-link" do
        "#{label}"
      end
    end
  end

  # Render a blank (...) pagination link disabled.
  def pagination_link_disabled()
    tag.li class: "page-item disabled" do
      tag.span class: 'page-link' do
        "..."
      end
    end
  end

end
