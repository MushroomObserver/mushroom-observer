# frozen_string_literal: true

module Account
  class APIKeysController < ApplicationController
    before_action :login_required
    before_action :disable_link_prefetching

    # NOTE: The index has two forms: a form to edit/remove existing_keys and
    # a form to create a new_key. The existing_keys form commits to the :destroy
    # action, but it has links for edits to existing_keys that are handled by
    # account_api_keys.js. They are updated via the api and AJAX, not :update.
    def index
      @key = APIKey.new
    end

    def create
      @key = APIKey.new

      create_api_key
      render(:index)
    end

    # The edit view seems to be only for no-js users.
    def edit
      unless (@key = find_or_goto_index(APIKey, params[:id].to_s)) &&
             check_permission!(@key)
        redirect_to(account_api_keys_path)
      end
    end

    def update
      return unless (@key = find_or_goto_index(APIKey, params[:id].to_s))
      return redirect_to(account_api_keys_path) unless check_permission!(@key)

      # could be that params[:commit] == :CANCEL.l -- don't update, do redirect.
      update_api_key if params[:commit] == :UPDATE.l
      redirect_to(account_api_keys_path)
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
end
