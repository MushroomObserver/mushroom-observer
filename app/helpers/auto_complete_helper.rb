# encoding: utf-8
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
#  reuse_auto_completer::              Share an auto-completer with a new field.
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

  # Add another input field onto an existing auto-completer.
  def reuse_auto_completer(first_id, new_id)
    javascript_tag("AUTOCOMPLETERS['#{first_id}'].reuse('#{new_id}')")
  end

  # Turn a text_field into an auto-completer.
  # id::   id of text_field
  # opts:: arguments (see autocompleter.js)
  def turn_into_auto_completer(id, opts={})
    if can_do_ajax?
      javascript_include_auto_complete

      js_args = []
      opts[:input_id]   = id
      opts[:row_height] = 22
      opts.each_pair do |key, val|
        if key.to_s == 'primer'
          list = val ? val.reject(&:blank?).map(&:to_s).uniq.join("\n") : ''
          js_args << "primer: '" + escape_javascript(list) + "'"
        else
          if !key.to_s.match(/^on/) &&
             !val.to_s.match(/^(-?\d+(\.\d+)?|true|false|null)$/)
            val = "'" + escape_javascript(val) + "'"
          end
          js_args << "#{key}: #{val}"
        end
      end
      js_args = js_args.join(', ')

      script = javascript_tag("new MOAutocompleter({ #{js_args} })")
      return script
    end
  end

  # Make text_field auto-complete for fixed set of strings.
  def turn_into_menu_auto_completer(id, opts={})
    raise "Missing primer for menu auto-completer!" if !opts[:primer]
    turn_into_auto_completer(id, {
      :unordered => false
    }.merge(opts))
  end

  # Make text_field auto-complete for Name text_name.
  def turn_into_name_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :ajax_url => '/ajax/auto_complete/name/@',
      :collapse => 1
    }.merge(opts))
  end

  # Make text_field auto-complete for Location display name.
  def turn_into_location_auto_completer(id, opts={})
    if @user and @user.location_format == :scientific
      format = '?format=scientific'
    else
      format = ''
    end
    turn_into_auto_completer(id, {
      :ajax_url => '/ajax/auto_complete/location/@' + format,
      :unordered => true
    }.merge(opts))
  end

  # Make text_field auto-complete for Project title.
  def turn_into_project_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :ajax_url => '/ajax/auto_complete/project/@',
      :unordered => true
    }.merge(opts))
  end

  # Make text_field auto-complete for SpeciesList title.
  def turn_into_species_list_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :ajax_url => '/ajax/auto_complete/species_list/@',
      :unordered => true
    }.merge(opts))
  end

  # Make text_field auto-complete for User name/login.
  def turn_into_user_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :ajax_url => '/ajax/auto_complete/user/@',
      :unordered => true
    }.merge(opts))
  end

  # Make text_field auto-complete for Herbarium name.
  def turn_into_herbarium_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :ajax_url => '/ajax/auto_complete/herbarium/@',
      :unordered => true
    }.merge(opts))
  end

  # Include everything needed for auto-completion.
  def javascript_include_auto_complete
    if can_do_ajax?
      javascript_include 'prototype'
      javascript_include 'effects'
      javascript_include 'controls'
      javascript_include 'autocomplete'
      javascript_include 'element_extensions'
    end
  end
end
