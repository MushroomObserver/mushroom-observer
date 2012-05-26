# encoding: utf-8

class API
  class_inheritable_accessor :model
  class_inheritable_accessor :table

  class_inheritable_accessor :high_detail_includes
  class_inheritable_accessor :low_detail_includes

  class_inheritable_accessor :high_detail_page_length
  class_inheritable_accessor :low_detail_page_length
  class_inheritable_accessor :put_page_length
  class_inheritable_accessor :delete_page_length

  self.high_detail_includes = []
  self.low_detail_includes  = []

  self.high_detail_page_length = 10
  self.low_detail_page_length  = 100
  self.put_page_length         = 1000
  self.delete_page_length      = 1000

  attr_accessor :query
  attr_accessor :detail
  attr_accessor :includes
  attr_accessor :page_length
  attr_accessor :page_number

  self.initializers << lambda do
    self.detail = parse_enum(:detail, :limit => [:none, :low, :high], :default => :none)
    self.page_number = parse_integer(:page, :default => 1)
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
    elsif method == :put
      put_page_length
    elsif method == :put
      delete_page_length
    elsif detail == :low
      low_detail_page_length
    else
      model.count
    end
  end

  def num_pages
    num = result_ids.length
    len = page_length
    ((num + len - 1) / len).truncate
  end

  def results
    @results ||= query.paginate(paginator, :include => includes)
  end

  def result_ids
    @result_ids ||= query.paginate_ids(paginator)
  end

  def num_results
    @num_results ||= query.num_results
  end

  def paginator
    @paginator ||= MOPaginator.new(
      :number => page_number,
      :num_per_page => page_length
    )
  end
end
