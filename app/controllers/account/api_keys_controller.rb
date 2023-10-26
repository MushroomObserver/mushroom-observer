# frozen_string_literal: true

module Account
  class APIKeysController < ApplicationController
    before_action :login_required

    # NOTE: The index has two forms: a form to edit/remove existing_keys and
    # a form to create a new_key. The existing_keys form commits to the :destroy
    # action, but it has links for edits to existing_keys that are handled by
    # account_api_keys.js. They are updated via the api and AJAX, not :update.
    def index
      # @key = APIKey.new
    end

    # this form is on the index
    # def new
    # end

    def create
      @key = APIKey.new

      create_api_key

      respond_to do |format|
        format.html { redirect_to(account_api_keys_path) }
        format.js { render(partial: "account/api_keys/update_table_and_flash") }
      end
    end

    # This form is in the index
    # The edit view seems to be only for no-js users.
    # def edit
      # respond_to do |format|
      #   format.html do
      #     unless (@key = find_or_goto_index(APIKey, params[:id].to_s)) &&
      #            check_permission!(@key)
      #       redirect_to(account_api_keys_path)
      #     end
      #   end
      #   format.js do
      #     verify_user_owns_key
      #   end
      # end
    # end

    def update
      return unless verify_user_owns_key

      update_api_key
      respond_to do |format|
        format.html { redirect_to(account_api_keys_path) }
        format.js { render(partial: "account/api_keys/update_table_and_flash") }
      end
    end

    # remove this method
    # def remove
    #   remove_api_keys
    #   redirect_to(account_api_keys_path)
    # end

    def destroy
      return unless verify_user_owns_key

      @user.api_keys.delete(@key)
      flash_notice(:account_api_keys_removed_some.t(num: 1))
      # binding.break

      respond_to do |format|
        format.html { redirect_to(account_api_keys_path) }
        format.js { render(partial: "account/api_keys/update_table_and_flash") }
      end
    end

    # no `find_or_goto_index` cause it's a js request
    def activate
      return unless verify_user_owns_key

      @key.verify!
      flash_notice(:account_api_keys_activated.t(notes: @key.notes))

      respond_to do |format|
        format.html { redirect_to(account_api_keys_path) }
        format.js { render(partial: "account/api_keys/update_table_and_flash") }
      end
    end

    private

    def create_api_key
      @key = APIKey.new(params.require(:api_key).permit(:user_id, :notes))
      @key.verified = Time.zone.now
      @key.save!
      # @key = APIKey.new
      # render update blanks out form for if they want to create another key
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

    # remove this method
    # def remove_api_keys
    #   num_destroyed = 0
    #   @user.api_keys.each do |key|
    #     next unless params["key_#{key.id}"] == "1"

    #     @user.api_keys.delete(key)
    #     num_destroyed += 1
    #   end
    #   if num_destroyed.positive?
    #     flash_notice(:account_api_keys_removed_some.t(num: num_destroyed))
    #   else
    #     flash_warning(:account_api_keys_removed_none.t)
    #   end
    # end

    # def activate_api_key
    #   @key.verify!
    # end

    # what js was doing. but we should be just hitting update with the @key
    # def update_api_key(key, value)
    #   raise(:runtime_api_key_notes_cannot_be_blank.l) if value.blank?

    #   key.update_attribute(:notes, value.strip_squeeze)
    #   render(plain: key.notes)
    # end
  end
end
