# encoding: utf-8
#
#  = External Link Model
#
#  An external link is a URL attached to a single observation which links to a
#  related record on an external site.  It is associated with a record in the
#  external_sites table, which potentially eventually among other things, tells
#  the site who is allowed to create external links to that site.  It is
#  important to note that only the owner of an observation and users associated
#  with an external_site (via an external_site's project's member user_group)
#  are allowed to attach a URL for that external_site to that observation. 
#
#  (Wow, that was difficult to write...)
#
#  == Attributes
#
#  id::            Locally unique numerical id, starting at 1.
#  created_at::    Date/time it was first created.
#  updated_at::    Date/time it was last updated.
#  user::          User that created it.
#  observation::   Observation the URL is attached to.
#  external_site:: External site the URL points to.
#  url::           Actual URL, complete with transport ("http://"), etc.
#
class ExternalLink < AbstractModel
  belongs_to :observation
  belongs_to :external_site
  belongs_to :user

  validates :observation,   presence: true
  validates :external_site, presence: true
  validates :user,          presence: true
  validates :url,           presence: true, length: { maximum: 100 }
  validate  :check_url_syntax

  VALID_URL_PAT = %r{^[a-z]+://}

  def check_url_syntax
    return if url.to_s =~ VALID_URL_PAT
    errors.add(:url, :validate_invalid_url.t)
  end

  # Convenience function to allow +sort_by(&:site_name)+.
  def site_name
    external_site.name
  end
end
