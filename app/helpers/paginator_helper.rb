# encoding: utf-8
#
#  = Pagination Helpers
#
#  Two handy methods for rendering pagination links above and below a list of
#  results in a view.  See also ApplicationController and MOPaginator.
#
#  *NOTE*: These are all included in ApplicationHelper.
#
#  == Methods
#
#  paginate_block::       Wrap block in appropriate pagination links.
#  pagination_letters::   Render the set of letters for pagination.
#  pagination_numbers::   Render nearby page numbers for pagination.
#  pagination_link::      Render a single link in above methods.
#
################################################################################

module ApplicationHelper::Paginator

  # Wrap a block in pagination links.  Includes letters if appropriate.
  #
  #   <% paginate_block(@pages) do %>
  #     <% for object in @objects %>
  #       <% object_link(object) %><br/>
  #     <% end %>
  #   <% end %>
  #
  def paginate_block(pages, args={}, &block)
    letters = pagination_letters(pages, args).to_s
    numbers = pagination_numbers(pages, args).to_s
    body = capture(&block).to_s
    str = letters + numbers + body + numbers + letters
    str = '<div class="results">' + str + '</div>'
    concat(str, block.binding)
  end

  # Insert letter pagination links.
  #
  #   # In controller:
  #   def action
  #     query = create_query(:Name)
  #     @pages = paginate_letters(:letter, :page, 50)
  #     @names = query.paginate(@pages, :letter_field => 'names.sort_name')
  #   end
  #
  #   # In view:
  #   <%= pagination_letters(@pages) %>
  #   <%= pagination_numbers(@pages) %>
  #
  def pagination_letters(pages, args={})
    if pages and
       pages.letter_arg and
       (pages.letter || pages.num_total > pages.num_per_page) and
       (!pages.used_letters or pages.used_letters.length > 1)
      args = args.dup
      args[:params] = (args[:params] || {}).dup
      args[:params][pages.number_arg] = nil
      str = %w(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z).map do |letter|
        if !pages.used_letters || pages.used_letters.include?(letter)
          pagination_link(letter, letter, pages.letter_arg, args)
        else
          letter
        end
      end.join(' ')
      return %(<div class="pagination">#{str}</div>)
    else
      return ''
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
  def pagination_numbers(pages, args={})
    result = ''
    if pages && pages.num_pages > 1
      params = args[:params] ||= {}
      if pages.letter_arg && pages.letter
        params[pages.letter_arg] = pages.letter
      end
      
      num  = pages.num_pages
      arg  = pages.number_arg
      this = pages.number
      this = 1 if this < 1
      this = num if this > num
      size = args[:window_size] || 5
      from = this - size
      to   = this + size
      
      result = []
      pstr = "« #{:PREV.t}"
      nstr = "#{:NEXT.t} »"
      result << pagination_link(pstr, this-1, arg, args) if this > 1
      result << '|'                                      if this > 1
      result << pagination_link(1, 1, arg, args)         if from > 1
      result << '...'                                    if from > 2
      for n in from..to
        if n == this
          result << n
        elsif n > 0 && n <= num
          result << pagination_link(n, n, arg, args)
        end
      end
      result << '...'                                    if to < num - 1
      result << pagination_link(num, num, arg, args)     if to < num
      result << '|'                                      if this < num
      result << pagination_link(nstr, this+1, arg, args) if this < num
      
      result = %(<div class="pagination">#{result.join(' ')}</div>)
    end
  end

  # Render a single pagination link for paginate_numbers above.
  def pagination_link(label, page, arg, args)
    params = args[:params] || {}
    params[arg] = page
    url = h(reload_with_args(params))
    if args[:anchor]
      url.sub!(/#.*/, '')
      url += '#' + args[:anchor]
    end
    link_to(label, url)
  end
end
