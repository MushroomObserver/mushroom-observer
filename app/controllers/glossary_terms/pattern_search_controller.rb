# frozen_string_literal: true

# GlossaryTerms pattern search form.
#
# Route: `new_glossary_term_search_path`
# Only one action here. Call namespaced controller actions with a hash like
# `{ controller: "/glossary_terms/pattern_search", action: :create }`
module GlossaryTerms
  class PatternSearchController < ApplicationController
    before_action :login_required

    def new
    end
  end
end
