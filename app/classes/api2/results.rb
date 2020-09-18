# frozen_string_literal: true

# API2
class API2
  class_attribute :model, :table, :high_detail_includes, :low_detail_includes,
                  :high_detail_page_length, :low_detail_page_length,
                  :put_page_length, :delete_page_length

  self.high_detail_includes = []
  self.low_detail_includes  = []
  self.high_detail_page_length = 10
  self.low_detail_page_length  = 100
  self.put_page_length         = 1000
  self.delete_page_length      = 1000

  attr_accessor :query, :detail, :page_number

  initializers << lambda do
    self.detail = parse(:enum, :detail, limit: [:none, :low, :high]) || :none
    self.page_number = parse(:integer, :page, default: 1)
  end

  def includes
    return high_detail_includes if detail == :high
    return low_detail_includes if detail == :low

    []
  end

  def page_length
    return high_detail_page_length if detail == :high
    return put_page_length if method == "PATCH"
    return delete_page_length if method == "DELETE"
    return low_detail_page_length if detail == :low

    1e6
  end

  def num_pages
    num = num_results
    len = page_length
    ((num + len - 1) / len).truncate
  end

  def results
    @results ||= query.paginate(paginator, include: includes)
  end

  def result_ids
    @result_ids ||= query.paginate_ids(paginator)
  end

  def num_results
    @num_results ||= query.num_results
  end

  def paginator
    @paginator ||= MOPaginator.new(
      number: page_number,
      num_per_page: page_length
    )
  end
end
