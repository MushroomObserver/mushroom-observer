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
      @name_strings = name_lister_strings
      render_new_page
    end

    def create
      # Names are passed in as string, one name per line.
      @name_strings = name_lister_strings

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
        render_new_page
      end
    end

    private

    def render_new_page
      render(
        Views::Controllers::SpeciesLists::NameLists::New.new(
          name_strings: @name_strings,
          user: @user
        ),
        layout: true
      )
    end

    # Read the newline-separated name string posted by
    # `Views::Controllers::SpeciesLists::NameLists::Form` under the
    # `name_lister[results]` namespace.
    def name_lister_results
      params.dig(:name_lister, :results).to_s
    end

    def name_lister_strings
      name_lister_results.chomp.split("\n").map { |n| n.to_s.chomp }
    end

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
      init_project_vars_for_create
      @list_members = name_lister_results.tr("|", " ").delete("*")
      # `species_lists/new.html.erb` is now Phlex (see #4389) — render
      # the class directly with the form props the page needs. Sub-
      # controllers don't pre-populate `dubious_where_reasons` or
      # `submitted_project_ids` (no form re-render path here), so
      # pass the empty defaults the form's parity with the main
      # `new` page expects.
      render(Views::Controllers::SpeciesLists::New.new(
               species_list: @species_list,
               projects: @projects,
               dubious_where_reasons: [],
               submitted_project_ids: nil,
               user: @user
             ))
    end

    ############################################################################

    include SpeciesLists::SharedPrivateMethods # shared private methods
    include SpeciesLists::SharedRenderMethods # shared private methods
  end
end
