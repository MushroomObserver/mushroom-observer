# frozen_string_literal: true

require("test_helper")

class ImageTest < UnitTestCase
  include ActiveJob::TestHelper
  include ActionCable::TestHelper

  # log_update/log_destroy/log_create_for/log_reuse_for/log_remove_from
  # attribute to `current_user` (the acting/editing user), not `user`
  # (the image's owner) - an admin editing/removing someone else's image
  # should show up in the RSS log as the admin, not the owner.
  def test_log_destroy_attributes_to_current_user_not_owner
    image = images(:turned_over_image)
    obs = image.observations.first
    assert_not_equal(rolf, image.user)

    image.current_user = rolf
    image.log_destroy

    new_line = obs.rss_log.notes.lines.first
    assert_match(/log_image_destroyed/, new_line)
    assert_match(/rolf/, new_line)
    assert_no_match(/#{image.user.login}/, new_line)
  end

  def test_log_create_for_attributes_to_current_user_not_owner
    image = images(:turned_over_image)
    obs = observations(:coprinus_comatus_obs)
    assert_not_equal(rolf, image.user)

    image.current_user = rolf
    image.log_create_for(obs)

    assert_match(/rolf/, obs.rss_log.notes)
  end

  def test_votes
    img = images(:in_situ_image)
    assert_empty(img.image_votes)
    assert_equal(0, img.num_votes)
    assert_equal(0, img.vote_cache.to_i)
    assert_nil(img.users_vote(mary))
    assert_nil(img.users_vote(rolf))

    img.change_vote(mary, 2)
    assert_equal(1, img.num_votes)
    assert_equal(2, img.vote_cache)
    assert_equal(2, img.users_vote(mary))
    assert_nil(img.users_vote(rolf))
    assert_false(img.image_votes.first.anonymous)

    img.change_vote(rolf, 4, anon: true)
    assert_equal(2, img.num_votes)
    assert_equal(3, img.vote_cache)
    assert_equal(2, img.users_vote(mary))
    assert_equal(4, img.users_vote(rolf))

    img.change_vote(mary, nil)
    assert_equal(1, img.num_votes)
    assert_equal(4, img.vote_cache)
    assert_equal(4, img.users_vote(rolf))
    assert_nil(img.users_vote(mary))
    assert_true(img.image_votes.first.anonymous)

    img.change_vote(rolf, nil)
    assert_nil(img.users_vote(mary))
    assert_nil(img.users_vote(rolf))
  end

  def test_copyright_logging
    license_one = licenses(:ccnc25)
    license_two = licenses(:ccwiki30)
    name_one = "Bobby Singer"
    name_two = "Robert H. Singer"
    date_one = Date.parse("2007-12-31")
    date_two = Date.parse("2008-01-01")

    img = Image.create(
      user: mary,
      when: date_one,
      license: license_one,
      copyright_holder: name_one
    )
    img.current_user = mary
    assert_equal(date_one.year, img.when.year)
    assert_equal(license_one, img.license)
    assert_equal(name_one, img.copyright_holder)
    assert_equal(0, img.copyright_changes.length)

    img.original_name = "blah blah"
    img.save
    img.reload
    assert_equal(0, img.copyright_changes.length)

    img.when = date_two
    img.save
    img.reload
    assert_equal(date_two.year, img.when.year)
    assert_not_equal(date_one.year, date_two.year)
    assert_equal(1, img.copyright_changes.length)

    img.copyright_holder = name_two
    img.license = license_two
    img.save
    img.reload
    assert_equal(name_two, img.copyright_holder)
    assert_equal(license_two, img.license)
    assert_equal(2, img.copyright_changes.length)

    changes = img.copyright_changes
    assert_equal(2, changes.length)
    assert_equal(date_one.year, changes[0].year)
    assert_equal(name_one,      changes[0].name)
    assert_equal(license_one,   changes[0].license)
    assert_equal(date_two.year, changes[1].year)
    assert_equal(name_one,      changes[1].name)
    assert_equal(license_one,   changes[1].license)
  end

  def test_project_ownership
    # NOT owned by Bolete project, but owned by Rolf
    img = images(:commercial_inquiry_image)
    assert_true(img.can_edit?(rolf))
    assert_false(img.can_edit?(mary))
    assert_false(img.can_edit?(dick))

    # IS owned by Bolete project, AND owned by Mary
    # (Dick is member of Bolete project)
    img = images(:in_situ_image)
    assert_false(img.can_edit?(rolf))
    assert_true(img.can_edit?(mary))
    assert_true(img.can_edit?(dick))
  end

  def test_validation
    img = Image.new
    assert_false(img.valid?)
    img.user = rolf
    assert_true(img.valid?)
    do_truncate_test(img, :content_type, 100)
    do_truncate_test(img, :copyright_holder, 255)
  end

  def do_truncate_test(img, var, len)
    exes = "x" * (len - 1)
    assert_truncated_right(img, var, exes, exes)
    assert_truncated_right(img, var, "#{exes}a", "#{exes}a")
    assert_truncated_right(img, var, "#{exes}å", "#{exes}å")
    assert_truncated_right(img, var, "#{exes}aå", "#{"x" * (len - 3)}...")
  end

  def assert_truncated_right(img, var, set, get)
    img.send(:"#{var}=", set)
    img.valid?
    assert_equal(get, img.send(var))
  end

  def test_presence_of_critical_external_scripts
    assert_not(Rails.root.join("script/bogus_script").exist?,
               "script/bogus_script should not exist!")
    # strip_exif is still shelled out to by Image#strip_gps! (the image
    # resize/transfer scripts are all Ruby now -- see Image::Processor).
    assert(Rails.root.join("script/strip_exif").exist?,
           "Missing script/strip_exif!")
  end

  def test_transform
    img = Image.new
    assert_no_enqueued_jobs { assert_nil(img.transform(:mirror)) }
    assert_raises(RuntimeError) { img.transform(:edible) }
  end

  def test_transform_enqueues_rotate_image_job
    img = images(:in_situ_image)
    assert_enqueued_with(job: RotateImageJob,
                         args: [img.id, img.original_extension, "-90"]) do
      img.transform(:rotate_left)
    end
  end

  # dHash is computed from the small local rendition — never the full-size
  # original, whose ImageMagick decode can exhaust the host (#4796).
  def test_compute_dhash_uses_small_local_rendition
    img = images(:in_situ_image)
    small = img.full_filepath(:small)
    hashed = nil
    File.stub(:exist?, ->(path) { path == small }) do
      Image::Dhash.stub(:from_file, lambda { |path|
        hashed = path
        456
      }) do
        assert_equal(456, img.compute_dhash!)
      end
    end
    assert_equal(small, hashed)
    assert_equal(456, img.reload.dhash)
  end

  # With no local rendition (e.g. after originals are cleaned up),
  # compute_dhash! fetches the remote small rendition — still never the
  # full-size original (#4796).
  def test_compute_dhash_fetches_remote_small_when_no_local_file
    img = images(:in_situ_image)
    fetched = nil
    img.stub(:full_filepath, "/no/such/file.jpg") do
      Image::Dhash.stub(:from_url, lambda { |url|
        fetched = url
        123
      }) do
        assert_equal(123, img.compute_dhash!)
      end
    end
    assert_equal(img.small_url, fetched)
    assert_equal(123, img.reload.dhash)
  end

  def test_validate_vote_rescues_non_numeric
    assert_nil(Image.validate_vote(Object.new))
  end

  def test_num_votes_at_a_given_level
    img = images(:in_situ_image)
    assert_equal(0, img.num_votes(2))

    img.change_vote(mary, 2)

    assert_equal(1, img.num_votes(2))
    assert_equal(0, img.num_votes(4))
  end

  def test_other_subjects
    img = images(:in_situ_image)

    assert_not_empty(img.all_subjects)
    # An unrelated object leaves the image's own subjects in place.
    assert(img.other_subjects?(Object.new))
  end

  def test_original_extension_by_content_type
    {
      "image/jpeg" => "jpg", "image/gif" => "gif", "image/png" => "png",
      "image/tiff" => "tiff", "image/bmp" => "bmp",
      "image/x-ms-bmp" => "bmp", "image/webp" => "webp",
      "image/heif" => "heic", "application/octet-stream" => "raw"
    }.each do |content_type, ext|
      assert_equal(ext, Image.new(content_type: content_type).
                        original_extension)
    end
  end

  def test_image_dir_defaults_and_override
    img = Image.new

    assert_equal(MO.local_image_files, img.image_dir)

    img.image_dir = "/custom/dir"

    assert_equal("/custom/dir", img.image_dir)
  end

  def test_image_setter_rejects_unknown_type
    assert_raises(RuntimeError) { Image.new.image = 42 }
  end

  def test_init_image_from_local_file_blank_path
    file = Struct.new(:path).new("")

    assert_raises(RuntimeError) do
      Image.new.init_image_from_local_file(file)
    end
  end

  def test_init_image_from_stream_content_length
    img = Image.new
    stream = Object.new
    stream.define_singleton_method(:content_length) { "42\n" }

    img.init_image_from_stream(stream)

    assert_equal("42", img.upload_length)
  end

  def test_upload_from_url
    img = Image.new
    upload = Struct.new(:content, :content_length, :content_type,
                        :content_md5).
             new(StringIO.new("data"), 4, "image/jpeg", "abc123")
    upload.define_singleton_method(:clean_up) { nil }

    API2::UploadFromURL.stub(:new, ->(_url) { upload }) do
      img.upload_from_url("https://example.org/x.jpg")
    end

    assert_equal(4, img.upload_length)
    assert_equal("image/jpeg", img.upload_type)
    assert_equal("abc123", img.upload_md5sum)
    assert_respond_to(img.clean_up_proc, :call)
  end

  def test_validate_image_length_too_big
    img = Image.new
    img.upload_length = MO.image_upload_max_size + 1

    assert_not(img.validate_image_length)
    assert(img.errors[:image].any?)
  end

  def test_save_to_temp_file_rescues_copy_error
    img = Image.new
    img.upload_handle = StringIO.new("data")

    Tempfile.stub(:new, ->(*) { raise("boom") }) do
      assert_not(img.save_to_temp_file)
    end
    assert(img.errors[:image].any?)
  end

  def test_save_to_temp_file_rejects_invalid_upload_handle
    img = Image.new
    img.upload_handle = Object.new # not an IO/StringIO/TeeInput

    assert_not(img.save_to_temp_file)
    assert(img.errors[:image].any?)
  end

  def test_process_image_before_save
    img = Image.new

    assert_not(img.process_image)
    assert(img.errors[:image].any?)
  end

  # A failed GPS strip must stop before Image::Processor#process is ever
  # reached -- an unstripped original must not propagate into resized/
  # transferred copies or get hashed (dhash is now computed inside
  # #process, #4796). See Image::Processor.strip_original_gps.
  def test_process_image_strip_failure_skips_processing
    img = images(:in_situ_image)
    img.upload_temp_file = "already-staged" # save_to_temp_file short-circuits

    processed = false
    processor = Object.new
    processor.define_singleton_method(:process) { processed = true }

    img.stub(:move_original, true) do
      Image::Processor.stub(:strip_original_gps, "boom") do
        Image::Processor.stub(:new, processor) do
          Rails.env.stub(:test?, false) do
            assert_not(img.process_image(strip: true))
          end
        end
      end
    end
    assert_not(processed, "strip failure must skip processing (and hashing)")
    assert(img.errors[:image].any?)
  end

  def test_process_image_command_failure
    img = images(:in_situ_image)
    img.upload_temp_file = "already-staged" # save_to_temp_file short-circuits

    failing_processor = Object.new
    def failing_processor.process
      raise("boom")
    end

    # Capture the rescue's Rails.logger.error call instead of letting it
    # through -- the test logger writes to $stdout, so the deliberate
    # "boom" backtrace otherwise dumps into the suite's console output
    # looking like a real failure. Capturing also pins the logging
    # contract itself, which the old passthrough never asserted.
    logged = nil
    img.stub(:move_original, true) do
      Image::Processor.stub(:new, failing_processor) do
        Rails.env.stub(:test?, false) do
          Rails.logger.stub(:error, ->(msg) { logged = msg }) do
            assert_not(img.process_image)
          end
        end
      end
    end
    assert(img.errors[:image].any?)
    assert_includes(logged, "Image::Processor failed for image #{img.id}")
    assert_includes(logged, "boom")
  end

  # Transfer-to-image-server is no longer part of Image::Processor#process
  # (see #4791 -- TransferImagesJob owns that now, asynchronously), and
  # the perceptual hash is computed inline in #process (#4796, no separate
  # job), so a successful resize enqueues only TransferImagesJob.
  def test_process_image_enqueues_transfer_job
    img = images(:in_situ_image)
    img.upload_temp_file = "already-staged" # save_to_temp_file short-circuits
    succeeding_processor = Object.new
    def succeeding_processor.process; end

    img.stub(:move_original, true) do
      Image::Processor.stub(:new, succeeding_processor) do
        Rails.env.stub(:test?, false) do
          assert_enqueued_with(job: TransferImagesJob,
                               args: [{ image_ids: [img.id] }]) do
            assert(img.process_image)
          end
        end
      end
    end
  end

  def test_move_original_system_fail
    img = Image.new
    File.stub(:rename, false) do
      Kernel.stub(:system, false) do
        assert_raises(RuntimeError) { img.move_original }
      end
    end
  end

  def test_glossary_terms
    img1  = images(:conic_image)
    img2  = images(:unused_image)
    term1 = glossary_terms(:conic_glossary_term)
    term2 = glossary_terms(:unused_thumb_and_used_image_glossary_term)
    assert_obj_arrays_equal([term1, term2].sort_by(&:id),
                            img1.glossary_terms.sort_by(&:id))
    assert_obj_arrays_equal([term1], img1.thumb_glossary_terms)
    assert_obj_arrays_equal([term2], img2.glossary_terms)
    assert_obj_arrays_equal([term2], img2.thumb_glossary_terms)
  end

  def test_delete_thmubnail_of_glossary_term_with_no_other_images
    term = glossary_terms(:conic_glossary_term)
    thumb = term.thumb_image
    other_images = term.images - [thumb]
    assert_not_nil(thumb)
    assert_empty(other_images)

    thumb.destroy!

    assert_nil(term.reload.thumb_image,
               "Glossary term has destroyed image as thumbnail!")
    assert_empty(term.images, "Glossary term should have no images left!")
  end

  def test_delete_thmubnail_of_glossary_term_with_multiple_images
    term = glossary_terms(:plane_glossary_term)
    thumb = term.thumb_image
    other_images = term.images - [thumb]
    assert_not_nil(thumb)
    assert_not_empty(other_images)
    assert_includes(thumb.glossary_terms, term)
    assert_includes(thumb.thumb_glossary_terms, term)
    thumb_id = thumb.id
    other_image_ids = other_images.map(&:id)

    thumb.destroy!

    assert_false(term.reload.image_ids.include?(thumb_id),
                 "Glossary term is attached to destroyed image!")
    assert_true(other_image_ids.include?(term.thumb_image_id),
                "Should have chosen another thumbnail for glossary term.")
  end

  def test_delete_thumbnail_of_observation_with_no_other_images
    obs = observations(:coprinus_comatus_obs)
    thumb = obs.thumb_image
    other_images = obs.images - [thumb]
    assert_not_nil(thumb)
    assert_empty(other_images)

    thumb.destroy!

    assert_nil(obs.reload.thumb_image,
               "Observation has destroyed image as thumbnail!")
    assert_empty(obs.images, "Observation should have no images left!")
  end

  def test_delete_thumbnail_of_observation_with_multiple_images
    obs = observations(:detailed_unknown_obs)
    thumb = obs.thumb_image
    other_images = obs.images - [thumb]
    assert_not_nil(thumb)
    assert_not_empty(other_images)
    assert_includes(thumb.observations, obs)
    assert_includes(thumb.thumb_observations, obs)
    thumb_id = thumb.id
    other_image_ids = other_images.map(&:id)

    thumb.destroy!

    assert_false(obs.reload.image_ids.include?(thumb_id),
                 "Observation is attached to destroyed image!")
    assert_true(other_image_ids.include?(obs.thumb_image_id),
                "Should have chosen another thumbnail for observation.")
  end

  def test_delete_user_profile_image
    assert_not_nil(rolf.image)

    rolf.image.destroy!

    assert_nil(rolf.reload.image_id,
               "Rolf's is using a destroyed image for profile image!")
  end

  def test_delete_project_image
    project = projects(:bolete_project)
    image = project.images.first
    assert_not_nil(image)
    image_id = image.id

    image.destroy!

    assert_false(project.reload.image_ids.include?(image_id),
                 "Project is still attached to a destroyed image!")
  end

  def test_delete_visual_group_image
    group = visual_groups(:visual_group_one)
    image = group.images.first
    assert_not_nil(image)
    image_id = image.id

    image.destroy!

    assert_false(group.reload.image_ids.include?(image_id),
                 "VisualGroup still references a destroyed image!")
  end

  def test_delete_image_with_votes
    image = images(:peltigera_image)
    image_id = image.id
    assert_not_empty(ImageVote.where(image_id: image_id))

    image.destroy!

    assert_empty(ImageVote.where(image_id: image_id),
                 "Failed to delete ImageVotes attached to destroyed image!")
  end

  # When no source exists, thumbnail/small return placeholders;
  # other sizes fall back to the remote source URL.
  def test_url_placeholder_for_untransferred_missing_images
    args = { id: 999_999, transferred: false, extension: "jpg" }

    url = Image::URL.new(args.merge(size: :thumbnail))
    assert_equal("/place_holder_thumb.jpg", url.url)

    url = Image::URL.new(args.merge(size: :small))
    assert_equal("/place_holder_320.jpg", url.url)

    url = Image::URL.new(args.merge(size: :medium))
    assert_not_equal("/place_holder_thumb.jpg", url.url)
    assert_not_equal("/place_holder_320.jpg", url.url)
  end

  # Rendition URLs are cache-busted with an updated_at token (#4808):
  # reprocessing (rotate/mirror) rewrites file contents under an
  # otherwise-stable path, so without the token browsers/CDNs keep
  # serving the old bytes until a hard refresh.
  def test_url_includes_updated_at_cache_busting_token
    img = images(:in_situ_image)
    img.transferred = true
    token = img.updated_at.to_i

    Image::ALL_SIZES.each do |size|
      url = img.url(size)
      assert(url.end_with?("/#{img.id}.jpg?#{token}"),
             "Expected #{size} URL #{url.inspect} to end with " \
             "cache-busting token ?#{token}")
    end
  end

  def test_url_cache_busting_token_changes_when_image_is_updated
    img = images(:in_situ_image)
    img.update_column(:transferred, true)
    old_url = img.reload.url(:medium)

    img.update_column(:updated_at, img.updated_at + 1.hour)

    assert_not_equal(old_url, img.reload.url(:medium),
                     "Expected URL to change when updated_at changes")
  end

  def test_url_placeholders_never_get_a_cache_busting_token
    url = Image::URL.new(size: :thumbnail, id: 999_999, transferred: false,
                         extension: "jpg", version: 123)

    assert_equal("/place_holder_thumb.jpg", url.url)
  end

  # Class-level Image.url (id-only call sites: textile embeds, map
  # popups, data exports) has no record to read updated_at from --
  # no token unless the caller passes one. Reports in particular
  # depend on these URLs staying stable.
  def test_class_level_url_has_no_token_unless_version_passed
    img = images(:in_situ_image)

    assert_not_includes(Image.url(:full_size, img.id, transferred: true), "?")
    assert(Image.url(:full_size, img.id,
                     transferred: true, version: 123).end_with?("?123"))
  end

  def test_broadcast_processed_update_fires_on_transferred_change
    image = images(:in_situ_image)
    image.update_column(:transferred, false)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [image, :processed])

    # `capture_broadcasts` JSON-decodes each message back to the raw
    # `<turbo-stream ...>` HTML string ActionCable stores it as.
    messages = capture_broadcasts(stream) { image.update(transferred: true) }

    # One broadcast_replace_to per INTERACTIVE_BROADCAST_SIZES entry --
    # and nothing else (the carousel-slide broadcast was removed along
    # with the obs-show carousel's subscription; only the image-show
    # page subscribes).
    assert_equal(Image::INTERACTIVE_BROADCAST_SIZES.length,
                 messages.length)
    Image::INTERACTIVE_BROADCAST_SIZES.each do |size|
      target = "interactive_image_#{image.id}_#{size}_media"
      assert(messages.any? { |m| m.include?(%(target="#{target}")) },
             "Expected a broadcast targeting #{target}")
    end
  end

  # Processing STARTS by flipping transferred true->false, BEFORE the
  # renditions are regenerated -- broadcasting at that moment would
  # push a new-token URL at stale files, and would duplicate
  # RotateImageJob's explicit end-of-processing broadcast (Copilot
  # review finding on #4825). Only the completion flip (false->true)
  # broadcasts.
  def test_broadcast_does_not_fire_when_transferred_becomes_false
    image = images(:in_situ_image)
    image.update_column(:transferred, true)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [image, :processed])

    assert_no_broadcasts(stream) { image.update(transferred: false) }
  end

  # The broadcast must not replay a page-specific image_link/votes/
  # extra_classes/identify combination -- it only knows the model, not
  # which page's props a given subscriber originally rendered with (a
  # matrix-box thumbnail's real image_link, votes: false on the
  # image-show page, etc). Confirms the fix for the bug where
  # rebroadcasting the *whole* Interactive component with defaults
  # would silently swap a thumbnail's link target to the image's own
  # show page, or make hidden votes reappear.
  def test_broadcast_interactive_sizes_omits_link_and_votes_markup
    image = images(:in_situ_image)
    image.update_column(:transferred, false)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [image, :processed])

    messages = capture_broadcasts(stream) { image.update(transferred: true) }

    media_messages = messages.select { |m| m.include?("_media") }
    assert_equal(Image::INTERACTIVE_BROADCAST_SIZES.length,
                 media_messages.length)
    media_messages.each do |m|
      assert_not_includes(m, "stretched-link")
      assert_not_includes(m, "image-vote-section")
    end
  end

  def test_broadcast_processed_update_fires_on_gps_stripped_change
    image = images(:in_situ_image)
    image.update_column(:gps_stripped, false)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [image, :processed])

    assert_broadcasts(stream, Image::INTERACTIVE_BROADCAST_SIZES.length) do
      image.update(gps_stripped: true)
    end
  end

  def test_broadcast_processed_update_does_not_fire_on_unrelated_changes
    image = images(:in_situ_image)
    stream = Turbo::StreamsChannel.send(:stream_name_from, [image, :processed])

    assert_no_broadcasts(stream) { image.update(notes: "new notes") }
  end

  def test_import_link
    img = images(:in_situ_image)
    assert_nil(img.import_link, "Image starts with no import link")

    link = ExternalLink.create!(
      user: img.user, target: img, external_site: ExternalSite.inaturalist,
      relationship: :import, external_id: "p1"
    )

    # Not-loaded branch: queries only the import row.
    img.external_links.reset
    assert_not(img.external_links.loaded?)
    assert_equal(link, img.import_link)

    # Loaded branch: detects within the already-loaded association.
    img.external_links.load
    assert(img.external_links.loaded?)
    assert_equal(link, img.import_link)
  end

  # ---- EXIF geocode reading (local file vs. remote via curl+exiftool) --

  # The image geotagged.jpg has this data (see also
  # ObservationFormSystemTest::GEOTAGGED_EXIF).
  GEOTAGGED_EXIF_GPS = { lat: 25.7582, lng: -80.3731, alt: 4 }.freeze

  def test_read_exif_geocode_local_file
    img = images(:in_situ_image)
    stage_geotagged_file(img.full_filepath("orig"))

    data = img.read_exif_geocode(hide_gps: false)

    assert_equal(GEOTAGGED_EXIF_GPS[:lat], data[:lat])
    assert_equal(GEOTAGGED_EXIF_GPS[:lng], data[:lng])
    assert_equal(GEOTAGGED_EXIF_GPS[:alt], data[:alt])
  ensure
    FileUtils.rm_f(img.full_filepath("orig"))
  end

  # Regression test: `script/exiftool_remote` used to only read `$1`
  # as a bare URL (fetched via `wget`), but `Image#read_exif_data`
  # calls it with `flags..., url` -- the same `cmd, *flags, path`
  # shape it uses for the local `exiftool` binary directly. That
  # argument-shape mismatch (compounded by `wget` not being installed
  # on every dev machine, unlike `curl`) silently broke EXIF re-reads
  # for any already-transferred image -- `read_exif_geocode` always
  # returned nil. See the corrected `curl [flags] url`-forwarding
  # shape in `script/exiftool_remote`.
  def test_read_exif_geocode_transferred_image
    img = images(:in_situ_image)
    img.update_column(:transferred, true)
    # original_url carries a `?<version>` cache-buster (#4808) that
    # curl correctly strips when resolving a `file://` URL -- but it's
    # not part of the real filesystem path, so strip it here too
    # before using this to stage the fixture file.
    remote_path = img.original_url.delete_prefix("file://").sub(/\?.*\z/, "")
    stage_geotagged_file(remote_path)

    data = img.read_exif_geocode(hide_gps: false)

    assert_equal(GEOTAGGED_EXIF_GPS[:lat], data[:lat])
    assert_equal(GEOTAGGED_EXIF_GPS[:lng], data[:lng])
    assert_equal(GEOTAGGED_EXIF_GPS[:alt], data[:alt])
  ensure
    FileUtils.rm_f(remote_path)
  end

  def stage_geotagged_file(path)
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.cp(Rails.root.join("test/images/geotagged.jpg"), path)
  end
end
