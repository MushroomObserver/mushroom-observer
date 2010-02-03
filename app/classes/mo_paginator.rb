#
#  = Pagination
#
#  Simple class to hold the minimal info needed by Paginator and Query.
#
#  TODO: document
#
################################################################################

class MOPaginator
  attr_accessor :letter_arg    # Name of parameter to use for letter (if any).
  attr_accessor :number_arg    # Name of parameter to use for page number.
  attr_accessor :letter        # Current letter (if any).
  attr_accessor :number        # Current page number.
  attr_accessor :num_per_page  # Number of results per page.
  attr_accessor :num_total     # Total number of results.
  attr_accessor :used_letters  # List of letters that have results.

  alias page_arg number_arg
  alias page number
  alias length num_total
  alias length= num_total=

  # Set page number so that it shows the given result (given by index, with
  # zero being the first result).
  def show_index(index)
    self.number = (index.to_f / num_per_page).floor + 1
  end

  # Let user supply number of results, but validate it so we know where
  # errors came from that would inevitably otherwise occur later on.
  def num_total=(n)
    if n.is_a?(String)
      @num_total = n.to_i
    elsif n.is_a?(Fixnum)
      @num_total = n.to_i
    elsif n.nil?
      @num_total = 0
    else
      raise "Invalid number, expected Fixnum, String or nil, got '#{n.class}=#{n}'"
    end
  end

  # Number of pages of results available.
  def num_pages
    (num_total.to_f / num_per_page).ceil
  end

  # First index on current page.
  def from
    n = (number - 1) * num_per_page
    n = 0 if n < 0
    return n
  end

  # Last index on current page.
  def to
    n = from + num_per_page - 1
    n = num_total - 1 if n > num_total - 1
    n = 0 if n < 0
    return n
  end

  # Create and initialize new instance.
  def initialize(args={})
    args.each do |key, val|
      send("#{key}=", val)
    end
  end
end
