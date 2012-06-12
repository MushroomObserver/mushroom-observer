# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot')

class TranslationControllerTest < FunctionalTestCase

#   def mock_template
#     [
#       "---\n",
#       " garbage \n",
#       "##################################\n",
#       "\n",
#       "# IMPORTANT STUFF\n",
#       "\n",
#       "# Main Objects:\n",
#       "image: image\n",
#       "name: name\n",
#       "user: user\n",
#       "\n",
#       "# Actions:\n",
#       "prev: Prev\n",
#       "# ignore this comment\n",
#       "next: Next\n",
#       "index: Index\n",
#       "show_object: Show [type]\n",
#       "\n",
#       "##################################\n",
#       "\n",
#       "# MAIN PAGES\n",
#       "\n",
#       "# observer/index\n",
#       "index_title: Main Index\n",
#       "# you don't see this every day\n",
#       "index_error: An unusual error occurred\n",
#       "index_help: >\n",
#       "  This page shows an index of objects.\n",
#       "\n",
#       "index_prefs: Your Account\n",
#       "\n",
#       "# account/prefs\n",
#       "prefs_title: Your Account\n",
#       "\n",
#     ].join
#   end
# 
#   def hashify(*args)
#     hash = {}
#     for arg in args
#       hash[arg] = true
#     end
#     return hash
#   end
# 
#   def assert_major_header(str, item)
#     assert(item.is_a? TranslationController::TranslationFormMajorHeader)
#     assert_equal(str, item.string)
#   end
# 
#   def assert_minor_header(str, item)
#     assert(item.is_a? TranslationController::TranslationFormMinorHeader)
#     assert_equal(str, item.string)
#   end
# 
#   def assert_comment(str, item)
#     assert(item.is_a? TranslationController::TranslationFormComment)
#     assert_equal(str, item.string)
#   end
# 
#   def assert_tag_field(tag, item)
#     assert(item.is_a? TranslationController::TranslationFormTagField)
#     assert_equal(tag, item.tag)
#   end
# 
# ################################################################################
# 
#   def test_edit_translations_with_page
#     Language.track_usage
#     :name.l
#     assert_equal(['name'], Language.tags_used)
#     page = Language.save_tags
#     get(:edit_translations, :page => page)
#   end
# 
#   def test_get_associated_tags
#     lang = languages(:english)
#     strings = lang.localization_strings
#     assert_equal(%w(TWO TWOS four one three two twos), strings.keys.sort)
#     tags1 = @controller.get_associated_tags(['one'], strings)
#     tags2 = @controller.get_associated_tags(['two'], strings)
#     tags3 = @controller.get_associated_tags(['Two'], strings)
#     tags4 = @controller.get_associated_tags(['TWOS'], strings)
#     tags5 = @controller.get_associated_tags(['tWoS', 'FoUr'], strings)
#     assert_equal({'one' => true}, tags1)
#     assert_equal({'two' => true}, tags2)
#     assert_equal({'two' => true}, tags3)
#     assert_equal({'two' => true}, tags4)
#     assert_equal({'two' => true, 'four' => true}, tags5)
#   end
# 
#   def test_build_form
#     lang = languages(:english)
#     file = mock_template
# 
#     form = @controller.build_form(lang, hashify(), file)
#     assert_equal([], form)
# 
#     form = @controller.build_form(lang, hashify('name'), file)
#     assert_major_header('IMPORTANT STUFF', form.shift)
#     assert_minor_header('Main Objects:', form.shift)
#     assert_tag_field('name', form.shift)
#     assert(form.empty?)
# 
#     form = @controller.build_form(lang, hashify('index', 'index_help'), file)
#     assert_major_header('IMPORTANT STUFF', form.shift)
#     assert_minor_header('Actions:', form.shift)
#     assert_tag_field('index', form.shift)
#     assert_major_header('MAIN PAGES', form.shift)
#     assert_minor_header('observer/index', form.shift)
#     assert_tag_field('index_title', form.shift)
#     assert_comment('you don\'t see this every day', form.shift)
#     assert_tag_field('index_error', form.shift)
#     assert_tag_field('index_help', form.shift)
#     assert_tag_field('index_prefs', form.shift)
#     assert(form.empty?)
#   end
# 
#   def test_authorization
#     get(:edit_translations, :locale => 'en-US')
#     assert_flash_error
#     assert_response(:redirect)
# 
#     get(:edit_translations, :locale => 'el-GR')
#     assert_flash_error
#     assert_response(:redirect)
# 
#     login('mary')
#     get(:edit_translations, :locale => 'en-US')
#     assert_flash_error
#     assert_response(:redirect)
# 
#     get(:edit_translations, :locale => 'el-GR')
#     assert_no_flash
#     assert_response(:success)
# 
#     login('rolf')
#     get(:edit_translations, :locale => 'en-US')
#     assert_no_flash
#     assert_response(:success)
#   end

  
end
