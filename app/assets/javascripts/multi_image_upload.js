/**
 * Created by Raymond on 1/9/15.
 */

function MultiImageUploader (localized_text) {
    var defaults = {
        image_upload_error_text: "There was an error uploading the image. Continuing anyway.",
        uploading_text: "Uploading",
        image_too_big_text: "This image is too large. Images must be less than 10mb in file size.",
        creating_observation_text: "Creating Observation..."
    }

    checkLocalizedText();
    function checkLocalizedText() {
        if (localized_text == undefined) {
            localized_text = defaults;
        }
        //Make sure we have all of the defaults initialized;
        localized_text.image_too_big_text = !localized_text.image_too_big_text ? defaults.image_too_big_text : localized_text.image_too_big_text;
        localized_text.uploading_text = !localized_text.uploading_text ? defaults.uploading_text : localized_text.uploading_text;
        localized_text.image_upload_error_text = !localized_text.image_upload_error_text ? defaults.image_upload_error_text : localized_text.image_upload_error_text;
        localized_text.creating_observation_text = !localized_text.creating_observation_text ? defaults.creating_observation_text : localized_text.creating_observation_text;
    }

    return {
        options: function(opts){  //update or get options.
            if (opts == undefined) {
                return localized_text;
            }
            else {
                localized_text = opts
                checkLocalizedText();
                return localized_text;
            }
        },
        init: function () {
            var _$addedImagesContainer, _$imageMessages, _$update_img_dates_btn, _$update_obs_date_btn, _$inconsistent_dates,
                _$form, _$select_files_button, _fileDictionary, _fileStore, _getTemplateUri, _uploadImageUri;
            _getTemplateUri = "/ajax/get_multi_image_template";
            _uploadImageUri = "/ajax/create_image_object";
            _$form = jQuery(document.forms.namedItem("create_observation_form"));
            _$select_files_button = jQuery('#multiple_images_button')
            _$imageMessages = jQuery("#image_messages"); //contains messages and warnings about selected files
            _$inconsistent_dates = jQuery("#inconsistent_date_message_container");
            _$update_img_dates_btn = jQuery("#inconsistent_date_use_obs_date_btn"); //buttons to update observation date or image dates due EXIF inconsistency
            _$update_obs_date_btn = jQuery("#inconsistent_date_update_obs_date_btn");
            _$addedImagesContainer = jQuery("#added_images_container"); //container to insert images into
            _fileDictionary = {}; //we can use the file size to avoid a recursive loop when checking for the existence of a file. This keeps solution to O(n);
            _fileStore = [];

            //the class for an added image.
            var FileStoreItem = function (file, uuid) {
                this.file = file;
                this.uuid = uuid;
                this.dom_element = null;
                this.exif_data = null;
                this.getTemplateHtml();
            };

            FileStoreItem.prototype.getTemplateHtml = function () {  //does an ajax request to get the template, then formats it, the format function adds to HTML.
                var _item = this;

                jQuery.get(_getTemplateUri, {
                    img_number: _item.uuid
                }, function (data) {  //on success
                    _item.createTemplate(data) //the data returned is the raw HTML template
                });
            }

            FileStoreItem.prototype.createTemplate = function (html_string) {
                var _this = this;

                html_string = html_string.replace('{{img_file_name}}', _this.file.name)
                    .replace('{{img_file_size}}', Math.floor((_this.file.size / 1024)) + "kb");
                _this.dom_element = $(html_string);  //Create the DOM element and add it to FileStoreItem;
                if (_this.file.size > 10000000)
                    _this.dom_element.find('.warn-text').text(localized_text.image_too_big_text);
                _$addedImagesContainer.append(_this.dom_element); //add it to the page

                _this.dom_element.find('a[data-file-uuid]').click(function () {  // bind the destroy function
                    _this.destroy();
                });

                _this.getExifData();  //extract the EXIF data (async) and then load it
                _this.loadImageAsFileUrl(); //load image as base64 async
            };

            FileStoreItem.prototype.loadImageAsFileUrl = function () {
                var _this = this;
                var fileReader = new FileReader();
                fileReader.onload = function (fileLoadedEvent) {
                    var $img = _this.dom_element.find('.img_responsive').first(); //find the actual image element
                    $img.attr('src', fileLoadedEvent.target.result); //get the image element in the container and set the src to base64 img url
                }
                fileReader.readAsDataURL(_this.file);
            }

            FileStoreItem.prototype.getExifData = function () {  //extracts the exif data async;
                var _fsItem = this;
                EXIF.getData(_fsItem.file, function () {
                    _fsItem.exif_data = this.exifdata;
                    _fsItem.applyExifData();  //apply the data to the DOM
                })
            };

            FileStoreItem.prototype.applyExifData = function () {  //applys exif data to the DOM element, DOM element must already be attached
                var _exif_date_taken, _observation_date;
                _observation_date = getObservationDate(); //returns the user set observation date;

                if (this.dom_element == null) {
                    console.warn("Error: Dom element for this file has not been created, so cannot update it with exif data!");
                    return;
                }
                //do the date logic
                _exif_date_taken = this.exif_data.DateTimeOriginal;

                if (_exif_date_taken) {
                    //we found the date taken, let's parse it down.
                    var _date_taken_array = _exif_date_taken.substring(' ', 10).split(':'), //returns an array of [YYYY,MM,DD]
                        _exif_day = parseInt(_date_taken_array[2]), //we have to parse these to an int to get rid of leading zeros since our forms don't use that format
                        _exif_month = parseInt(_date_taken_array[1]),
                        _exif_year = parseInt(_date_taken_array[0]);


                    //Check if EXIF data matches the observation date, warn user if it does not.
                    if (_observation_date.month != _exif_month || _observation_date.day != _exif_day || _observation_date.year != _exif_year) {
                        _$imageMessages.show();
                        _$inconsistent_dates.show();

                        //bind the handlers to the buttons they click on. Important: unbind first so we don't fire for X number of images.
                        //use the jquery event namespace to accomplish this task
                        _$update_img_dates_btn.unbind('click.updateImageDates').bind('click.updateImageDates', function () {
                            _$imageMessages.hide();
                            _$inconsistent_dates.hide();
                            _fileStore.forEach(function (fileStoreItem) {
                                _observation_date = getObservationDate(); //refresh it in case the user updates it.
                                fileStoreItem.setImageDate(_observation_date.day, _observation_date.month, _observation_date.year)
                            });
                        });

                        _$update_obs_date_btn.unbind('click.updateObsDate').bind('click.updateObsDate', function () {
                            alert('Change the observation date');
                            _$imageMessages.hide();
                            _$inconsistent_dates.hide();
                            setObservationDate(_exif_day, _exif_month, _exif_year);
                        });
                    }
                    //set the select image dates.
                    this.setImageDate(_exif_day, _exif_month, _exif_year)
                }
                else {  //no date was found in EXIF data
                    this.setImageDate(_observation_date.day, _observation_date.month, _observation_date.year); //Use observation date
                }
            };

            FileStoreItem.prototype.setImageDate = function (day, month, year) {
                jQuery(this.dom_element.find('select')[0]).val(day);
                jQuery(this.dom_element.find('select')[1]).val(month);
                jQuery(this.dom_element.find('select')[2]).val(year);
            }

            FileStoreItem.prototype.getUserEnteredInfo = function () {
                return {
                    day: jQuery(this.dom_element.find('select')[0]).val(),
                    month: jQuery(this.dom_element.find('select')[1]).val(),
                    year: jQuery(this.dom_element.find('select')[2]).val(),
                    license: jQuery(this.dom_element.find('select')[3]).val(),
                    notes: jQuery(this.dom_element.find('input')[0]).val(),
                    copyright_holder: jQuery(this.dom_element.find('input')[1]).val()
                };
            }

            FileStoreItem.prototype.buildFormData = function () {
                var _this = this,
                    _info = _this.getUserEnteredInfo(),
                    _fd = new FormData();

                if (_this.file.size > 10000000)
                    return null;

                _fd.append("image[upload]", _this.file, _this.file.name);
                _fd.append("image[when][3i]", _info.day);
                _fd.append("image[when][2i]", _info.month);
                _fd.append("image[when][1i]", _info.year);
                _fd.append("image[notes]", _info.notes);
                _fd.append("image[copyright_holder]", _info.copyright_holder);
                _fd.append("image[license]", _info.license);
                return _fd;
            }

            FileStoreItem.prototype.incrementProgressBar = function (decimalPercentage) {
                var _this = this,
                    _$progress_bar = _this.dom_element.find(".added_image_name_container"),
                    _percent_string = decimalPercentage ? parseInt(decimalPercentage * 100).toString() + "%" : "0%"; //if we don't have percentage,  just set it to 0 percent
                _$progress_bar.css('background', 'linear-gradient(to right, #51B973 {{percentage}}, #F6F6F6 0%'.replace("{{percentage}}", _percent_string));

                if (_this.isUploading == true)
                    return;           //don't set multiple timeouts for doDots!


                _this.isUploading = true;
                doDots(1);

                var _dots = [".", "..", "..."];

                function doDots(i) {
                    setTimeout(function () {
                        if (i < 900) {
                            _$progress_bar.html('<strong>' + localized_text.uploading_text + _dots[i % 3] + '</strong>'); //show the user we are uploading the image by showing some dots for a while.
                            doDots(++i);
                        }
                    }, 333)
                }
            }

            FileStoreItem.prototype.destroy = function () {
                this.dom_element.remove();  //remove element from the dom;
                delete _fileDictionary[this.file.size]; //remove the file from the dictionary
                var idx = _fileStore.indexOf(this); //removes the file from the array
                if (idx > -1)
                    _fileStore.splice(idx, 1);  //removes the file from the array
            }


            //Upload Helpers

            /*Event Listeners that are not within an individual image upload template dom element are
             1. Detect when files are selected
             2. Detect form submit
             */

            //Detect when files are added from browser
            _$select_files_button.change(function () {
                var files = $(this)[0].files; //Get the files from the browser
                for (var i = 0; i < files.length; i++) { //loop through the attached files, check to make sure we aren't adding duplicates
                    if (_fileDictionary[files[i].size] != undefined) {  //stop adding the file, an exact size is already attached  TODO:What are the odds of this?
                        continue;  //stop here since a file with this size has been added.
                    }

                    var uuid = generate_uuid();
                    var _fileStoreItem = new FileStoreItem(files[i], uuid); //uuid is used as the index for the ruby form template.
                    _fileDictionary[files[i].size] = _fileStoreItem;//add an item to the dictionary with the file size as they key
                    _fileStore.push(_fileStoreItem)
                }
            });

            //Detect when a user submits observation; includes upload logic
            var _uploadsCompleted = false;  //is set to true after all the images are uploaded!
            _$form.submit(function (e) {
                var _imagesRemaining, _imageUploadNumber, _$good_images, _$submit_buttons;

                _imagesRemaining = _fileStore.length - 1;  //0 based index please
                _imageUploadNumber = 1; //use this to display the text to the user of what image we are uploading.
                _$good_images = jQuery('#good_images');
                _$submit_buttons = _$form.find('input[type="submit"]');

                _$submit_buttons.prop('disabled', 'true'); //disable submit buttons during upload process.
                jQuery("[data-file-uuid]").hide() //hide all the remove links!

                if (_uploadsCompleted || _imagesRemaining == -1) { //if the images were all uploaded or no images to uploads, submit the form
                    return true;
                }

                upload(_fileStore[_imagesRemaining]); //kick off the upload starting with the last in the list (could be first if we wanted, but less code this way)

                function upload(fileStoreItemToUpload) {   //call recursively because it is async
                    _$submit_buttons.val(localized_text.uploading_text + _imageUploadNumber + '...');
                    fileStoreItemToUpload.incrementProgressBar();
                    fileStoreItemToUpload.incrementProgressBar();
                    var xhrReq = new XMLHttpRequest();
                    //event listeners;
                    xhrReq.onload = function (event) {
                        if (xhrReq.status == 200 || xhrReq.status == 201) {
                            var image = JSON.parse(xhrReq.response).image;  //Rails returning this as a string?
                            var _good_images = _$good_images.val();
                            if (_good_images.length == 0) //do this so the split function actually works
                                _$good_images.val(image.id);
                            else {
                                var _good_images_array = _good_images.split(' ');
                                _good_images_array.push(image.id);
                                var _imgsToAddTo = _good_images_array.join(' ');
                                _$good_images.val(_imgsToAddTo) //add to the good images;
                            }
                            clearTimeout(fileStoreItemToUpload.uploadTextAnimationTimeout); //remove the animation timeout set by the increment progress bar function
                            fileStoreItemToUpload.dom_element.hide('slow');
                            next();  //recursive to upload
                        } else {
                            alert(localized_text.image_upload_error_text);
                            fileStoreItemToUpload.dom_element.hide('slow');
                            next();
                        }
                    };
                    xhrReq.onprogress = function (event) {
                        if (event.lengthComputable) {
                            var percentComplete = event.loaded / event.total;
                            fileStoreItemToUpload.incrementProgressBar(percentComplete);
                        } else {
                        }
                    }
                    //Note: You need to add the event listeners before calling open() on the request.  Otherwise the progress events will not fire.
                    xhrReq.open("POST", _uploadImageUri, true);
                    var _fd = fileStoreItemToUpload.buildFormData();

                    // Null check below Below will SKIP uploading the image.  This let's us skip uploading images that are too large by checking size in the
                    // build form data method and returning null if it is too big.
                    if (_fd != null)
                        xhrReq.send(_fd);
                    else {
                        next();
                    }
                }

                function next() { //calls upload recursively
                    _imagesRemaining--;  //decrement items remaining
                    _imageUploadNumber++; //increase image upload number
                    if (_imagesRemaining == -1) {  //no more images to upload
                        _uploadsCompleted = true;
                        _fileStore.forEach(function (item) {
                            item.destroy();  //remove all the images as they were uploaded!
                        });
                        _$submit_buttons.val(localized_text.creating_observation_text);
                        _$form.submit();
                    }
                    else {  //keep uploading
                        upload(_fileStore[_imagesRemaining]) //recursively call
                    }
                }

                return false;
            });


            //Helpers
            function getObservationDate() {
                return {
                    day: $('#observation_when_3i').val(),
                    month: $('#observation_when_2i').val(),
                    year: $('#observation_when_1i').val()
                }
            }

            function setObservationDate(day, month, year) {
                $('#observation_when_3i').val(day);
                $('#observation_when_2i').val(month);
                $('#observation_when_1i').val(year);
                return getObservationDate();
            }

            function generate_uuid() {
                return 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
                    var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
                    return v.toString(16);
                });
            }
        }
    }
}