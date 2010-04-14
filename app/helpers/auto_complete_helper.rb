#
#  = Auto-completion Helpers
#
#  These are similar to the ones provided by Rails.  Problem is Rails doesn't
#  give us the ability to customize properly, and they don't write valid
#  XHTML in some cases.  Instead of providing an alternative text_field
#  method called text_field_with_auto_complete, we let you create any old
#  field you want with the standard non-autocomplete-enabled helpers, then
#  add auto-complete functionality using turn_into_auto_completer or
#  variations. 
#
#  *NOTE*: These are all included in ApplicationHelper and thus available to
#  all views by default.
#
#  == Typical usage
#
#    # In your view:
#    <% javascript_include_auto_complete %>
#    <% form = form_for(:thingy) do %>
#      Location: <%= form.text_field(:place) %>
#      <%= turn_into_location_auto_completer('thingy_place') %>
#    <% end %>
#
#  == Methods
#
#  turn_into_auto_completer::          Turn text field into auto-completer.
#  turn_into_menu_auto_completer::     Turn into auto-completer for set menu.
#  turn_into_location_auto_completer:: Turn into Location name auto-completer.
#  turn_into_name_auto_completer::     Turn into Name auto-completer.
#  turn_into_project_auto_completer::  Turn into Project title auto-completer.
#  turn_into_species_list_auto_completer:: Turn into SpeciesList title auto-completer.
#  turn_into_user_auto_completer::     Turn into User name auto-completer.
#  javascript_include_auto_complete::  Include javascript libs for auto-completion.
#
################################################################################

module ApplicationHelper::AutoComplete

  # Turn a text_field into an auto-completer.
  # id::   id of text_field
  # opts:: arguments
  #
  # Valid arguments: (see prototype and cached_auto_complete.js for more)
  # url::           URL of AJAX callback (required)
  # div_id::        DOM ID of div (default = "<id>_auto_complete")
  # div_class::     CSS class of div (default = "auto_complete")
  # js_class::      JS autocompleter class (default = "CachedAutocompleter")
  # inherit_width:: Inherit width of pulldown from text field?
  #
  def turn_into_auto_completer(id, opts={})
    if can_do_ajax?
      url       = nil
      div_id    = "#{id}_auto_complete"
      div_class = "auto_complete"
      js_class  = "CachedAutocompleter"
      js_args   = ""
      primer    = nil
      opts.each_pair do |key, val|
        case key
        when :div_id:    div_id    = val
        when :div_class: div_class = val
        when :url:       url       = val
        when :js_class:  js_class  = val
        when :primer:    primer    = val
        else
          if !key.to_s.match(/^on/) &&
             !val.to_s.match(/^(\d+(\.\d+)?|true|false|null)$/)
            val = "'" + escape_javascript(val) + "'"
          end
          js_args += ", #{key}: #{val}"
        end
      end
      if primer && !primer.empty?
        js_args += ', primer: [' + primer.map do |val|
          "'" + escape_javascript(val) + "'"
        end.join(',') + ']'
      end
      js_args.sub!(/^, /, '')
      raise(ArgumentError, "Must specify url.") if !url
      div = %(<div class="#{div_class}" id="#{div_id}"></div>)
      script = javascript_tag \
        %(new #{js_class}('#{id}', '#{div_id}', '#{url}', { #{js_args} }))
      return div + script
    end
  end

  # Make text_field auto-complete for fixed set of strings.
  def turn_into_menu_auto_completer(id, opts={})
    raise "Missing primer for menu auto-completer!" if !opts[:primer]
    turn_into_auto_completer(id, {
      :url           => '/ajax/auto_complete/name',
      :frequency     => 0.1,
      :js_class      => 'CachedAutocompleter',
      :noAjax        => true,
    }.merge(opts))
  end

  # Make text_field auto-complete for Location display name.
  def turn_into_location_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :url           => '/ajax/auto_complete/location',
      :indicator     => 'indicator',
      :frequency     => 0.1,
      :wordMatch     => true,
      :js_class      => 'CachedAutocompleter',
    }.merge(opts))
  end

  # Make text_field auto-complete for Name text_name.
  def turn_into_name_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :url           => '/ajax/auto_complete/name',
      :indicator     => 'indicator',
      :frequency     => 0.1,
      :collapse      => true,
      :js_class      => 'CachedAutocompleter',
      :inherit_width => (@ua == :ie ? 1 : 0),
    }.merge(opts))
  end

  # Make text_field auto-complete for Project title.
  def turn_into_project_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :url           => '/ajax/auto_complete/project',
      :indicator     => 'indicator',
      :frequency     => 0.1,
      :wordMatch     => true,
      :js_class      => 'CachedAutocompleter',
    }.merge(opts))
  end

  # Make text_field auto-complete for SpeciesList title.
  def turn_into_species_list_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :url           => '/ajax/auto_complete/species_list',
      :indicator     => 'indicator',
      :frequency     => 0.1,
      :wordMatch     => true,
      :js_class      => 'CachedAutocompleter',
    }.merge(opts))
  end

  # Make text_field auto-complete for User name/login.
  def turn_into_user_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :url           => '/ajax/auto_complete/user',
      :indicator     => 'indicator',
      :frequency     => 0.1,
      :wordMatch     => true,
      :js_class      => 'CachedAutocompleter',
      :inherit_width => (@ua == :ie ? 1 : 0),
    }.merge(opts))
  end

  # Include everything needed for auto-completion.
  def javascript_include_auto_complete
    if can_do_ajax?
      javascript_include 'prototype'
      javascript_include 'effects'
      javascript_include 'controls'
      javascript_include 'cached_auto_complete'
    end
  end
end
