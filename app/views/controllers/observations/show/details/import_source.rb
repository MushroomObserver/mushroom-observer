# frozen_string_literal: true

# One inline line at the top of `Details`, above when/where/who, for
# obs imported from an external source (iNat, MyCoPortal, etc.).
# Hides silently for non-imported obs -- `external_credit_link`
# resolves the import link, its URL, and the external id together
# (nil when not imported).
class Views::Controllers::Observations::Show::Details::ImportSource < Views::Base
  HELP_ARTICLE_ID = 39

  prop :obs, ::Observation

  def view_template
    return unless (link = @obs.external_credit_link)

    p(class: "obs-import-source", id: "observation_import_source") do
      render_credit(link)
      whitespace
      render_help_link
    end
  end

  private

  def render_credit(link)
    Link(type: :external, content: credit_text(link), path: link[:url])
  end

  # Import link's URL always resolves (stored override or derived from
  # the site template), so the credit always renders as a link.
  def credit_text(link)
    return link[:text] if link[:external_id].blank?

    "#{link[:text]} #{link[:external_id]}"
  end

  # (?) info icon linking to the MO docs article about imports.
  # On-site, so does NOT open in a new tab (unlike the credit link).
  def render_help_link
    a(href: article_path(HELP_ARTICLE_ID),
      title: :source_credit_help_link.l,
      aria: { label: :source_credit_help_link.l }) { Icon(type: :question) }
  end
end
