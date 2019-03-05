#
#  = Pagination
#
#  Simple class to hold the minimal info needed to paginate a set of objects by
#  page number and/or letter.  This class knows nothing about how to query the
#  results (see Query#paginate), nor does it know anything about how to render
#  the results or pagination controls (see ApplicationHelper::Paginator).
#
#  You give it a page number and number of results; it in return can tell you
#  which results you should display.
#
#  It also stores a few other parameters which though it never uses, the query
#  and/or render mechanisms need access to, such as the URL parameter used to
#  select page and letter, and the list of letters for which there are results.
#
#  == Query and ApplicationHelper::Paginator
#
#  Together these three classes and modules make it possible to gather a set of
#  results to an arbitrary query, and render them on an HTML view together with
#  all the necessary controls.  The basic usage is:
#
#    # In your Rails controller:
#    def index
#      @pages = MOPaginator.new(
#        :number_arg   => :page,
#        :number       => params[:page],
#        :num_per_page => 100,
#      )
#      query = Query.lookup(:Model, :flavor)
#      @results = query.paginate(@pages)
#    end
#
#    # This paginates by letter and number:
#    def index_by_letter
#      @pages = MOPaginator.new(
#        :letter_arg   => :letter,
#        :number_arg   => :page,
#        :letter       => params[:letter],
#        :number       => params[:page],
#        :num_per_page => 100,
#      )
#      query = Query.lookup(:Model, :flavor)
#      @results = query.paginate(@pages)
#    end
#
#    # This is how you might use it without Query:
#    def custom_index
#      @results = Model.find(...)
#      @pages.num_total = @results.length
#      @subset = @results[@pages.from..@pages.to]
#    end
#
#    # Use the same code in your view template for either case:
#    <%= paginate_block(@pages) do %>
#      <% for object in @results
#        <%= link_to(object.name, action: "show_object", id: object.id) %><br/>
#      <% end %>
#    <% end %>
#
#  == Attributes
#
#  letter_arg::     URL parameter used to select letter.
#  number_arg::     URL parameter used to select page number. (= +page_arg)
#  letter::         Letter selected (or +nil+ if none).
#  number::         Page number selected (or +nil+ if none). (= +page+)
#  num_per_page::   Number of results to show per page.
#  num_total::      Number of results available. (= +length)
#  used_letters::   Array of letters that have results.
#
#  == Class Methods
#
#  new::            Instantiate, setting one or more attributes at the same time
#
#  == Instance Methods
#
#  show_index::     Set page number so that it's showing the given result.
#  num_pages::      Calculate number of pages of results available.
#  from::           Index of the first result in selected page.
#  to::             Index of the last result in selected page.
#  from_to::        Same as <tt>pages.from..pages.to</tt>.
#
################################################################################

class MOPaginator
  attr_accessor :letter_arg    # Name of parameter to use for letter (if any).
  attr_accessor :number_arg    # Name of parameter to use for page number.
  attr_reader :letter        # Current letter (if any).
  attr_reader :number        # Current page number.
  attr_reader :num_per_page  # Number of results per page (default is 100).
  attr_reader :num_total     # Total number of results.
  attr_reader :used_letters  # List of letters that have results.

  alias_method :page_arg, :number_arg
  alias_method :page, :number
  alias_method :length, :num_total

  def blank?
    num_total.zero?
  end

  def empty?
    num_total.zero?
  end

  def any?
    num_total.positive?
  end

  # Create and initialize new instance.
  def initialize(args = {})
    args.each do |key, val|
      send("#{key}=", val)
    end
    @number ||= 1
    @num_per_page ||= 100
    @num_total ||= 0
  end

  # Validate the page number selection.
  def number=(num)
    if num
      @number = num.to_i
      @number = 1 if @number < 1
    else
      @number = 1
    end
    @number
  end
  alias_method :page=, :number=

  # Validate the letter selection.
  def letter=(char)
    if char
      @letter = char.to_s[0, 1].upcase
      @letter = nil unless /[A-Z]/.match?(@letter)
    else
      @letter = nil
    end
    @letter
  end

  # Validate the number of results.
  def num_total=(num)
    if num
      @num_total = num.to_i
      @num_total = 0 if @num_total < 1
    else
      @num_total = 0
    end
    @num_total
  end
  alias_method :length=, :num_total=

  # Validate the number per page.
  def num_per_page=(num)
    @num_per_page = num.to_i
    raise "Invalid num_per_page: #{num.inspect}" if @num_per_page < 1

    @num_per_page
  end

  # Validate +used_letters+ array.  Force them all to uppercase, and remove
  # duplicates and non-letters.  (Set to +nil+ to mean assume all letters have
  # results.)
  def used_letters=(list)
    if list
      @used_letters = list.map { |l| l.to_s[0, 1].upcase }.uniq.
                      select { |l| l.match(/[A-Z]/) }.sort
    else
      @used_letters = nil
    end
  end

  # Number of pages of results available.
  def num_pages
    (num_total.to_f / num_per_page).ceil
  end

  # First index on current page.
  def from
    n = ((number || 0) - 1) * num_per_page
    n = 0 if n.negative?
    n
  end

  # Last index on current page.
  def to
    n = from + num_per_page - 1
    n = num_total - 1 if n > num_total - 1
    n = 0 if n.negative?
    n
  end

  # Same as <tt>pages.from..pages.to</tt>.
  def from_to
    from..to
  end

  # Set page number so that it shows the given result (given by index, with
  # zero being the first result).
  def show_index(index)
    self.number = (index.to_f / num_per_page).floor + 1
  end
end
