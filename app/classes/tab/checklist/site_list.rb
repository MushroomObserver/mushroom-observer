# frozen_string_literal: true

# "Site stats: observed taxa" checklist link. The checklist domain
# is otherwise still helper-based (cross-deps on users + species_lists
# helpers); this single PORO is split out because the site_stats
# action-nav (info domain) composes it.
class Tab::Checklist::SiteList < Tab::Base
  def title
    :site_stats_observed_taxa.t
  end

  def path
    checklist_path
  end
end
