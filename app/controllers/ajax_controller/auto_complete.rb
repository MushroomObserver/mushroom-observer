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
      render(plain: helpers.auto_complete_results(string))
    end
  end

  private

end
