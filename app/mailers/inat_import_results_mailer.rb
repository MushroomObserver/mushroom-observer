# frozen_string_literal: true

# Email import results to user after batch import completes
class InatImportResultsMailer < ApplicationMailer
  after_action :noreply_delivery, only: [:build]

  def build(user:, inat_import:, batch_info:)
    setup_user(user)
    @user = user
    @inat_import = inat_import
    @batch_info = batch_info
    @title = "iNaturalist Import Complete - Batch #{batch_info[:batch_number]}"

    debug_log(
      :inat_import_results,
      nil,
      user,
      inat_import: inat_import.id
    )

    mo_mail(
      @title,
      to: user,
      content_style: "plain"
    )
  end
end
