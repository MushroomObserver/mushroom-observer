# frozen_string_literal: true

module Account
  class APIKeysController < ApplicationController
    before_action :login_required

    # NOTE: The index has several forms:
    # a form to edit existing_keys
    # a form to create a new_key
    # a destroy button for each key
    # an activate button if the key is not verified (created by another app)
    def index
      render(Views::Controllers::Account::APIKeys::Index.new(user: @user))
    end

    # No-JS fallback for users whose browsers can't run the
    # inline-collapse "+ Add Key" panel on the index page. Renders
    # the standalone create form; submit posts to `create` the same
    # way as the inline form.
    def new
      @key = APIKey.new
      render(Views::Controllers::Account::APIKeys::New.new(key: @key))
    end

    # No-JS fallback edit view. Loads the key for the standalone
    # edit page. The inline-on-index edit UI is JS-driven and
    # doesn't need this action.
    def edit
      return unless verify_user_owns_key

      render(Views::Controllers::Account::APIKeys::Edit.new(key: @key))
    end

    def create
      @key = APIKey.new

      create_api_key

      respond_to do |format|
        format.turbo_stream do
          render_update_table_and_flash
        end
        format.html { redirect_to(account_api_keys_path) }
      end
    end

    def update
      return unless verify_user_owns_key

      update_api_key
      respond_to do |format|
        format.turbo_stream do
          render_update_table_and_flash
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
          render_update_table_and_flash
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
          render_update_table_and_flash
        end
        format.html { redirect_to(account_api_keys_path) }
      end
    end

    private

    # Replaces the formerly-ERB `_update_table_and_flash.erb`
    # turbo_stream partial — emit two stream actions: refresh the
    # API-keys table with the Phlex view, and refresh the page-flash
    # zone with the current flash notices.
    def render_update_table_and_flash
      render(turbo_stream: [
               turbo_stream.replace(
                 "account_api_keys_table",
                 view_context.render(
                   Views::Controllers::Account::APIKeys::Table.new(user: @user)
                 )
               ),
               turbo_stream_flash_update
             ])
    end

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
      @key = APIKey.find(params[:id])
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
