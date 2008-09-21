# 
# == Auto-completion helpers.
# 
# These are similar to the ones provided by Rails.  Problem is Rails doesn't
# give us the ability to customize properly, and they don't write valid XHTML
# in some cases.  Instead of providing an alternative +text_field+ method
# called +text_field_with_auto_complete+, we let you create any old field you
# want with the standard non-autocomplete-enabled helpers, then add
# auto-complete functionality using +turn_into_auto_completer+ or variations. 
#
# == Usage
#
# app/view/some/action.rhtml:
#   <% javascript_include_auto_complete %>
#   <% form = form_for(:thingy) do %>
#     Location: <%= form.text_field(:place) %>
#     <%= turn_into_location_auto_completer('thingy_place') %>
#   <% end %>
#
################################################################################

module ApplicationHelper

  # Turn a text_field into an auto-completer.
  # id:: id of text_field
  # opts:: any of these: (see prototype and cached_auto_complete.js for more)
  #   :url              URL of AJAX callback (required)
  #   :div_id           DOM ID of div ("<id>_auto_complete")
  #   :div_class        CSS class of div ("auto_complete")
  #   :js_class         JS autocompleter class ("CachedAutocompleter")
  #   :inherit_width    Inherit width of pulldown from text field?
  #
  def turn_into_auto_completer(id, opts={})
    if can_do_ajax?
      url       = nil
      div_id    = "#{id}_auto_complete"
      div_class = "auto_complete"
      js_class  = "CachedAutocompleter"
      js_args   = ""
      opts.each_pair do |key, val|
        case key
        when :div_id:    div_id    = val
        when :div_class: div_class = val
        when :url:       url       = val
        when :js_class:  js_class  = val
        else
          if !key.to_s.match(/^on/) && 
             !val.to_s.match(/^(\d+(\.\d+)?|true|false|null)$/)
            val = "'" + escape_javascript(val) + "'"
          end
          js_args += ", #{key}: #{val}"
        end
      end
      js_args.sub!(/^, /, '')
      raise ArgumentError, "Must specify url." if !url
      div = %(<div class="#{div_class}" id="#{div_id}"></div>)
      script = javascript_tag \
        %(new #{js_class}('#{id}', '#{div_id}', '#{url}', { #{js_args} }))
      return div + script
    end
  end

  # Make text_field auto-complete for location name.
  def turn_into_location_auto_completer(id, opts={})
    opts = {
      :url           => '/location/auto_complete_location',
      :indicator     => 'indicator',
      :frequency     => 0.1,
      :wordMatch     => true,
      :js_class      => 'CachedAutocompleter',
    }.clone.merge(opts)
    turn_into_auto_completer(id, opts)
  end

  # Make text_field auto-complete for mushroom name.
  def turn_into_name_auto_completer(id, opts={})
    turn_into_auto_completer(id, {
      :url           => '/name/auto_complete_name',
      :indicator     => 'indicator',
      :frequency     => 0.1,
      :collapse      => true,
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
