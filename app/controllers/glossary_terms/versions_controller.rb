# frozen_string_literal: true

# show_past_glossary_term
module GlossaryTerms
  class VersionsController < ApplicationController
    before_action :login_required
    before_action :store_location

    # Show past versions of GlossaryTerm.
    # Accessible only from show_glossary_term page.
    def show
      return unless find_glossary_term!

      @glossary_term.revert_to(params[:version].to_i)
      @versions = @glossary_term.versions
    end

    private

    def find_glossary_term!
      @glossary_term = find_or_goto_index(GlossaryTerm,
                                          params[:id].to_s)
    end
  end
end
