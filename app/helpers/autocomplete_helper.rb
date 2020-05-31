# frozen_string_literal: true

module AutocompleteHelper
  # Add another input field onto an existing auto-completer.
  def reuse_auto_completer(first_id, new_id)
    inject_javascript_at_end %(
      AUTOCOMPLETERS[jQuery('##{first_id}').data('uuid')].reuse('#{new_id}')
    )
  end

  # Turn a text_field into an auto-completer.
  # id::   id of text_field
  # opts:: arguments (see autocomplete.js)
  def turn_into_auto_completer(id, opts = {})
    if can_do_ajax?
      opts[:input_id] = id
      js_args = escape_js_opts(opts)
      inject_javascript_at_end("new MOAutocompleter(#{js_args})")
    end
  end

  # Make text_field auto-complete for fixed set of strings.
  def turn_into_menu_auto_completer(id, opts = {})
    raise "Missing primer for menu auto-completer!" unless opts[:primer]

    turn_into_auto_completer(id, {
      unordered: false
    }.merge(opts))
  end

  # Make text_field auto-complete for Name text_name.
  def turn_into_name_auto_completer(id, opts = {})
    turn_into_auto_completer(id, {
      ajax_url: "/ajax/auto_complete/name/@",
      collapse: 1
    }.merge(opts))
  end

  # Make text_field auto-complete for Location display name.
  def turn_into_location_auto_completer(id, opts = {})
    format = if @user && @user.location_format == :scientific
               "?format=scientific"
             else
               ""
             end
    turn_into_auto_completer(id, {
      ajax_url: "/ajax/auto_complete/location/@" + format,
      unordered: true
    }.merge(opts))
  end

  # Make text_field auto-complete for Project title.
  def turn_into_project_auto_completer(id, opts = {})
    turn_into_auto_completer(id, {
      ajax_url: "/ajax/auto_complete/project/@",
      unordered: true
    }.merge(opts))
  end

  # Make text_field auto-complete for SpeciesList title.
  def turn_into_species_list_auto_completer(id, opts = {})
    turn_into_auto_completer(id, {
      ajax_url: "/ajax/auto_complete/species_list/@",
      unordered: true
    }.merge(opts))
  end

  # Make text_field auto-complete for User name/login.
  def turn_into_user_auto_completer(id, opts = {})
    turn_into_auto_completer(id, {
      ajax_url: "/ajax/auto_complete/user/@",
      unordered: true
    }.merge(opts))
  end

  # Make text_field auto-complete for Herbarium name.
  def turn_into_herbarium_auto_completer(id, opts = {})
    return unless @user

    turn_into_auto_completer(id, {
      ajax_url: "/ajax/auto_complete/herbarium/@?user_id=#{@user.id}",
      unordered: true
    }.merge(opts))
  end

  # Convert year field of date_select into an auto-completed text field.
  def turn_into_year_auto_completer(id, opts = {})
    js_args = escape_js_opts(opts)
    javascript_include("date_select.js")
    inject_javascript_at_end %(
      replace_date_select_with_text_field("#{id}", #{js_args})
    )
  end

  # Convert ruby Hash into Javascript string that evaluates to a hash.
  # escape_js_opts(:a => 1, :b => 'two') = "{ a: 1, b: 'two' }"
  def escape_js_opts(opts)
    js_args = []
    opts.each_pair do |key, val|
      if key.to_s == "primer"
        list = val ? val.reject(&:blank?).map(&:to_s).uniq.join("\n") : ""
        js_args << "primer: '" + escape_javascript(list) + "'"
      else
        if !key.to_s.start_with?("on") &&
           !val.to_s.match(/^(-?\d+(\.\d+)?|true|false|null)$/)
          val = "'" + escape_javascript(val.to_s) + "'"
        end
        js_args << "#{key}: #{val}"
      end
    end
    "{ " + js_args.join(", ") + " }"
  end
end
