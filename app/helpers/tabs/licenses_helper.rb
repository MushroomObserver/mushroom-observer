# frozen_string_literal: true

# Title and Tab Helpers for License views
#   xx_tabs::      List of links to display in xx tabset
#   xx_title::     Title of x page; includes any markup
#
module Tabs
  module LicensesHelper
    def license_index_tabs
      [new_license_tab]
    end

    def license_show_title(license)
      [
        license.display_name,
        license_title_id(license)
      ].safe_join(" ")
    end

    def license_show_tabs(license)
      links = [licenses_index_tab, new_license_tab, edit_license_tab(license)]
      links.push(destroy_license_tab(license)) unless license.in_use?
      links
    end

    def license_form_new_tabs
      [licenses_index_tab]
    end

    def license_form_edit_tabs(license:)
      [
        object_return_tab(license),
        licenses_index_tab
      ]
    end

    def edit_license_tab(license)
      InternalLink::Model.new(
        :EDIT.t, license, edit_license_path(license.id)
      ).tab
    end

    def destroy_license_tab(license)
      InternalLink::Model.new(
        :DESTROY.t, license, license,
        html_options: { button: :destroy }
      ).tab
    end

    # "Editing: Creative Commons Non-commercial v3.0 (#nnn)"  textilized
    def license_edit_title(license)
      capture do
        concat("#{:EDITING.l}: ")
        concat(license_show_title(license))
      end
    end

    def license_title_id(license)
      tag.span(class: "smaller") do
        tag.span("#(#{license.id || "?"}):")
      end
    end

    ##########

    private

    def new_license_tab
      InternalLink::Model.new(
        :create_license_title.t, License, new_license_path
      ).tab
    end

    def licenses_index_tab
      InternalLink::Model.new(
        :index_license.t, License, licenses_path
      ).tab
    end
  end
end
