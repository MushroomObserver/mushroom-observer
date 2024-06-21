# frozen_string_literal: true

class AutocompletersController < ApplicationController
  require "cgi"

  # Requiring login here would mean "advanced search" must also require login.
  around_action :catch_ajax_errors

  layout false

  # The AutoComplete class returns "primers": 1000 records starting with the
  # first letter the user types. The Stimulus controller refines the results as
  # the user types, to minimize server requests. The eventual result is, we
  # auto-complete a string corresponding to the name of a record, e.g. Name.
  # AutoComplete currently renders a list of strings in plain text, but
  # could add record ids. The first line of the returned results is the actual
  # (minimal) string used to match the records. If it had to truncate the list
  # of results, the last string is "...".
  # type::              Type of string.
  # params[:string]::   String user has entered.
  def new
    @user = User.current = session_user

    if params[:string].blank? && params[:all].blank?
      render(json: ActiveSupport::JSON.encode([]))
    else
      render(json: ActiveSupport::JSON.encode(auto_complete_results))
    end
  end

  private

  def auto_complete_results
    # add useful params that the controller knows about
    params[:format] = @user&.location_format
    params[:user_id] = @user&.id

    ::AutoComplete.subclass(@type).new(params).matching_records
  end

  # callback on `around_action`
  def catch_ajax_errors
    prepare_parameters
    yield
  rescue StandardError => e
    msg = "#{e}\n"
    msg += backtrace(e) unless Rails.env.production?
    render(plain: msg, status: :internal_server_error)
  end

  def prepare_parameters
    @type  = params[:type].to_s
  end

  def backtrace(exception)
    result = ""
    exception.backtrace.each do |line|
      break if /action_controller.*perform_action/.match?(line)

      result += "#{line}\n"
    end
    result
  end
end
