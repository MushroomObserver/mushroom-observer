# frozen_string_literal: true

# Nomenclature panel — the largest Names::Show sub-view. Two-column
# panel body: left has rank / status / name / authority / citation;
# right has registry-aware ICN ID + external nomenclature DB links
# (Index Fungorum / MycoBank / GSD / SF / etc.). Below the columns:
# the "correct spelling" line for misspellings, and the synonyms
# block (approved / deprecated / misspelled groupings).
#
# Originally `_nomenclature.html.erb` (~146 lines). Now rendered by
# `Views::Controllers::Names::Show` and `Views::Controllers::Names::Versions::Show`
# (and any remaining legacy callers should render this view directly).
class Views::Controllers::Names::Show::Nomenclature < Views::Base
  register_value_helper :rank_as_string

  prop :name, ::Name
  prop :user, _Nilable(::User), default: nil

  def view_template
    render(Components::Panel.new(
             panel_class: "name-section",
             panel_id: "nomenclature"
           )) do |panel|
      panel.with_heading { plain(:show_name_nomenclature.l) }
      panel.with_heading_links { render_edit_link } if @user
      panel.with_body { render_body }
    end
  end

  private

  def render_edit_link
    render(Components::IconLink.new(
             tab: Tab::Name::Edit.new(name: @name)
           ))
  end

  def render_body
    div(class: "row") do
      render_left_column
      render_right_column
    end
    render_misspelling_correct_link if @name.is_misspelling?
    render_synonyms_block if synonyms_link
  end

  # --- Left column --------------------------------------------------

  def render_left_column
    div(class: "col-sm-6 name-section") do
      render_rank_line
      render_status_line
      render_name_line
    end
  end

  def render_rank_line
    p do
      rank_text = @name.rank ? rank_as_string(@name.rank) : :unknown.l
      plain("#{:RANK.l}: #{rank_text}")
    end
  end

  def render_status_line
    p do
      plain("#{:STATUS.l}: ")
      plain(@name.status)
      plain(" (#{:MISSPELLED.l})") if @name.is_misspelling?
      if approve_link || deprecate_link
        span(class: "text-nowrap ml-3") do
          render_synonym_links_inline
        end
      end
    end
  end

  # Inline emit (the Phlex idiom) — `render` flushes each
  # `Components::IconLink` straight to the buffer instead of
  # pre-building an HTML string.
  def render_synonym_links_inline
    links = [approve_link, deprecate_link].compact
    links.each_with_index do |link, idx|
      render(link)
      plain(" | ") if idx < links.length - 1
    end
  end

  def render_name_line
    render_name_paragraph
    render_authority_paragraph
    render_citation_paragraph
  end

  def render_name_paragraph
    p do
      plain("#{:NAME.l}: ")
      plain(@name.user_real_text_name(@user))
      span(class: "text-nowrap ml-3") { render(synonyms_link) } if synonyms_link
    end
  end

  def render_authority_paragraph
    p { plain("#{:AUTHORITY.l}: #{@name.author.to_s.t.strip_html}") }
  end

  def render_citation_paragraph
    p { plain("#{:CITATION.l}: #{@name.citation.to_s.tl.strip_html}") }
  end

  # --- Icon links (computed once, cached) ---------------------------

  def unlocked?
    in_admin_mode? || !@name.locked
  end

  def approve_link
    return nil unless unlocked? && @name.deprecated &&
                      @name.correct_spelling_id.nil?

    Components::IconLink.new(
      tab: Tab::Name::Approve.new(name: @name)
    )
  end

  def deprecate_link
    return nil unless unlocked? && !@name.deprecated

    Components::IconLink.new(
      tab: Tab::Name::Deprecate.new(name: @name)
    )
  end

  def synonyms_link
    return nil unless unlocked?

    Components::IconLink.new(
      tab: Tab::Name::EditSynonym.new(name: @name)
    )
  end

  # --- Right column -------------------------------------------------

  def render_right_column
    div(class: "col-sm-6 name-section") do
      if @name.icn_id?
        render_icn_id_links
      elsif @name.registrable?
        render_registrable_links
      elsif @name.searchable_in_registry?
        render_searchable_registry_links
      end
    end
  end

  def render_icn_id_links
    p do
      render_tab_link(Tab::Name::IndexFungorumRecord.new(name: @name))
      plain(" Index Fungorum")
    end
    p do
      render_tab_link(Tab::Name::MycobankRecord.new(name: @name))
      plain(" MycoBank")
    end
    p { render_fungorum_synonymy_link }
  end

  def render_fungorum_synonymy_link
    if @name.at_or_below_species?
      render_tab_link(Tab::Name::FungorumGsdSynonymy.new(name: @name))
    elsif %w[Genus Family].include?(@name.rank)
      render_tab_link(Tab::Name::FungorumSfSynonymy.new(name: @name))
    end
  end

  def render_registrable_links
    p do
      plain("#{:ICN_ID.l}: ")
      em { plain(:show_name_icn_id_missing.l) }
    end
    p { render_tab_link(Tab::Name::IndexFungorumSearchPage.new) }
    p do
      render_tab_link(Tab::Name::IndexFungorumNameSearch.new(name: @name))
    end
    p { render_tab_link(Tab::Name::MycobankSearch.new(name: @name)) }
  end

  def render_searchable_registry_links
    p { render_tab_link(Tab::Name::IndexFungorumSearchPage.new) }
    p do
      render_tab_link(Tab::Name::IndexFungorumNameSearch.new(name: @name))
    end
    p { render_tab_link(Tab::Name::MycobankBasicSearch.new) }
  end

  # --- Misspelling correct-spelling line ----------------------------

  def render_misspelling_correct_link
    p do
      plain("#{:show_name_misspelling_correct.l}: ")
      if @name.correct_spelling
        a(href: name_path(@name.correct_spelling_id)) do
          plain(@name.correct_spelling.user_display_name(@user).t.strip_html)
        end
      else
        plain(@name.correct_spelling_id.to_s)
      end
    end
  end

  # --- Synonyms block (approved / deprecated / misspelled) ----------

  def render_synonyms_block
    approved, deprecated = @name.sort_synonyms
    misspellings = deprecated.select(&:correct_spelling_id)
    deprecated.reject!(&:correct_spelling_id)

    render_synonym_group(label_for_approved, approved)
    render_synonym_group(:show_name_deprecated_synonyms.l, deprecated)
    render_synonym_group(:show_name_misspelled_synonyms.l, misspellings)
  end

  def label_for_approved
    if @name.deprecated
      :show_name_preferred_synonyms.l
    else
      :show_name_synonyms.l
    end
  end

  def render_synonym_group(label, names)
    return if names.blank?

    p do
      plain("#{label}: ")
      names.each_with_index do |n, idx|
        a(href: name_path(n.id)) do
          plain(n.user_display_name(@user).t.strip_html)
        end
        plain(", ") if idx < names.length - 1
      end
    end
  end

  # --- Helper ------------------------------------------------------

  def render_tab_link(tab)
    text, url, opts = tab.to_a
    a(href: url, **(opts || {}).slice(:class, :target, :rel)) do
      plain(text)
    end
  end
end
