#
#  = Integration Test Helpers
#
#  TestCase to use with ActionController integration tests.
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

class IntegrationTestCase < ActionController::IntegrationTest
  include FlashAssertions

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
  # the whole thing in a Form instance.
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

  class Form
    attr_accessor :context
    attr_accessor :form
    attr_accessor :params
    attr_accessor :submits

    def initialize(context, form)
      @context = context
      @form    = form
      @url     = CGI.unescapeHTML(form.attributes['action'])
      @params  = []
      @submits = []
      get_initial_values
    end

    def get_initial_values
      @context.assert_select(@form, 'input') do |elems|
        for elem in elems
          id   = CGI.unescapeHTML(elem.attributes['id'] || '')
          name = CGI.unescapeHTML(elem.attributes['name'] || '')
          val  = CGI.unescapeHTML(elem.attributes['value'] || '')
          case elem.attributes['type']
          when 'submit'
            @submits << [ name, val ]
          else
            @params << [ name, val, id ]
          end
        end
      end
    end

    def edit_field(id, val)
      found = false
      for triple in @params
        id2 = triple[2]
        if id2.index(id) + id.length == id2.length
          triple[1] = val
          found = true
          break
        end
      end
      if !found
        @context.assert(nil, "Couldn't find input field with ID ending in #{id.inspect}.\n" +
                             "Have these: #{@params.keys.sort.inspect}")
      end
    end

    def submit(button)
      found = false
      hash = {}
      for name, val, id in @params
        hash[name] = val if val.to_s != ''
      end
      for name, val in @submits
        if val == button
          hash[name] = val
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
