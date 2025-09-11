# frozen_string_literal: true

# Controller for handling the naming of observations

module Observations
  class BulkRenameController < ApplicationController
    def new
      return unless admin_check
    end

    def create
      return unless admin_check
    end

    private

    def admin_check
      return true if in_admin_mode?

      flash_error(:bulk_rename_admin_required.t)
      redirect_to(observations_path)
    end
  end
end
