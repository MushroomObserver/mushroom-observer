# frozen_string_literal: true

# API
class API
  class_attribute :model
  class_attribute :table

  class_attribute :high_detail_includes
  class_attribute :low_detail_includes

  class_attribute :high_detail_page_length
  class_attribute :low_detail_page_length
  class_attribute :put_page_length
  class_attribute :delete_page_length

  self.high_detail_includes = []
  self.low_detail_includes  = []

  self.high_detail_page_length = 10
  self.low_detail_page_length  = 100
  self.put_page_length         = 1000
  self.delete_page_length      = 1000

  attr_accessor :query
  attr_accessor :detail
  attr_accessor :page_number

  initializers << lambda do
    self.detail = parse(:enum, :detail, limit: [:none, :low, :high]) || :none
    self.page_number = parse(:integer, :page, default: 1)
  end

  def includes
    if detail == :high
      high_detail_includes
    elsif detail == :low
      low_detail_includes
    else
      []
    end
  end

  def page_length
    if detail == :high
      high_detail_page_length
    elsif method == "PATCH"
      put_page_length
    elsif method == "DELETE"
      delete_page_length
    elsif detail == :low
      low_detail_page_length
    else
      1e6
    end
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
