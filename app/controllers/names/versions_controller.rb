# frozen_string_literal: true

# show_past_name
module Names
  class VersionsController < ApplicationController
    before_action :login_required
    before_action :store_location

    # Show past version of Name.  Accessible only from show_name page.
    def show
      return unless find_name!

      @name.revert_to(params[:version].to_i)
      @versions = @name.versions.to_a

      render(Views::Controllers::Names::Versions::Show.new(
               name: @name, user: @user, versions: @versions,
               version: params[:version].to_i,
               inherited_classification_user: inherited_classification_user
             ))
    end

    # Looks up the user the version's classification was inherited
    # from, if any — keeps the look-up out of
    # `Views::Controllers::Names::Versions::Show`. Re-queries the AR
    # association so `find_by(version:)` hits the `(name_id, version)`
    # index instead of scanning the in-memory `@versions` Array.
    def inherited_classification_user
      row = @name.versions.find_by(version: params[:version].to_i)
      data = row && @name.classification_at_version(row)
      return unless data && data[:source] == :inherited

      user_id = data.dig(:inherited_from, :user_id)
      user_id && User.find_by(id: user_id)
    end

    private

    # A past-version display page never reads
    # `@name.namings`/`@name.observations` directly —
    # `show_page_includes` skips those eager-loads (see
    # `Name::Scopes` for why it matters for high-observation-count
    # names).
    def find_name!
      @name = Name.show_page_includes.safe_find(params[:id]) ||
              flash_error_and_goto_index(Name, params[:id])
    end
  end
end
