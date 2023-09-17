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
    @user = User.current

    string = CGI.unescape(@id).strip_squeeze
    if string.blank?
      render(plain: "\n\n")
    else
      render(plain: auto_complete_results(string))
    end
  end

  private

  def auto_complete_results(string)
    case @type
    when "location"
      if @user&.location_format == "scientific"
        params[:format] = "scientific"
      end
    when "herbarium"
      params[:user_id] = @user&.id
    end

    ::AutoComplete.subclass(@type).new(string, params).
      matching_strings.join("\n") + "\n"
  end
end
