#
#  = Integration Session Test Helpers
#
#  Methods in this class are available to all the integration tests.
#
#  ==== Debugging
#  dump_links::       Show list of all the links on the last page rendered.
#  save_page::        Save response from last request in a file.
#  get_with_error_checking::  Call get_via_redirect with extra error checking.
#  post_with_error_checking:: Call post_via_redirect with extra error checking.
#
#  ==== Helpers
#  parse_query_params:: Get (our) query params from the given URL.
#  get_links::        Get an Array of URLs for a set of links.
#
#  ==== Navigation
#  push_page::        Save response from last query so we can go back to it.
#  go_back::          Go back a number of times.
#  click_on::         Click on first link that matches the given args.
#
#  ==== Forms
#  do_form::          Encapsulate filling out and posting a given form.
#
################################################################################

module SessionExtensions

  ##############################################################################
  #
  #  :section: Debugging
  #
  ##############################################################################

  # Dump out a list of all the links on the last page rendered.
  def dump_links
    assert_select('a[href]') do |links|
      for link in links
        puts "link: #{link.attributes['href']}"
      end
    end
  end

  # Save response from last request so you can look at it in a browser.
  def save_page(file=nil)
    file ||= "#{RAILS_ROOT}/public/test.html"
    File.open(file, 'w') do |fh|
      fh.write(@response.body)
    end
  end

  # Call get/post_via_redirect, checking for 500 errors and missing language
  # tags.  Saves body of all successful responses for debugging, too.
  def process_with_error_checking(method, url, *args)
    Symbol.missing_tags = []
    send("#{method}_via_redirect", url, *args)
    if status == 500
      error = controller.instance_variable_get('@error')
      msg = "#{error}\n#{error.backtrace.join("\n")}"
      assert_equal(200, status, msg)
    end
    assert_equal([], Symbol.missing_tags, "Language tag(s) are missing.")
    save_page
  end

  # Wrapper on process_with_error_checking.
  def get_with_error_checking(*args)
    process_with_error_checking('get', *args)
  end

  # Wrapper on process_with_error_checking.
  def post_with_error_checking(*args)
    process_with_error_checking('post', *args)
  end

  ##############################################################################
  #
  #  :section: Random Helpers
  #
  ##############################################################################

  # Get string representing (our) query from the given URL.  Defaults to the
  # current page's URL.  (In practice, for now, this is just the Query id.)
  def parse_query_params(url=path)
    path, query = url.split('?')
    params = CGI.parse(query)
    params['q']
  end

  # Get an Array of URLs for the given links.
  #
  #   # This gets all the name links in the results of the last page.
  #   urls = get_links('div.results a[href^=/name/show_name]')
  #
  def get_links(*args)
    clean_our_backtrace do
      results = []
      assert_select(*args) do |links|
        results = links.map {|l| l.attributes['href']}
      end
      return results
    end
  end

  ##############################################################################
  #
  #  :section: Navigation
  #
  ##############################################################################

  # Save response from last query on the page stack.
  def push_page(name='')
    @page_stack ||= []
    @page_stack.push({
      :name => name,
      :body => @response.body,
    })
  end

  # Go back one or more times and restore a previous query result.  If called
  # with no argument, it just restores the previous page and doesn't affect the
  # stack.  If called with 2, it pops one page off the stack then restores the
  # page before that.  And so on.
  def go_back(arg=1)
    if arg.is_a?(Fixnum)
      while arg > 1
        @page_stack.pop
        arg -= 1
      end
    else
      while @page_stack.any? and (@page_stack.last[:name] != arg)
        @page_stack.pop
      end
      if @page_stack.empty?
        raise("Missing page called #{name.inspect}!")
      end
    end
    @response.body = @page_stack.last[:body]
    @html_document = HTML::Document.new(@response.body)
    save_page
  end

  # Click on the first link matching the given args.  Args can be:
  # label:: Label contains a String or matches a Regexp.
  # href::  URL starts with a String or matches a Regexp.
  # in::    Link contained in a given element type(s).
  def click_on(args={})
    clean_our_backtrace do
      select = 'a[href]'
      sargs  = []

      # Filter links based on URL.
      if arg = args[:href]
        if arg.is_a?(Regexp)
          select = "a[href^=?]"
          sargs << arg
        else
          select = "a[href^=#{arg}]"
        end
      end

      # Filter links by parent element types.
      if arg = args[:in]
        if arg == :tabs
          arg = 'div.tab_sets'
        elsif arg == :left_panel
          arg = 'table.LeftSide'
        elsif arg == :results
          arg = 'div.results'
        end
        select = "#{arg} #{select}"
      end

      done = false
      assert_select(select, *sargs) do |links|
        for link in links
          match = true

          # Filter based on link "label" (can be an image too, for example).
          if arg = args[:label]
            if arg == :image
              match = false if !link.to_s.match(/<img /)
            elsif arg.is_a?(Regexp)
              match = false if !link.to_s.match(arg)
            else
              match = false if !link.to_s.index(arg)
            end
          end

          # Click on first link that matches everything.
          if match
            url = CGI.unescapeHTML(link.attributes['href'])
# puts "CLICK ON: #{url}"
            get_with_error_checking(url)
            done = true
            break
          end
        end
      end

      assert(nil, "Expected a link matching: #{args.inspect}") if !done
    end
  end

  ##############################################################################
  #
  #  :section: Forms
  #
  #  Provides a handy encapsulation for filling out and submitting forms.
  #
  #    get(page)
  #    do_form('form[action=search]') do |form|
  #      form.edit_field(id1, val1)
  #      form.edit_field(id2, val2)
  #      form.submit(button)
  #    end
  #
  ##############################################################################

  # Look up a given form, initialize a Hash of parameters for it, and wrap up
  # the whole thing in a Form instance.  Returns (and yields) an instance of
  # IntegrationSession::Form.
  def do_form(*args)
    form = nil
    clean_our_backtrace do
      assert_select(*args) do |elems|
        assert_equal(1, elems.length,
                     "Found multiple forms matching #{args.inspect}.")
        elem = elems.first
        assert_equal('form', elem.name,
                     "Expected #{args.inspect} to find a form!")
        form = Form.new(self, elem)
        yield(form) if block_given?
      end
    end
    return form
  end

  # Class that represents a single HTML form.  Allow you to make assertions
  # about the kinds and values of input fields available, allows you to modify
  # them and then submit the result.
  class Form

    # Instance of the session that this form came from.
    attr_accessor :context

    # HTML element containing the form.
    attr_accessor :form

    # Array of input fields.
    attr_accessor :inputs

    # Array of submit buttons.
    attr_accessor :submits

    # Class used to encapsulates a single input field in a Form.
    class Field
      attr_accessor :type, :name, :id, :default, :value
      def initialize(args={})
        args.each {|k,v| send("#{k}=", v.to_s)}
      end
    end

    # Create and fill in the default values of a form.
    def initialize(context, form)
      @context = context
      @form    = form
      @url     = CGI.unescapeHTML(form.attributes['action'])
      @inputs  = []
      @submits = []
      fill_in_initial_values!
    end

    # Parse the default or initial values from the HTML and populate the
    # +inputs+ and +submits+ Arrays with the results.  Called automatically
    # by the constructor.
    def fill_in_initial_values!
      @context.assert_select(@form, 'input') do |elems|
        for elem in elems
          id   = CGI.unescapeHTML(elem.attributes['id'] || '')
          name = CGI.unescapeHTML(elem.attributes['name'] || '')
          val  = CGI.unescapeHTML(elem.attributes['value'] || '')
          type = elem.attributes['type']
          # Work-around for the check-box work-around: Rails adds an extra
          # hidden field imediately after every check-box for the benefit of
          # browsers that fail to post check-boxes whivh aren't checked.
          unless (id == '') and (type == 'hidden') and
                 @inputs.last and (@inputs.last.name == name)
            case type
            when 'submit'
              @submits << Field.new(
                :type  => :submit,
                :name  => name,
                :value => val
              )
            else
              @inputs << Field.new(
                :type    => type.to_sym,
                :name    => name,
                :id      => id,
                :default => val,
                :value   => val
              )
            end
          end
        end
      end
    end

    # Find the field whose ID ends in the given string.  Returns an instance
    # of IntegrationSession::Form::Field or +nil+.
    def get_field(id)
      result = nil
      for field in @inputs
        id2 = field.id
        if (i = id2.index(id)) and
           (i + id.length == id2.length)
          result = field
          break
        end
      end
      return result
    end

    # Assert the value of a given input field.  Change the value of the given
    # input field.  Matches field whose ID _ends_ in the given String.
    # Converts everything to String since +nil+ isn't distinguished from
    # <tt>""</tt> by HTML forms.  Pass in either a String or a Regexp for the
    # expected value.
    def assert_value(id, val, msg=nil)
      if field = get_field(id)
        val2 = field.value.to_s
      else
        val2 = ''
      end
      msg ||= "Expected value of form field #{id.inspect} to be #{val.inspect}."
      if val.is_a?(Regexp)
        @context.assert_match(val, val2.to_s, msg)
      else
        @context.assert_equal(val.to_s, val2.to_s, msg)
      end
    end

    # Change the value of the given input field.  Matches field whose ID _ends_
    # in the given String.
    def edit_field(id, val)
      @context.assert(field = get_field(id),
                      "Couldn't find input field with ID ending in #{id.inspect}.\n" +
                      "Have these: #{@inputs.map(&:id).sort.inspect}")
      field.value = val
    end

    # Submit the form using the given button.  (Button label must match String
    # exactly.)  Post is processed on the session that owns this form, using
    # +post_via_redirect+ (wrapped in +post_with_error_checking+).
    def submit(button)
      found = false
      hash = {}
      for field in @inputs
        hash[field.name] = field.value if field.value.to_s != ''
      end
      for field in @submits
        if field.value == button
          hash[field.name] = field.value
          found = true
          break
        end
      end
      if !found
        @context.assert(nil, "Couldn't find submit button labelled #{button.inspect}.")
      end
      @context.post_with_error_checking(@url, hash)
    end
  end
end
