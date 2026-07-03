# frozen_string_literal: true

# Sidebar indexes nav: glossary terms.
class Tab::Sidebar::Indexes::Glossary < Tab::Base
  def title
    :GLOSSARY.t
  end

  def path
    glossary_terms_path
  end
end
