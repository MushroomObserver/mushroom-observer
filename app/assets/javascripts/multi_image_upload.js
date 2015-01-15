function MultiImageUploader(localized_text) {
    var defaults = {
        image_upload_error_text: "There was an error uploading the image. Continuing anyway.",
        uploading_text: "Uploading",
        image_too_big_text: "This image is too large. Images must be less than 10mb in file size.",
        creating_observation_text: "Creating Observation...",
        months: "January, February, March, April, May, June, July, August, September,October,November, December"
    };

    if (localized_text == undefined) {
        localized_text = defaults;
    } else {
        localized_text.image_too_big_text = !localized_text.image_too_big_text ? defaults.image_too_big_text : localized_text.image_too_big_text;
        localized_text.uploading_text = !localized_text.uploading_text ? defaults.uploading_text : localized_text.uploading_text;
        localized_text.image_upload_error_text = !localized_text.image_upload_error_text ? defaults.image_upload_error_text : localized_text.image_upload_error_text;
        localized_text.creating_observation_text = !localized_text.creating_observation_text ? defaults.creating_observation_text : localized_text.creating_observation_text;
        localized_text.months = !localized_text.months ? defaults.months : localized_text.months;
    }

    //Internal Variable Definitions;
    var  fileStore = new FileStore(),
        _getTemplateUri = "/ajax/get_multi_image_template",
        _uploadImageUri = "/ajax/create_image_object",
        _$addedImagesContainer = jQuery("#added_images_container"),//container to insert images
        $form = jQuery(document.forms.namedItem("create_observation_form")),
        $submitButtons= $form.find('input[type="submit"]'),
        $goodImages = jQuery('#good_images'),
        $removeLinks = jQuery("[data-file-uuid]"),
        $selectFilesButton = jQuery('#multiple_images_button'),
        $obsDay = jQuery('#observation_when_3i'),
        $obsMonth = jQuery('#observation_when_2i'),
        $obsYear = jQuery('#observation_when_1i'),
        $imgRadioContainer = jQuery('#image_date_radio_container'),
        $obsRadioContainer = jQuery('#observation_date_radio_container'),
        $fixDateSubmit = jQuery('#fix_date_submit'),
        $imgMessages = jQuery(".image_messages"),
        dateUpdater = new DateUpdater();

    /*********************/
    /* Class Definitions */
    /*********************/

    //Simple Date Class
    function SimpleDate(day, month, year) {
        this.day = parseInt(day);
        this.month = parseInt(month);
        this.year = parseInt(year);
    };

    SimpleDate.prototype.areEqual = function (simpleDate) { //returns true if same
        var _this = this;
        return _this.month == simpleDate.month && _this.day == simpleDate.day && _this.year == simpleDate.year;
    };

    SimpleDate.prototype.asDateString = function() {
        var _months = localized_text.months.split(' ');
        return this.day + "-" + _months[this.month-1] + "-" + this.year;
    }

    /*DateUpdater -- deals generally with
      image and observation dates and their updating.
      Through the message box*/

    function DateUpdater() {
        this.observationDateAdded = false;
        }


    DateUpdater.prototype.areDatesInconsistent = function() {  //will check differences between the image dates and observation dates
        var _this = this,
            _obsDate = _this.observationDate(),
            _distinctDates = fileStore.getDistinctImageDates();

        for(var i = 0; i < _distinctDates.length; i++) {
            if (!_distinctDates[i].areEqual(_obsDate))
                return true;
        }

        return false;
    };

    //builds and refreshes the fix date box;
    DateUpdater.prototype.refreshBox = function () {
        var _this = this,
            _distinctImgDates = fileStore.getDistinctImageDates();

        $imgRadioContainer.html('');
        $obsRadioContainer.html('');

        _this.makeObservationDateRadio(_this.observationDate());

        _distinctImgDates.forEach(function (simpleDate){
            _this.makeImageDateRadio(simpleDate);
        });

        if (_this.areDatesInconsistent())
            $imgMessages.show('slow');

        //TODO: move
        $fixDateSubmit.unbind('click.fixDateBind').bind('click.fixDateBind', function () {
            var _selectedItemData = jQuery('input[name=fix_date]:checked').data();
            if (_selectedItemData && _selectedItemData.date) {
                _this.fixDates(_selectedItemData.date);
            }
        });
    };

    DateUpdater.prototype.fixDates = function (simpleDate) {
        var _this = this;
        fileStore.updateImageDates(simpleDate);
        _this.observationDate(simpleDate);
        $imgMessages.hide('slow');
    }


    DateUpdater.prototype.makeImageDateRadio = function (simpleDate) {
        var _this = this;

        var html = "<div><label><input type='radio' data-target='observation' data-date='{{date}}' name='fix_date'/>{{dateStr}}</label></div>"
        html = html.replace('{{date}}', JSON.stringify(simpleDate));
        html = html.replace('{{dateStr}}', simpleDate.asDateString());
        $imgRadioContainer.append(jQuery(html));
    };



    DateUpdater.prototype.makeObservationDateRadio = function (simpleDate) {
        var _this = this;

        var html = "<div><label><input type='radio' data-target='image' data-date='{{date}}' name='fix_date'/><span>{{dateStr}}</span></label></div>"
        html = html.replace('{{date}}', JSON.stringify(simpleDate));
        html = html.replace('{{dateStr}}',  simpleDate.asDateString());

        var $obsRadio = jQuery(html);
        $obsYear.change(function (){_this.updateObservationDateRadio($obsRadio)});
        $obsMonth.change(function (){_this.updateObservationDateRadio($obsRadio)});
        $obsDay.change(function (){_this.updateObservationDateRadio($obsRadio)});
        $obsRadioContainer.append($obsRadio);
    };


    DateUpdater.prototype.updateObservationDateRadio = function ($obsRadio) {
        var _this = this;
        var _currentObsDate = _this.observationDate();
        $obsRadio.find('input').data('date', _currentObsDate);
        $obsRadio.find('span').text(_currentObsDate.asDateString());
        if (_this.areDatesInconsistent())
            $imgMessages.show('slow');
    };

    DateUpdater.prototype.observationDate = function (simpleDate) { //undefined gets current date, simpledate object updates date

        if (simpleDate && simpleDate.day && simpleDate.month && simpleDate.year) {
            $obsDay.val(simpleDate.day);
            $obsMonth.val(simpleDate.month);
            $obsYear.val(simpleDate.year);
        }
        return new SimpleDate($obsDay.val(), $obsMonth.val(), $obsYear.val());
    };


    /*File Store contains all the file items*/
    function FileStore() {
        var _this = this;
        _this.fileStoreItems = [];
        _this.fileDictionary = {};
        _this.areAllProcessed = function () {
            for(var i = 0; i < _this.fileStoreItems.length; i++) {
                if (!_this.fileStoreItems[i].processed)
                    return false;
            }
            return true;
        }

    }

    FileStore.prototype.addFiles = function(files){
        var _this = this;
        for (var i = 0; i < files.length; i++) { //loop through the attached files, check to make sure we aren't adding duplicates
            if (_this.fileDictionary[files[i].size] != undefined) {  //stop adding the file, an exact size is already attached  TODO:What are the odds of this?
                continue;  //stop here since a file with this size has been added.
            }

            var _fileStoreItem = new FileStoreItem(files[i], generateUUID()); //uuid is used as the index for the ruby form template.
            _this.fileDictionary[files[i].size] = _fileStoreItem;//add an item to the dictionary with the file size as they key
            _this.fileStoreItems.push(_fileStoreItem)
        }

        //check status of when all the selected files have processed.
        checkStatus();
        function checkStatus() {
            setTimeout(function() {
                if (!_this.areAllProcessed()) {
                    checkStatus();
                }
                else {
                    dateUpdater.refreshBox();
                }
            },30)
        }
    };

    FileStore.prototype.updateImageDates = function (simpleDate) {
        var _this = this;
        _this.fileStoreItems.forEach(function (fileStoreItem) {
            fileStoreItem.imageDate(simpleDate);
        });
    };


    FileStore.prototype.getDistinctImageDates = function () {
        var _this = this;
        var _testAgainst = "";
        var _distinct = [];

        for (var i = 0; i < _this.fileStoreItems.length; i++) {
            var _ds = _this.fileStoreItems[i].imageDate().asDateString();
            if (_testAgainst.indexOf(_ds) != -1)
                continue;
            _testAgainst =+ _ds;
            _distinct.push(_this.fileStoreItems[i].imageDate())
        }

        return _distinct;
    };

    FileStore.prototype.destroyAll = function () {
        this.fileStoreItems.forEach(function (item) {
            item.destroy();  //remove all the images as they were uploaded!
        });
    };

    FileStore.prototype.uploadAll = function (){
        /*  var _imagesRemaining = fileStore.length - 1,  //0 based index please
         _imageUploadNumber = 1; //use this to display the text to the user of what image we are uploading.

         $submitButtons.prop('disabled', 'true'); //disable submit and remove image buttons during upload process.
         $removeLinks.hide();

         if (_uploadsCompleted || _imagesRemaining == -1)  //if the images were all uploaded or no images to uploads, submit the form
         return true;

         //kick off the upload starting with the last in the list (could be first if we wanted, but less code this way)
         upload(fileStore.fileStoreItems[_imagesRemaining]);

         function upload(fileStoreItemToUpload) {   //call recursively because it is async
         $submitButtons.val(localized_text.uploading_text + " " + _imageUploadNumber + '...');
         fileStoreItemToUpload.incrementProgressBar();
         var xhrReq = new XMLHttpRequest();

         xhrReq.onload = function () { //attach event listener
         if (xhrReq.status == 200) {
         var image = JSON.parse(xhrReq.response).image,  //Rails returning this as a string???
         goodImageVals = $goodImages.val();
         $goodImages.val(goodImageVals.length == 0 ? image.id : goodImageVals + ' ' + image.id); //add to the good images;
         } else {
         alert(localized_text.image_upload_error_text);
         }
         fileStoreItemToUpload.dom_element.hide('slow');
         next();  //recursive to upload
         };

         xhrReq.onprogress = function (event) {
         if (event.lengthComputable) {
         var percentComplete = event.loaded / event.total;
         fileStoreItemToUpload.incrementProgressBar(percentComplete);
         }
         };

         //Note: You need to add the event listeners before calling open() on the request.
         xhrReq.open("POST", _uploadImageUri, true);
         //Send the form
         var _fd = fileStoreItemToUpload.asFormData();
         _fd != null ? xhrReq.send(_fd) : next();

         }

         function next() { //calls upload recursively
         _imagesRemaining--;  //decrement items remaining
         _imageUploadNumber++; //increase image upload number
         if (_imagesRemaining == -1) {  //no more images to upload
         _uploadsCompleted = true;
         fileStore.destroyAll();
         $submitButtons.val(localized_text.creating_observation_text);
         $form.submit();
         }
         else {  //keep uploading
         upload(fileStore.fileStoreItems[_imagesRemaining]) //recursively call
         }
         }
         return false;  //keeps form from submiting*/
    }


    //File Store Item Class


    function FileStoreItem(file, uuid) {
        this.file = file;
        this.uuid = uuid;
        this.dom_element = null;
        this.exif_data = null;
        this.processed = false;  //we use this to check the async status of files
        this.getTemplateHtml();
    }

    FileStoreItem.prototype.getTemplateHtml = function () {  //does an ajax request to get the template, then formats it, the format function adds to HTML.
        var _this = this;
        jQuery.get(_getTemplateUri, {
            img_number: _this.uuid
        }, function (data) {  //on success
            _this.createTemplate(data) //the data returned is the raw HTML template
        });
    };

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
        };
        fileReader.readAsDataURL(_this.file);
    };

    FileStoreItem.prototype.getExifData = function () {  //extracts the exif data async;
        var _fsItem = this;
        EXIF.getData(_fsItem.file, function () {
            _fsItem.exif_data = this.exifdata;
            _fsItem.applyExifData();  //apply the data to the DOM
        })
    };

    FileStoreItem.prototype.applyExifData = function () {  //applys exif data to the DOM element, DOM element must already be attached
        var _exif_date_taken;
        var _this = this;

        if (this.dom_element == null) {
            console.warn("Error: Dom element for this file has not been created, so cannot update it with exif data!");
            return;
        }

        _exif_date_taken = _this.exif_data.DateTimeOriginal;
        if (_exif_date_taken) {
            //we found the date taken, let's parse it down.
            var _date_taken_array = _exif_date_taken.substring(' ', 10).split(':'), //returns an array of [YYYY,MM,DD]
                _exifSimpleDate = new SimpleDate(_date_taken_array[2], _date_taken_array[1], _date_taken_array[0]);
                _this.imageDate(_exifSimpleDate);
            }
        else {  //no date was found in EXIF data
            _this.imageDate(dateUpdater.observationDate()); //Use observation date
        }
        _this.processed = true;
    };

    FileStoreItem.prototype.imageDate = function (simpleDate) {
        var _this = this,
        _$day = jQuery(_this.dom_element.find('select')[0]),
        _$month = jQuery(_this.dom_element.find('select')[1]),
        _$year = jQuery(_this.dom_element.find('select')[2]);
        if (simpleDate) {
            _$day.val(simpleDate.day);
            _$month.val(simpleDate.month);
            _$year.val(simpleDate.year);
        }
        return new SimpleDate(_$day.val(), _$month.val(), _$year.val());
    };

    FileStoreItem.prototype.getUserEnteredInfo = function () {
        return {
            day: jQuery(this.dom_element.find('select')[0]).val(),
            month: jQuery(this.dom_element.find('select')[1]).val(),
            year: jQuery(this.dom_element.find('select')[2]).val(),
            license: jQuery(this.dom_element.find('select')[3]).val(),
            notes: jQuery(this.dom_element.find('input')[0]).val(),
            copyright_holder: jQuery(this.dom_element.find('input')[1]).val()
        };
    };

    FileStoreItem.prototype.asFormData = function () {
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
    };

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
                    _$progress_bar.html('<div class="col-xs-12"><strong>' + localized_text.uploading_text + _dots[i % 3] + '</strong></div>'); //show the user we are uploading the image by showing some dots for a while.
                    doDots(++i);
                }
            }, 333)
        }
    };

    FileStoreItem.prototype.destroy = function () {
        this.dom_element.remove();  //remove element from the dom;
        delete fileStore.fileDictionary[this.file.size]; //remove the file from the dictionary
        var idx = fileStore.fileStoreItems.indexOf(this); //removes the file from the array
        if (idx > -1)
            fileStore.fileStoreItems.splice(idx, 1);  //removes the file from the array
    };

    //Helpers

    function generateUUID() {
        return 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
            var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    function init() { //initialize the uploader!
        $submitButtons.prop('disabled', false);//make sure submit buttons are enabled when the dom is loaded!

        //Detect when files are added from browser
        $selectFilesButton.change(function () {
            var files = $(this)[0].files; //Get the files from the browser
            fileStore.addFiles(files);
        });

        //Detect when a user submits observation; includes upload logic
        $form.submit(function () {});
    }

    return {
        init: init
    }

}