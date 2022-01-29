# frozen_string_literal: true

# Check https://joinhandshake.com/blog/our-team/implementing-custom-pagination-with-graphql-ruby/
# Documentation is inconsistent, not sure this can work as typed

class HandshakeConnection < GraphQL::Pagination::Connection
  def nodes
    results.slice(0, page_size) # Remove the extra result we fetched to check if there's another page
  end

  def cursor_for(item)
    Base64.encode64(item.id.to_s)
  end

  def direction
    if @before_value.present? || @last_value.present?
      :backward
    else
      # Fall back to forward by default
      :forward
    end
  end

  def has_next_page
    return false unless direction == :forward

    results.size > page_size
  end

  # Always return false because we're not implementing backwards pagination yet
  def has_previous_page
    return false unless direction == :backward

    results.size > page_size
  end

  def page_size
    case direction
    when :forward
      @first_value || max_page_size
    when :backward
      @last_value || max_page_size
    end
  end

  def results
    @_results ||= begin
      case direction
      when :forward
        # If there’s an after cursor, decode it and only query for records with an id that come after that cursor
        if @after_value.present?
          @items = @items.where("id > ?", Base64.decode64(@after_value))
          end
      when :backward
        # If there’s a before cursor, decode it and only query for records with an id that come before that cursor
        if @before_value.present?
          @items = @items.where("id < ?", Base64.decode64(@before_value))
          end
        @items = @items.reverse_order
      end

      @items.limit(page_size + 1) # Fetch one extra result to determine if there's another page
    end
  end
end
