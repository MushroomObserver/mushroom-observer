# encoding: utf-8
require 'test_helper'
require 'account_mailer'

class AccountMailerTest < ActiveSupport::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures/account_mailer'

  def setup
    Locale.code = "en"
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    @expected = TMail::Mail.new
    @expected.mime_version = '1.0'
  end

  # At the moment at least Redcloth produces slightly different output on
  # Nathan's laptop than on Jason's.  I'm trying to reduce both responses to a
  # common form so that we don't need to continue to tweak two separate copies
  # of every email response.  But I'm failing...
  def fix_mac_vs_pc!(email)
    email.gsub!(/<br \/>\n/, '<br/>')
    email.gsub!(/&#38;/, '&amp;')
    email.gsub!(/ &#8212;/, '&#8212;')
    email.gsub!(/^\s+/, '')
    email.gsub!(/[\n\r]+/, "\n")
  end

  # Run off an email in both HTML and text form.
  def run_mail_test(name, user=nil, &block)
    clean_our_backtrace('run_mail_test') do
      text_files = Dir.glob("#{FIXTURES_PATH}/#{name}.text*").
                       reject {|x| x.match(/\.new$/)}
      html_files = Dir.glob("#{FIXTURES_PATH}/#{name}.html*").
                       reject {|x| x.match(/\.new$/)}

      assert(text_files.any? || html_files.any?)
      
      if text_files.any?
        user.email_html = false if user
        email = block.call.encoded
        assert_string_equal_file(email, *text_files)
      end

      if html_files.any?
        user.email_html = true if user
        email = block.call.encoded
        fix_mac_vs_pc!(email)
        assert_string_equal_file(email, *html_files)
      end
    end
  end

################################################################################

  def test_email_1
    project = projects(:eol_project)
    run_mail_test('admin_request', rolf) do
      AccountMailer.create_admin_request(katrina, rolf, project,
        'Please do something or other', 'and this is why...')
    end
  end

  def test_email_2
    obj = names(:coprinus_comatus)
    run_mail_test('author_request', rolf) do
      AccountMailer.create_author_request(katrina, rolf, obj.description,
                        'Please do something or other', 'and this is why...')
    end
  end

  def test_email_3
    obs = observations(:minimal_unknown)
    comment = comments(:another_comment)
    run_mail_test('comment_response', rolf) do
      email = AccountMailer.create_comment(dick, rolf, obs, comment)
    end
  end

  def test_email_4
    obs = observations(:minimal_unknown)
    comment = comments(:minimal_comment)
    run_mail_test('comment', mary) do
      email = AccountMailer.create_comment(rolf, mary, obs, comment)
    end
  end

  def test_email_5
    image = images(:commercial_inquiry_image)
    run_mail_test('commercial_inquiry', image.user) do
      AccountMailer.create_commercial_inquiry(mary, image,
                                          'Did test_commercial_inquiry work?')
    end
  end

  def test_email_6
    obs = observations(:coprinus_comatus_obs)
    name1 = names(:agaricus_campestris)
    name2 = obs.name

    # The umlaut in Mull. is making it do weird encoding on the subject line.
    name2.search_name = name2.search_name.to_ascii
    name2.display_name = name2.display_name.to_ascii

    run_mail_test('consensus_change', mary) do
      AccountMailer.create_consensus_change(dick, mary, obs, name1, name2,
                                            obs.created_at)
    end
  end

  def test_email_7
    run_mail_test('denied') do
      AccountMailer.create_denied(junk)
    end
  end

  def test_email_8
    run_mail_test('email_features', rolf) do
      AccountMailer.create_email_features(rolf, 'A feature')
    end
  end

  def test_email_9
    loc = locations(:albion)
    desc = loc.description
    run_mail_test('location_change', mary) do
      AccountMailer.create_location_change(dick, mary, loc.updated_at, loc,
                                           desc, 1, 2, 1, 2)
    end
  end

  def test_email_10
    name = names(:peltigera)
    desc = name.description
    run_mail_test('name_change', mary) do
      AccountMailer.create_name_change(dick, mary, name.updated_at, name, desc,
                                       1, 2, 1, 2, desc.review_status)
    end
  end

  def test_email_11
    # Test for bug that occurred in the wild
    name = names(:peltigera)
    desc = name.description
    run_mail_test('name_change2', mary) do
      AccountMailer.create_name_change(dick, mary, name.updated_at, name, desc,
                                       0, 1, 0, 1, desc.review_status)
    end
  end

  def test_email_12
    naming = namings(:coprinus_comatus_other_naming)
    obs = observations(:coprinus_comatus_obs)
    run_mail_test('name_proposal', rolf) do
      AccountMailer.create_name_proposal(mary, rolf, naming, obs)
    end
  end

  def test_email_13
    naming = namings(:agaricus_campestris_naming)
    notification = notifications(:agaricus_campestris_notification_with_note)
    run_mail_test('naming_for_observer', rolf) do
      AccountMailer.create_naming_for_observer(rolf, naming, notification)
    end
  end

  def test_email_14
    naming = namings(:agaricus_campestris_naming)
    run_mail_test('naming_for_tracker', mary) do
      AccountMailer.create_naming_for_tracker(mary, naming)
    end
  end

  def test_email_15
    run_mail_test('new_password', rolf) do
      AccountMailer.create_new_password(rolf, 'A password')
    end
  end

  def test_email_16
    obs = observations(:coprinus_comatus_obs)
    name = obs.name

    # The umlaut in Mull. is making it do weird encoding on the subject line.
    name.search_name = name.search_name.to_ascii
    name.display_name = name.display_name.to_ascii

    run_mail_test('observation_change', mary) do
      AccountMailer.create_observation_change(dick, mary, obs,
        'date,location,specimen,is_collection_location,notes,' +
        'thumb_image_id,added_image,removed_image', obs.created_at)
    end
    run_mail_test('observation_destroy', mary) do
      AccountMailer.create_observation_change(dick, mary, nil,
        '**__Coprinus comatus__** L. (123)', obs.created_at)
    end
  end

  def test_email_17
    obs = observations(:detailed_unknown)
    run_mail_test('observation_question', obs.user) do
      AccountMailer.create_observation_question(rolf, obs,
        'Where did you find it?')
    end
  end

  def test_email_18
    name = names(:agaricus_campestris)
    run_mail_test('publish_name', rolf) do
      AccountMailer.create_publish_name(mary, rolf, name)
    end
  end

  def test_email_19
    run_mail_test('user_question', mary) do
      AccountMailer.create_user_question(rolf, mary,
        'Interesting idea', 'Shall we discuss it in email?')
    end
  end

  def test_email_20
    run_mail_test('verify', mary) do
      AccountMailer.create_verify(mary)
    end
  end

  def test_email_21
    run_mail_test('webmaster_question') do
      AccountMailer.create_webmaster_question(mary.email, 'A question')
    end
  end

  def test_email_22
    run_mail_test('email_registration') do
      AccountMailer.create_email_registration(nil, conference_registrations(:njw_at_msa))
    end
  end

  def test_email_23
    run_mail_test('update_registration') do
      reg = conference_registrations(:njw_at_msa)
      before = reg.describe
      reg.how_many = 5
      reg.notes = "5 is better than 4"
      reg.save
      AccountMailer.create_update_registration(nil, reg, before)
    end
  end

  def test_email_24
    run_mail_test('verify_api_key', rolf) do
      AccountMailer.create_verify_api_key(rolf, dick, ApiKey.first)
    end
  end

  def test_email_add_specimen_not_curator
    specimen = specimens(:interesting_unknown)
    run_mail_test('add_specimen_not_curator', rolf) do
      AccountMailer.create_add_specimen_not_curator(mary, rolf, specimen)
    end
  end
end
