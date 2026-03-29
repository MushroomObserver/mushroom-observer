# frozen_string_literal: true

# RSS logging, email notifications, and primary-touch methods
# for occurrence lifecycle events.
module Occurrence::Logging
  extend ActiveSupport::Concern

  class_methods do
    # Log and notify when observations are added to an occurrence.
    def log_observation_added(obs_list, user = User.current)
      log_obs_event(obs_list, :log_occurrence_added, user)
    end

    # Field slip variant — includes field slip code in log entry.
    def log_field_slip_added(obs_list, user = User.current)
      code = field_slip_code_for(obs_list)
      log_obs_event(obs_list, :log_field_slip_added, user,
                    touch_tag: :log_field_slip_updated, name: code)
    end

    # Log and notify when an observation is removed.
    def log_observation_removed(obs, occ = nil, user = User.current)
      log_obs_removal(obs, occ, :log_occurrence_removed, user)
    end

    # Field slip variant.
    def log_field_slip_removed(obs, occ = nil, user = User.current)
      resolved = occ || obs.occurrence
      code = resolved&.field_slip&.code
      log_obs_removal(obs, occ, :log_field_slip_removed, user,
                      touch_tag: :log_field_slip_updated, name: code)
    end

    # Update the primary observation's log_updated_at so it appears
    # at the top of Activity-sorted indexes and RSS feeds.
    def touch_primary(occ, exclude: [],
                      tag: :log_occurrence_updated, name: nil)
      return unless occ&.persisted?

      primary = occ.primary_observation
      return unless primary
      return if exclude.any? { |obs| obs.id == primary.id }

      primary.log(tag, touch: true, name: name)
    end

    private

    def log_obs_event(obs_list, tag, user,
                      touch_tag: :log_occurrence_updated, name: nil)
      occ = nil
      obs_list.each do |obs|
        obs.log(tag, touch: true, name: name)
        notify_observation_owner(obs, :added, user)
        occ ||= obs.occurrence
      end
      touch_primary(occ, exclude: obs_list, tag: touch_tag,
                         name: name)
    end

    def log_obs_removal(obs, occ, tag, user, **opts)
      occ ||= obs.occurrence
      obs.log(tag, touch: true, name: opts[:name])
      notify_observation_owner(obs, :removed, user)
      touch_primary(occ,
                    tag: opts[:touch_tag] || :log_occurrence_updated,
                    name: opts[:name])
    end

    def field_slip_code_for(obs_list)
      occ = obs_list.first&.occurrence
      occ&.field_slip&.code
    end

    def notify_observation_owner(obs, action, user)
      owner = obs.user
      return if owner == user || owner.no_emails

      OccurrenceChangeMailer.build(
        sender: user, receiver: owner,
        observation: obs, action: action
      ).deliver_later
    end
  end
end
