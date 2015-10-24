# encoding: utf-8
module AutocompleteHelper
  # Add another input field onto an existing auto-completer.
  def reuse_auto_completer(first_id, new_id)
    inject_javascript_at_end("AUTOCOMPLETERS['#{first_id}'].reuse('#{new_id}')")
  end

  # Turn a text_field into an auto-completer.
  # id::   id of text_field
  # opts:: arguments (see autocomplete.js)
  def turn_into_auto_completer(id, opts = {})
    if can_do_ajax?
      js_args = []
      opts[:input_id]   = id
      opts[:row_height] = 22
      opts.each_pair do |key, val|
        if key.to_s == "primer"
          list = val ? val.reject(&:blank?).map(&:to_s).uniq.join("\n") : ""
          js_args << "primer: '" + escape_javascript(list) + "'"
        else
          if !key.to_s.match(/^on/) &&
             !val.to_s.match(/^(-?\d+(\.\d+)?|true|false|null)$/)
            val = "'" + escape_javascript(val.to_s) + "'"
          end
          js_args << "#{key}: #{val}"
        end
      end
      js_args = js_args.join(", ")
      inject_javascript_at_end("new MOAutocompleter({ #{js_args} })")
    end
  end

  # Make text_field auto-complete for fixed set of strings.
  def turn_into_menu_auto_completer(id, opts = {})
    fail "Missing primer for menu auto-completer!" unless opts[:primer]
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
    if @user && @user.location_format == :scientific
      format = "?format=scientific"
    else
      format = ""
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
    turn_into_auto_completer(id, {
      ajax_url: "/ajax/auto_complete/herbarium/@?user_id=" + @user.id.to_s,
      unordered: true
    }.merge(opts)) if @user
  end
end
