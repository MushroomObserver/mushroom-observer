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
      # render(plain: "")
    else
      render(plain: helpers.auto_complete_results(string))
    end
  end

  private

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
    case @type
    when "location"
      params[:format] = "scientific" if @user&.location_format == "scientific"
    when "herbarium"
      params[:user_id] = @user&.id
    end

    ::AutoComplete.subclass(@type).new(string, params).
      matching_strings.join("\n") + "\n"
  end
end
