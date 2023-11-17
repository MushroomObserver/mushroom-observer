# frozen_string_literal: true

# This is a simple Turbo callback to toggle the export button on an image,
# but it appears to be currently unused.
# TODO: Harmonize this with the "ExportController", for exports and ml status.
# If that controller should update any page UIs without a reload, it should
# probably be broken up into separate controllers like this.
module Images
  class ExportsController < ApplicationController
    before_action :login_required
    # Mark an object for export. Renders updated export controls.
    # type::  Type of object.
    # id::    Object id.
    # value:: '0' or '1'
    def update
      @user  = User.current
      @image = Image.find(params[:id])
      raise("Permission denied.") unless @user.in_group?("reviewers")
      raise("Bad value.") if @value != "0" && @value != "1"

      mark_image_exportable(@image, @value)
      render(partial: "images/exports/update")
    end

    private

    def mark_image_exportable(image, value)
      @image = image
      @image.ok_for_export = (value == "1")
      @image.save_without_our_callbacks
    end
  end
end
