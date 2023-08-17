# frozen_string_literal: true

module SpeciesLists
  class NameListsController < ApplicationController
    before_action :login_required
    before_action :require_successful_user

    # Specialized javascripty form for creating a list of names, at Darvin's
    # request. Links into create_species_list.
    # Uses same private methods as create/edit
    def new
      # Names are passed in as string, one name per line.
      results = params[:results] || ""
      @name_strings = results.chomp.split("\n").map { |n| n.to_s.chomp }
    end

    def create
      # Names are passed in as string, one name per line.
      results = params[:results] || ""
      @name_strings = results.chomp.split("\n").map { |n| n.to_s.chomp }

      # (make this an instance var to give unit test access)
      @names = parse_names
      @names.compact!
      case params[:commit]
      when :name_lister_submit_spl.l
        create_list
      when :name_lister_submit_txt.l
        render_name_list_as_txt(@names)
      when :name_lister_submit_rtf.l
        render_name_list_as_rtf(@names)
      when :name_lister_submit_csv.l
        render_name_list_as_csv(@names)
      else
        flash_error(:name_lister_bad_submit.t(button: params[:commit]))
        render("new")
      end
    end

    private

    def parse_names
      @name_strings.map do |str|
        str.sub!(/\*$/, "")
        name, author = str.split("|")
        name.tr!("ë", "e")
        if author
          Name.find_by(text_name: name, author: author)
        else
          Name.find_by(text_name: name)
        end
      end
    end

    def create_list
      return unless @user

      @species_list = SpeciesList.new
      clear_query_in_session
      init_name_vars_for_create
      init_member_vars_for_create
      init_project_vars_for_create
      @checklist ||= []
      @list_members = params[:results].tr("|", " ").delete("*")
      render("species_lists/new")
    end

    ############################################################################

    include SpeciesLists::SharedPrivateMethods # shared private methods
    include SpeciesLists::SharedRenderMethods # shared private methods
  end
end
