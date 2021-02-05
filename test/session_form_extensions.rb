# frozen_string_literal: true

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
#  new::            Initialize form from HTML element returned by assert_select.
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
#  assert_checked::   Make sure a checkbox is checked
#  assert_unchecked:: Make sure a checkbox is unchecked
#
################################################################################

module SessionExtensions
  class Form
    require "session_upload"

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

      def initialize(args = {})
        args.each { |k, v| send("#{k}=", v) }
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
      self.url     = CGI.unescapeHTML(form["action"])
      self.inputs  = []
      self.submits = []
      fill_in_initial_values!
    end

    def find_value(elem, attr)
      result = CGI.unescapeHTML(elem[attr] || "")
      result.is_a?(Nokogiri::XML::Attr) ? result.value : result
    end

    # Parse the default or initial values from the HTML and populate the
    # +inputs+ and +submits+ Arrays with the results.  Called automatically
    # by the constructor.
    def fill_in_initial_values!
      context.assert_select(form, "input, textarea, select") do |elems|
        elems.each do |elem|
          id   = find_value(elem, "id")
          name = find_value(elem, "name")
          val  = find_value(elem, "value")
          type = elem.name == "input" ? find_value(elem, "type") : elem.name
          disabled = find_value(elem, "disabled") == "disabled"

          field = Field.new(
            node: elem,
            type: type.to_sym,
            name: name,
            id: id,
            default: val,
            value: val,
            disabled: disabled
          )

          case type
          when "submit"
            submits << field

          when "text", "password"
            inputs << field

          when "textarea"
            field.value = CGI.unescapeHTML(elem.children.map(&:to_s).join(""))
            inputs << field

          when "file"
            field.value = nil
            inputs << field

          when "checkbox", "radio"
            field.on_value = val
            field.value = (elem["checked"] == "checked")
            inputs << field

          when "select"
            val = nil
            field.options = opts = []
            context.assert_select(elem, "option") do |elems|
              for elem in elems
                opt = Field::Option.new
                opt.value = CGI.unescapeHTML(elem["value"])
                opt.label = CGI.unescapeHTML(elem.children.map(&:to_s).join(""))
                opts << opt
                val = opt.value \
                  if elem["selected"] == "selected"
              end
            end
            val ||= opts.first.value
            field.value = val
            inputs << field

          when "hidden"
            # Work-around for the check-box work-around: Rails adds an extra
            # hidden field imediately after every check-box for the benefit of
            # browsers that fail to post check-boxes which aren't checked.
            unless (id == "") && inputs.last && (inputs.last.name == name)
              inputs << field
            end
          end
        end
      end
    end

    # Find the field whose ID ends in the given String or matches the given
    # Regexp.  Returns an instance of IntegrationSession::Form::Field or +nil+.
    def get_field(id, strict = false)
      results = []
      inputs.each do |field|
        id2 = field.id
        if id.is_a?(Regexp) && id2.match(id)
          results << field
        elsif (i = id2.rindex(id)) && (i + id.length == id2.length)
          results << field
        end
      end

      if strict
        context.assert(results.any?,
                       "Couldn't find input field with ID ending in " \
                       "#{id.inspect}.\n" \
                       "Have these: #{inputs.map(&:id).inspect}")
        context.assert(results.length == 1,
                       "Multiple input fields field with ID ending in " \
                       "#{id.inspect}: #{results.map(&:id).inspect}")
      end

      results.first
    end

    # Call get_field and flunk an assertion if field not found.
    def get_field!(id)
      get_field(id, :strict)
    end

    # Find the field whose name ends in the given String or matches the given
    # Regexp.  Returns an instance of IntegrationSession::Form::Field or +nil+.
    def get_field_by_name(name, strict = false)
      results = []
      inputs.each do |field|
        nm2 = field.name
        if name.is_a?(Regexp) && nm2.match(name)
          results << field
        elsif (i = nm2.rindex(name)) && (i + name.length == nm2.length)
          results << field
        end
      end

      if strict
        context.assert(results.any?,
                       "Couldn't find input field with name ending in " \
                       "#{name.inspect}.\n" \
                       "Have these: #{inputs.map(&:name).inspect}")
        context.assert(results.length == 1,
                       "Multiple input fields field with name ending in " \
                       "#{name.inspect}: #{results.map(&:name).inspect}")
      end

      results.first
    end

    # Find the checkbox whose name ends in the given String or matches the given
    # Regexp. Returns an instance of IntegrationSession::Form::Field or +nil+.
    # Check boxes must be dealt with separately from other inputs because Rails
    # check_box(x) creates 2 inputs with name="x".
    # (The one of interest other has type="checkbox".)
    def get_checkbox_by_name!(name, strict = false)
      results = []
      inputs.each do |field|
        next unless field.type == :checkbox

        nm2 = field.name
        if name.is_a?(Regexp) && nm2.match(name)
          results << field
        elsif (i = nm2.rindex(name)) && (i + name.length == nm2.length)
          results << field
        end
      end

      if strict
        context.assert(results.any?,
                       "Couldn't find checkbox with name ending in " \
                       "#{name.inspect}.\n" \
                       "Have these: #{inputs.map(&:name).inspect}")
        context.assert(results.length == 1,
                       "Multiple checkboxes with name ending in " \
                       "#{name.inspect}: #{results.map(&:name).inspect}")
      end
      results.first
    end

    # Call get_field and flunk an assertion if field not found.
    def get_field_by_name!(name)
      get_field_by_name(name, :strict)
    end

    def string_value(field)
      return field unless field.respond_to?(:value)

      string_value(field.value)
    end

    # Find the field whose ID ends in the given String or matches the given
    # Regexp.  Returns its value as a String if found, else +nil+.
    def get_value(id)
      string_value(get_field(id)).strip
    end

    # Call get_value and flunk an assertion if field not found.
    def get_value!(id)
      string_value(get_field(id, :strict)).strip
    end

    # Make sure the form does _not_ have a given field.
    def assert_no_field(id, msg = nil)
      field = get_field(id)
      msg ||= "Expected form NOT to have field #{id.inspect}."
      context.assert(!field || (field.type == :hidden), msg)
    end

    def selected_value(field)
      selected = field.node.children.select { |x| x["selected"] }
      return "" if selected == []

      selected[0]["value"]
    end

    def field_value(field)
      if field.type == :select
        value = selected_value(field)
        return value if value != ""
      end
      field.value.to_s.strip
    end

    # Assert the value of a given input field.
    # If first argument is enclosed in brackets (e.g. "[code]"),
    #   matches the field whose _name_ _ends_ in the given String.
    #   else matches field whose _ID_ _ends_ in the given String.
    # Converts everything to String since +nil+ isn't distinguished from
    # <tt>""</tt> by HTML forms.  Pass in either a String or a Regexp for the
    # expected value.
    def assert_value(id, val, msg = nil)
      field = get_field_by_identifier(id)
      msg ||= "Expected value of form field #{id.inspect} to be #{val.inspect}."
      val2 = field_value(field)
      if val.is_a?(Regexp)
        context.assert_match(val, val2.to_s, msg)
      else
        context.assert_equal(val.to_s, val2.to_s, msg)
      end
    end

    def get_field_by_identifier(identifier)
      # Does it begin with "[" and end with "]"?
      if identifier.is_a?(String) && /^\[.*\]$/ =~ identifier
        get_field_by_name!(identifier)
      else
        get_field!(identifier)
      end
    end

    def assert_unchecked(id, msg = nil)
      assert_checked(id, false, msg)
    end

    # Assert that the identified check box is checked
    # identifier: bracketed string "[...]" to match check_box by its name
    #             another string or a regexp to match check_box by its id
    def assert_checked(identifier, checked = true, msg = nil)
      # Does it begin with "[" and end with "]"?
      field =  if identifier.is_a?(String) && /^\[.*\]$/ =~ identifier
                 get_checkbox_by_name!(identifier)
               else
                 get_field!(identifier)
               end
      val = field.node["checked"]
      if checked
        msg ||= "Expected checkbox #{identifier.inspect} to be checked."
        context.assert_equal("checked", val, msg)
      else
        msg ||= "Expected checkbox #{identifier.inspect} to be unchecked."
        context.assert_nil(val, msg)
      end
    end

    # Make sure a given field is enabled for editing.
    def assert_enabled(id, msg = nil)
      field = get_field_by_identifier(id)
      msg ||= "Expected field #{id.inspect} to be enabled."
      context.refute(field.disabled, msg)
      field
    end

    # Make sure a given field is disabled.
    def assert_disabled(id, msg = nil)
      field = get_field!(id)
      msg ||= "Expected field #{id.inspect} to be disabled."
      context.assert(field.disabled, msg)
      field
    end

    # Make sure a given field is there but hidden.
    def assert_hidden(id, msg = nil)
      field = get_field!(id)
      msg ||= "Expected field #{id.inspect} to be hidden."
      context.assert(field.type == :hidden, msg)
      field
    end

    # Allow user to make further HTML assertions on the form.
    def assert_select(*args, &block)
      context.assert_select(form, *args, &block)
    end

    # Change the value of the given input field.  Matches field whose ID _ends_
    # in the given String.
    def change(id, val)
      if val == true
        assert_enabled(id).node["checked"] = "checked"
      elsif val == false
        assert_enabled(id).node.remove_attribute("checked")
      else
        assert_enabled(id).value = val
      end
    end

    # Check the identified check box.
    # identifier: bracketed string "[...]" to match check_box by its name
    #             another string or a regexp to match check_box by its id
    def check(identifier)
      field =  if identifier.is_a?(String) && /^\[.*\]$/ =~ identifier
                 get_checkbox_by_name!(identifier)
               else
                 get_field!(identifier)
               end
      msg ||= "Expected field #{identifier.inspect} to be enabled."
      context.refute(field.disabled, msg)
      context.assert([:checkbox, :radio].include?(field.type),
                     "Must be a check-box or radio-box.")

      # Just change "checked" property for checkboxes.
      field.node["checked"] = "checked" if field.type == :checkbox

      # Uncheck all the other radio-boxes in this group.
      if field.type == :radio
        field.value = true
        inputs.each do |field2|
          if (field2 != field) && (field2.name == field.name)
            field2.value = false
          end
        end
      end
    end

    # Uncheck the identified check box.
    # identifier: bracketed string "[...]" to match check_box by its name
    #             another string or a regexp to match check_box by its id
    def uncheck(identifier)
      field =  if identifier.is_a?(String) && /^\[.*\]$/ =~ identifier
                 get_checkbox_by_name!(identifier)
               else
                 get_field!(identifier)
               end
      msg ||= "Expected field #{identifier.inspect} to be enabled."
      context.refute(field.disabled, msg)
      context.assert([:checkbox].include?(field.type), "Must be a check-box.")
      field.node.remove_attribute("checked")
    end

    # Upload a file in a file field.
    def upload(id, file, type)
      field = assert_enabled(id)
      context.assert_equal(:file, field.type)
      field.value = FileUpload.new(file, type)
    end

    # Change selection of pulldown menu.
    def select(id, label)
      field = assert_enabled(id)
      context.assert(field.type == :select,
                     "Expected field #{id.inspect} to be a select field!")
      matches = []
      field.options.each do |opt|
        if label.is_a?(Regexp)
          next unless opt.label.match?(label)
        else
          next unless opt.label == label.to_s
        end

        field.value = opt.value
        matches << opt.label
      end
      context.assert(!matches.empty?,
                     "Couldn't find any options in the pulldown " \
                     "#{field.id.inspect} that match #{label.inspect}.\n" \
                     "Have these: #{field.options.map(&:label).inspect}")
      context.assert(matches.length == 1,
                     "Multiple options in the pulldown #{field.id.inspect} " \
                     "match #{label.inspect}: #{matches.inspect}")
    end

    # Submit the form using the given button.  Button can be specified by a
    # String (full exact match), Regexp, or +nil+ (meaning use the first one).
    # Post is processed on the session that owns this form.
    def submit(button = nil)
      found = false
      hash = {}
      for field in inputs
        if field.type == :checkbox
          hash[field.name] =
            field.node["checked"] == "checked" ? field.on_value : "0"
        elsif field.type == :radio
          hash[field.name] = field.on_value if field.value
        elsif field.type == :file
          if field.value
            file = field.value.filename
            type = field.value.content_type
            hash[field.name] = Rack::Test::UploadedFile.new(file, type, :binary)
          else
            hash[field.name] = nil
          end
        else
          hash[field.name] = field.value
        end
      end
      submits.each do |field|
        next unless button.is_a?(Regexp) && field.value.match(button) ||
                    (button.is_a?(String) && (field.value == button) ||
                     button.nil?)

        context.refute(field.disabled,
                       "Tried to submit form with disabled button: " \
                       "#{button.inspect}")
        context.assert(!found || found == field.value,
                       "Found multiple non-identical submit buttons " \
                       "matching #{button.inspect}")
        hash[field.name] = field.value
        found = field.value
      end
      context.assert(found,
                     "Couldn't find submit button labeled #{button.inspect}.")
      puts("POST #{url}: #{hash.inspect}") if debug
      context.post(url, params: hash)
    end
  end
end
