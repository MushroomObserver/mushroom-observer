# frozen_string_literal: true

class AutocompletersController < ApplicationController
  require("cgi")

  # Requiring login here would mean "advanced search" must also require login.
  around_action :catch_ajax_errors

  # Reduce overhead for these requests.
  disable_filters
  layout false

  # The Autocomplete class returns "primers": 1000 records starting with the
  # first letter the user types. The Stimulus controller refines the results as
  # the user types, to minimize server requests. The eventual result is, we
  # auto-complete a string corresponding to the name of a record, e.g. Name.
  # Autocomplete currently renders a list of strings in plain text, but
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
      add_context_params
      render(json: ActiveSupport::JSON.encode(autocomplete_results))
    end
  end

  private

  # add useful context params that the controller knows about, but not the class
  def add_context_params
    params[:format] = @user&.location_format
    params[:user_id] = @user&.id
  end

  def autocomplete_results
    # Don't pass region or clade as the @type with `exact` here.
    if params[:exact].present?
      return ::Autocomplete.subclass(@type).new(params).first_matching_record
    end

    ::Autocomplete.subclass(@type).new(params).matching_records
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
