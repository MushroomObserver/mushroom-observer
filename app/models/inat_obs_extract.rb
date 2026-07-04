# frozen_string_literal: true

# Compact cache of an iNat observation's comparison-relevant fields (#4585).
# Built from the raw iNat API JSON via Inat::Obs so field semantics match
# the importer (the same `when`/taxon/ofvs parsing), plus a few raw fields
# the importer does not surface (obscured flag, public accuracy, photo
# medium urls, iNat's updated_at). Populated by
# script/build_inat_obs_extracts.rb and consumed by the reflection
# comparator and discovery matching.
class InatObsExtract < ApplicationRecord
  # Photo rendition to cache/hash: resolution-invariant dHash means the
  # medium size is plenty and far cheaper to fetch than the original.
  PHOTO_SIZE = "medium"

  validates :inat_id, presence: true,
                      uniqueness: true
  validates :fetched_at, presence: true

  # Build (without saving) an extract from one raw iNat observation hash
  # (a single element of the API's `results` array).
  def self.from_raw(raw, fetched_at:)
    obs = Inat::Obs.new(JSON.generate(raw))
    new(attributes_from(obs, raw).merge(fetched_at: fetched_at))
  end

  # Upsert one raw iNat observation hash, keyed on inat_id. Returns the
  # persisted record.
  def self.upsert_from_raw(raw, fetched_at:)
    record = from_raw(raw, fetched_at: fetched_at)
    existing = find_by(inat_id: record.inat_id)
    if existing
      existing.update!(
        record.attributes.except("id", "created_at", "updated_at")
      )
      existing
    else
      record.save!
      record
    end
  end

  def self.attributes_from(obs, raw)
    {
      inat_id: raw[:id],
      inat_login: raw.dig(:user, :login),
      observed_on: obs.when,
      lat: obs.lat,
      lng: obs.lng,
      public_accuracy: raw[:public_positional_accuracy],
      obscured: raw[:obscured] || false,
      taxon_name: obs.inat_taxon_name,
      taxon_rank: obs.inat_taxon_rank,
      place_guess: obs.where,
      description: raw[:description],
      photos: photos_from(raw),
      ofvs: obs.inat_obs_fields,
      inat_updated_at: raw[:updated_at]
    }
  end
  private_class_method :attributes_from

  # [{ "id" =>, "url" => }] with the medium-size rendition url. The iNat API
  # returns a `square` thumbnail url; swap the size token, mirroring
  # Inat::ObsPhoto#url (which swaps to "original").
  def self.photos_from(raw)
    Array(raw[:observation_photos]).map do |obs_photo|
      photo = obs_photo[:photo] || {}
      { "id" => obs_photo[:photo_id] || photo[:id],
        "url" => photo[:url]&.sub("square", PHOTO_SIZE) }
    end
  end
  private_class_method :photos_from
end
