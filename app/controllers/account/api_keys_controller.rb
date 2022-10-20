# frozen_string_literal: true

class Account::APIKeysController < ApplicationController
  before_action :login_required
  before_action :disable_link_prefetching

  # The index has two forms: for existing_keys and to create a new_key.
  # NOTE: The existing_keys form commits to the :destroy action!
  # But it has links for edits to existing_keys that are handled by
  # account_api_keys.js and updated via the api and AJAX.

  def index
    @key = APIKey.new
  end

  def create
    @key = APIKey.new

    create_api_key
    render(:index)
  end

  def edit
    unless (@key = find_or_goto_index(APIKey, params[:id].to_s)) &&
           check_permission!(@key)
      redirect_to(account_api_keys_path)
    end
  end

  def update
    return unless (@key = find_or_goto_index(APIKey, params[:id].to_s))
    return redirect_to(account_api_keys_path) unless check_permission!(@key)

    # return if request.method != "POST"
    case params[:commit]
    when :CANCEL.l
      render(:index) and return
    when :UPDATE.l
      update_api_key
    end
    render(:index) and return
  rescue StandardError => e
    flash_error(e.to_s)
  end

  def remove
    remove_api_keys
    render(:index)
  end

  def activate
    if (key = find_or_goto_index(APIKey, params[:id].to_s))
      if check_permission!(key)
        key.verify!
        flash_notice(:account_api_keys_activated.t(notes: key.notes))
      end
      redirect_to(account_api_keys_path)
    end
  rescue StandardError => e
    flash_error(e.to_s)
  end

  private

  def create_api_key
    @key = APIKey.new(params[:key].permit!)
    @key.verified = Time.zone.now
    @key.save!
    @key = APIKey.new # blank out form for if they want to create another key
    flash_notice(:account_api_keys_create_success.t)
  rescue StandardError => e
    flash_error(:account_api_keys_create_failed.t(msg: e.to_s))
  end

  def remove_api_keys
    num_destroyed = 0
    @user.api_keys.each do |key|
      if params["key_#{key.id}"] == "1"
        @user.api_keys.delete(key)
        num_destroyed += 1
      end
    end
    if num_destroyed.positive?
      flash_notice(:account_api_keys_removed_some.t(num: num_destroyed))
    else
      flash_warning(:account_api_keys_removed_none.t)
    end
  end

  def update_api_key
    @key.update!(params[:key].permit(:notes))
    flash_notice(:account_api_keys_updated.t)
  end
end
