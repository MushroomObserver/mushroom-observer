# frozen_string_literal: true

# see ajax_controller.rb
module AjaxController::AutoComplete
  require "cgi"

  # Auto-complete string as user types. Renders list of strings in plain text.
  # First line is the actual (minimal) string used to match results.  If it
  # had to truncate the list of results, the last string is "...".
  # type:: Type of string.
  # id::   String user has entered.
  def auto_complete
    string = CGI.unescape(@id).strip_squeeze
    if string.blank?
      render(plain: "\n\n")
      # render(plain: "")
    else
      render(plain: auto_complete_results(string))
    end
  end

  private

  # This should be a helper so it can be called in separate controllers
  # stimulus-autocomplete:
  # <li class="list-group-item" role="option"
  #     data-autocomplete-value="1">Blackbird</li>
  # <li class="list-group-item" role="option"
  #     data-autocomplete-value="2">Bluebird</li>
  # <li class="list-group-item" role="option"
  #     data-autocomplete-value="3">Mockingbird</li>
  # Note that we can return a value, i.e. record.id!
  # matches = [[string, id], [string, id]]
  def auto_complete_results(string)
    ::AutoComplete.subclass(@type).new(string, params).
      matching_strings.join("\n") + "\n"
      # matches.map do [string, id]
      #   tag.li(class: "list-group-item", role: "option",
      #          data: { autocomplete_value: id })
      # end.join("\n") + "\n"
  end
end
