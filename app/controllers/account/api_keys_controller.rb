# frozen_string_literal: true

module Account
  class APIKeysController < ApplicationController
    before_action :login_required

    # NOTE: The index has several forms:
    # a form to edit existing_keys
    # a form to create a new_key
    # a destroy button for each key
    # an activate button if the key is not verified (created by another app)
    def index; end

    def create
      @key = APIKey.new

      create_api_key

      respond_to do |format|
        format.turbo_stream do
          render(partial: "account/api_keys/update_table_and_flash")
        end
        format.html { redirect_to(account_api_keys_path) }
      end
    end

    def update
      return unless verify_user_owns_key

      update_api_key
      respond_to do |format|
        format.turbo_stream do
          render(partial: "account/api_keys/update_table_and_flash")
        end
        format.html { redirect_to(account_api_keys_path) }
      end
    end

    def destroy
      return unless verify_user_owns_key

      @user.api_keys.delete(@key)
      flash_notice(:account_api_keys_removed_some.t(num: 1))

      respond_to do |format|
        format.turbo_stream do
          render(partial: "account/api_keys/update_table_and_flash")
        end
        format.html { redirect_to(account_api_keys_path) }
      end
    end

    # no `find_or_goto_index` cause it's a js request
    def activate
      return unless verify_user_owns_key

      @key.verify!
      flash_notice(:account_api_keys_activated.t(notes: @key.notes))

      respond_to do |format|
        format.turbo_stream do
          render(partial: "account/api_keys/update_table_and_flash")
        end
        format.html { redirect_to(account_api_keys_path) }
      end
    end

    private

    def create_api_key
      @key = APIKey.new(params.require(:api_key).permit(:user_id, :notes))
      @key.verified = Time.zone.now
      @key.save!
      # render update blanks out form if they want to create another key
      flash_notice(:account_api_keys_create_success.t)
    rescue StandardError => e
      flash_error(:account_api_keys_create_failed.t + e.to_s)
    end

    def verify_user_owns_key
      @user = User.current = session_user || raise("Must be logged in.")
      @key  = APIKey.find(params[:id])
      raise("Permission denied") and return false if @key.user != @user

      true
    end

    def update_api_key
      @key.update!(params[:api_key].permit(:notes))
      flash_notice(:account_api_keys_updated.t)
    rescue StandardError => e
      flash_error(e.to_s)
    end
  end
end
