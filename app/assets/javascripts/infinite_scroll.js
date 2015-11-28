/**
 * Created by ray on 9/7/2015.
 */

//=require box_resizer

jQuery(document).ready(function () {
    function infiniteScroll() {
        var $document = jQuery(document);

        function getInitialPageNumber() {
            var pagePosInUrl = location.search.indexOf('page=');
            if (pagePosInUrl === -1)  return 1;

            var pagePortionUri = location.search.substring(pagePosInUrl + 5);
            var pageNumber = pagePortionUri.split('&')[0];
            return parseInt(pageNumber);
        }

        var currentPage = getInitialPageNumber();
        var nextPage = currentPage + 1;

        function getUrlToFetch() {
            var baseUri = "/ajax/index_rss_log";

            //no page parameter in current url
            if (location.search.indexOf('page') === -1) {
                //no question mark either, so add one
                if (location.search.indexOf('?') === -1)
                    return baseUri + '?page=' + nextPage;
                else
                //there is a question mark, so append the page paramter
                    return baseUri + location.search + '&page=' + nextPage;
            }
            //there is a page parameter in the current url
            else {
                var locSearch = location.search;
                var regex = new RegExp("page=[0-9]*");
                //so replace it with the new next page
                return baseUri + locSearch.replace(regex, 'page=' + nextPage);
            }
        }

        function getNextPageData(urlToFetch) {
            return jQuery.get(urlToFetch).promise();
        }

        var nextPageData = getNextPageData(getUrlToFetch());

        var scrollObservable = Rx.Observable.fromEvent($document, 'scroll')
            .debounce(150)
            .map(function () {
                return $document.scrollTop();
            })
            .filter(function (scrollPos) {
                return (jQuery('body').height() - window.innerHeight - scrollPos) < 300;
            })
            .flatMapLatest(function () {
                return Rx.Observable.just(getUrlToFetch());
            })
            .distinctUntilChanged()
            .flatMapLatest(function () {
                return nextPageData; //prewarmed promise
            })
            .flatMapLatest(function (data) {
                return Rx.Observable.just(
                    {
                        results: jQuery(jQuery(data).find('#results_block')),
                        pager: jQuery(jQuery(data).find('.pagination')[0]),
                        currentPage: nextPage
                    }
                );
            });


        var scrollSubscription = scrollObservable
            .subscribe(function (htmls) {
                setTimeout(box_resizer, 1000);
                currentPage = nextPage;
                nextPage++;
                jQuery('#results_block').append(htmls.results.html());
                jQuery('.pagination').html(htmls.pager.html());
                nextPageData = getNextPageData(getUrlToFetch()); //preload next page
                 //give it a second before trying to resize the boxes
            },
            function (e) {
                console.log('error', e);
            },
            function () {
                console.log('done, should never be reached');
            });
    }

    //init if we are on a scrollable page
    if (jQuery('#results_block').length > 0) {
        var $translatorsCredit  = jQuery('#translators_credit');

        if ($translatorsCredit.length > 0) {
            // move the translators credit to the top of the page if it is currently visible
            // otherwise it will not ever be reached
            $translatorsCredit.prependTo('.results');
        }
        infiniteScroll()
    }


});