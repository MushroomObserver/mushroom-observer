# encoding: utf-8
#
#  = Session Form Helpers
#
#  This class represents a single HTML form.  It allows you to make assertions
#  about the kinds and values of input fields available, allows you to modify
#  them and then submit the result.
#
#  == Attributes
#  context::          Instance of the session that this form came from.
#  form::             HTML element containing the form.
#  url::              URL of action form POSTs to.
#  inputs::           Array of input fields.
#  submits::          Array of submit buttons.
#  debug::            Set to true to have it display POST data on submit.
#
#  == Methods
#  new::              Initialize form from HTML element returned by assert_select.
#  get_field::        Return Form::Field matching the given DOM id.
#  get_field!::       Same as get_field, but flunks an assertion if not found.
#  get_value::        Return value (String) of field matching the given DOM id.
#  get_value!::       Same as get_value, but flunks an assertion if not found.
#
#  ==== Form actions
#  change::           Change the value of a given field.
#  check::            Change value of checkbox to 'checked'.
#  uncheck::          Change value of checkbox to 'unchecked'.
#  upload::           Select a file to upload.
#  select::           Change the selection of a pulldown menu.
#  submit::           Submit the form.
#
#  ==== Assertions
#  assert_no_field::  Make sure a given field is _not_ present.
#  assert_value::     Make sure a given field has a certain value.
#  assert_enabled::   Make sure a given field is enabled.
#  assert_disabled::  Make sure a given field is disabled.
#  assert_hidden::    Make sure a given field is there but hidden
#  assert_select::    Call assert_select on the form.
#
################################################################################

class SessionExtensions::Form

  # Instance of the session that this form came from.
  attr_accessor :context

  # HTML element containing the form.
  attr_accessor :form

  # Action the form posts to.
  attr_accessor :url

  # Array of input fields.
  attr_accessor :inputs

  # Array of submit buttons.
  attr_accessor :submits

  # When true: display list of parameters on POST.
  attr_accessor :debug

  # Class used to encapsulates a single input field in a Form.
  class Field
    # HTML::Tag instance representing field.
    attr_accessor :node

    # Type of field, e.g. :textarea, :select.
    attr_accessor :type

    # Name of field, e.g. 'user[login]'
    attr_accessor :name

    # DOM id of field, e.g. 'user_login'
    attr_accessor :id

    # Original value of field (as served).
    attr_accessor :default

    # Current value of field (e.g. after edits).
    attr_accessor :value

    # Value to POST if checkbox is checked.
    attr_accessor :on_value

    # List of options available to pulldown (select).
    attr_accessor :options

    # Is this field modifiable?
    attr_accessor :disabled

    def initialize(args={})
      args.each {|k,v| send("#{k}=", v)}
    end

    # Tiny class used to represent option in select field.
    class Option
      attr_accessor :value
      attr_accessor :label
    end
  end

  # Create and fill in the default values of a form.
  def initialize(context, form)
    self.context = context
    self.form    = form
    self.url     = CGI.unescapeHTML(form.attributes['action'])
    self.inputs  = []
    self.submits = []
    fill_in_initial_values!
  end

  # Parse the default or initial values from the HTML and populate the
  # +inputs+ and +submits+ Arrays with the results.  Called automatically
  # by the constructor.
  def fill_in_initial_values!
    context.assert_select(form, 'input, textarea, select') do |elems|
      for elem in elems
        id   = CGI.unescapeHTML(elem.attributes['id'] || '')
        name = CGI.unescapeHTML(elem.attributes['name'] || '')
        val  = CGI.unescapeHTML(elem.attributes['value'] || '')
        type = (elem.name == 'input') ? elem.attributes['type'] : elem.name
        disabled = elem.attributes['disabled'] == 'disabled'

        field = Field.new(
          :node     => elem,
          :type     => type.to_sym,
          :name     => name,
          :id       => id,
          :default  => val,
          :value    => val,
          :disabled => disabled
        )

        case type
        when 'submit'
          submits << field

        when 'text', 'password'
          inputs << field

        when 'textarea'
          field.value = CGI.unescapeHTML(elem.children.map(&:to_s).join(''))
          inputs << field

        when 'file'
          field.value = nil
          inputs << field

        when 'checkbox', 'radio'
          field.on_value = val
          field.value = (elem.attributes['checked'] == 'checked')
          inputs << field

        when 'select'
          val = nil
          field.options = opts = []
          context.assert_select(elem, 'option') do |elems|
            for elem in elems
              opt = Field::Option.new
              opt.value = CGI.unescapeHTML(elem.attributes['value'])
              opt.label = CGI.unescapeHTML(elem.children.map(&:to_s).join(''))
              opts << opt
              val = opt.value if elem.attributes['selected'] == 'selected'
            end
          end
          val = opts.first.value if !val
          field.value = val
          inputs << field

        when 'hidden'
          # Work-around for the check-box work-around: Rails adds an extra
          # hidden field imediately after every check-box for the benefit of
          # browsers that fail to post check-boxes whivh aren't checked.
          unless (id == '') and inputs.last and (inputs.last.name == name)
            inputs << field
          end
        end
      end
    end
  end

  # Find the field whose ID ends in the given String or matches the given
  # Regexp.  Returns an instance of IntegrationSession::Form::Field or +nil+.
  def get_field(id, strict=false)
    results = []
    for field in inputs
      id2 = field.id
      if id.is_a?(Regexp) ? id2.match(id) :
         ((i = id2.rindex(id)) and (i + id.length == id2.length))
        results << field
      end
    end

    if strict
      context.assert_block("Couldn't find input field with ID ending in " +
                            "#{id.inspect}.\nHave these: " +
                            "#{inputs.map(&:id).inspect}") { results.any? }
      context.assert_block("Multiple input fields field with ID ending in " +
                            "#{id.inspect}: #{results.map(&:id).inspect}") \
                            { results.length == 1 }
    end

    return results.first
  end

  # Call get_field and flunk an assertion if field not found.
  def get_field!(id)
    get_field(id, :strict)
  end

  # Find the field whose ID ends in the given String or matches the given
  # Regexp.  Returns its value as a String if found, else +nil+.
  def get_value(id)
    get_field(id).value
  end

  # Call get_value and flunk an assertion if field not found.
  def get_value!(id)
    get_field(id, :strict).value
  end

  # Make sure the form does _not_ have a given field.
  def assert_no_field(id, msg=nil)
    msg ||= "Expected form NOT to have field #{id.inspect}."
    context.assert_block(msg) {
      field = get_field(id)
      !field or (field.type == :hidden)
    }
  end

  # Assert the value of a given input field.  Change the value of the given
  # input field.  Matches field whose ID _ends_ in the given String.
  # Converts everything to String since +nil+ isn't distinguished from
  # <tt>""</tt> by HTML forms.  Pass in either a String or a Regexp for the
  # expected value.
  def assert_value(id, val, msg=nil)
    field = get_field!(id)
    val2 = field.value.to_s
    msg ||= "Expected value of form field #{id.inspect} to be #{val.inspect}."
    if val.is_a?(Regexp)
      context.assert_match(val, val2.to_s, msg)
    else
      context.assert_equal(val.to_s, val2.to_s, msg)
    end
  end

  # Make sure a given field is enabled for editing.
  def assert_enabled(id, msg=nil)
    field = get_field!(id)
    msg ||= "Expected field #{id.inspect} to be enabled."
    context.assert_block(msg) { !field.disabled }
    return field
  end

  # Make sure a given field is disabled.
  def assert_disabled(id, msg=nil)
    field = get_field!(id)
    msg ||= "Expected field #{id.inspect} to be disabled."
    context.assert_block(msg) { field.disabled }
    return field
  end

  # Make sure a given field is there but hidden.
  def assert_hidden(id, msg=nil)
    field = get_field!(id)
    msg ||= "Expected field #{id.inspect} to be hidden."
    context.assert_block(msg) { field.type == :hidden }
    return field
  end

  # Allow user to make further HTML assertions on the form.
  def assert_select(*args, &block)
    context.assert_select(form, *args, &block)
  end

  # Change the value of the given input field.  Matches field whose ID _ends_
  # in the given String.
  def change(id, val)
    assert_enabled(id).value = val
  end

  # Check a given check-box.
  def check(id)
    field = assert_enabled(id)
    context.assert_block("Must be a check-box or radio-box.") do
      [:checkbox, :radio].include?(field.type)
    end
    field.value = true

    # Uncheck all the other radio-boxes in this group.
    if field.type == :radio
      for field2 in inputs
        if (field2 != field) and (field2.name == field.name)
          field2.value = false
        end
      end
    end
  end

  # Uncheck a given check-box.
  def uncheck(id)
    field = assert_enabled(id)
    context.assert_block("Must be a check-box.") do
      [:checkbox].include?(field.type)
    end
    field.value = false
  end

  # Upload a file in a file field.
  def upload(id, file, type)
    field = assert_enabled(id)
    context.assert_equal(:file, field.type)
    field.value = ActionController::TestUploadedFile.new(file, type, :binary)
  end

  # Change selection of pulldown menu.
  def select(id, label)
    field = assert_enabled(id)
    context.assert_block("Expected field #{id.inspect} to be a select field!") \
      { field.type == :select }
    matches = []
    for opt in field.options
      if label.is_a?(Regexp) ? opt.label.match(label) :
                               (opt.label == label.to_s)
        field.value = opt.value
        matches << opt.label
      end
    end
    context.assert_block("Couldn't find any options in the pulldown " +
                          "#{field.id.inspect} that match #{label.inspect}.\n" +
                          "Have these: #{field.options.map(&:label).inspect}") \
                          { matches.length > 0 }
    context.assert_block("Multiple options in the pulldown " +
                          "#{field.id.inspect} match #{label.inspect}: " +
                          "#{matches.inspect}") { matches.length == 1 }
  end

  # Submit the form using the given button.  Button can be specified by a
  # String (full exact match), Regexp, or +nil+ (meaning use the first one).
  # Post is processed on the session that owns this form.
  def submit(button=nil)
    found = false
    hash = {}
    for field in inputs
      if field.type == :checkbox
        hash[field.name] = field.value ? field.on_value : '0'
      elsif field.type == :radio
        hash[field.name] = field.on_value if field.value
      elsif field.value.to_s != ''
        hash[field.name] = field.value
      end
    end
    for field in submits
      if button.is_a?(Regexp) and field.value.match(button) or
         button.is_a?(String) and (field.value == button) or
         button.nil?
        context.assert_block("Tried to submit form with disabled button: " +
                             button.inspect) { !field.disabled }
        context.assert_block("Found multiple non-identical submit " +
                             "buttons matching #{button.inspect}") \
                             { !found || found == field.value }
        hash[field.name] = field.value
        found = field.value
      end
    end
    context.assert_block("Couldn't find submit button labelled " +
                          "#{button.inspect}.") { found }
    puts "POST #{url}: #{hash.inspect}" if debug
    context.post(url, hash)
  end
end
