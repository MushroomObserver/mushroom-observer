# frozen_string_literal: true

class Inat
  # Builds a minimal "counterpart" MO Observation from an unlicensed
  # ::Inat::Obs (#4828) — for a superimporter's import-others run, when the
  # source iNat observation has no license. Carries only the iNat
  # observation id (via ExternalLink), date, location, collector, and a
  # single proposed name; never a photo, other suggested identifications,
  # a sequence, or a dump of the iNat obs's Notes/description into MO's
  # Notes. Unlike Inat::MoObservationBuilder, per-naming notifications are
  # NOT suppressed here — see Inat::ImportDigest, which excludes these
  # observations' namings from the end-of-import digest so interested
  # users aren't notified twice.
  class SkeletonObservationBuilder
    attr_reader :inat_obs, :user, :skipped_images, :unlicensed_obs,
                :created_image_ids

    def initialize(inat_obs:, user:, external_site: nil, inat_import: nil)
      @inat_obs = inat_obs
      @user = user
      @external_site = external_site || ExternalSite.inaturalist
      @inat_import = inat_import
      @skipped_images = 0
      @unlicensed_obs = 0
      @created_image_ids = []
    end

    def mo_observation
      create_observation
      add_external_link
      @observation
    rescue StandardError => e
      # Remove incomplete Observation from the db
      @observation&.destroy
      raise(e)
    end

    private

    def create_observation
      @observation = Observation.create(new_obs_params)
      add_naming_with_vote(name: name_resolver.lead_name, value: naming_vote)
      @observation.log(:log_observation_created, user: user)
    end

    def new_obs_params
      { user: user, notes: placeholder_notes,
        inat_import_id: @inat_import&.id }.
        merge(location_attrs).merge(name_attrs).merge(collector_attrs)
    end

    def location_attrs
      { when: inat_obs.when, location: inat_obs.location,
        where: inat_obs.where, lat: inat_obs.lat, lng: inat_obs.lng,
        gps_hidden: inat_obs.gps_hidden }
    end

    def name_attrs
      lead_name = name_resolver.lead_name
      { name_id: lead_name.id, text_name: lead_name.text_name }
    end

    # Link the collector to an MO user when the iNat collector (a custom
    # collector field, else the iNat login) matches a User#inat_username;
    # otherwise store the iNat name as free text. Same as
    # Inat::MoObservationBuilder — see PR #4452 / Joe.
    def collector_attrs
      Observation.resolve_collector(inat_obs.collector, owner: user,
                                                        match_inat: true)
    end

    # A single fixed line explaining the record's provenance, without
    # copying any of the iNat obs's actual notes/description text (#4828).
    def placeholder_notes
      { Observation.other_notes_key => placeholder_text }
    end

    def placeholder_text
      :inat_skeleton_placeholder_notes.t(
        inat_id: inat_obs[:id], name: inat_obs_owner_name
      ).to_str
    end

    # Same fallback Inat::Obs#copyright uses internally (obs's display
    # name, else their iNat login).
    def inat_obs_owner_name
      inat_obs[:user][:name].presence || inat_obs[:user][:login]
    end

    def name_resolver
      @name_resolver ||= Inat::LeadNameResolver.new(inat_obs: inat_obs,
                                                    user: user)
    end

    def add_external_link
      create_import_link(@observation, inat_obs[:id].to_s)
    end

    # Records import provenance as a polymorphic import ExternalLink on the
    # target (Observation or Image, #4299). The URL is derived from the
    # site's template + external_id, so none is stored.
    def create_import_link(target, external_id)
      ExternalLink.create!(
        user: user, target: target, external_site: @external_site,
        external_id: external_id, relationship: :import
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(
        "InatImport: failed to create ExternalLink for " \
        "#{target.class} #{target.id} (iNat #{external_id}): #{e.message}"
      )
    end

    def add_naming_with_vote(name:, value:)
      naming = Naming.create(
        observation: @observation, user: user, name: name,
        reasons: { 2 => naming_reason }
      )

      vote = Vote.create(naming: naming, observation: @observation,
                         user: user, value: value)
      # We need an ObservationView, but noone has actually viewed this Obs.
      ObservationView.create!(observation: @observation, user: user,
                              last_view: vote.updated_at, reviewed: 1)
    end

    # A single citation, not differentiated by override/provisional/
    # community (unlike Inat::MoObservationBuilder::NamingReasons) since
    # there's only ever one, un-attributed lead naming here.
    def naming_reason
      inat_link = "<a href=\"#{Inat::Constants::SITE}/observations/" \
                  "#{inat_obs[:id]}\">iNat #{inat_obs[:id]}</a>"
      "#{inat_link}, #{:inat_leading_id.l} " \
        "#{Time.zone.today.strftime("%Y-%m-%d")}"
    end

    # Confidence weight, matching Inat::MoObservationBuilder#naming_vote's
    # non-sequence branches — Research Grade is Promising, else Could Be.
    # Never the sequence-driven "confirmed" weight: sequences are excluded.
    def naming_vote
      research_grade? ? Vote::NEXT_BEST_VOTE : Vote::MIN_POS_VOTE
    end

    def research_grade?
      inat_obs[:quality_grade] == "research"
    end
  end
end
