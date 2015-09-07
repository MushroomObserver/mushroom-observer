/**
 * Created by ray on 9/7/2015.
 */

//=require box_resizer

jQuery(document).ready(function () {
function infiniteScroll () {
    var $document = jQuery(document);

    function getInitialPageNumber() {
        var pagePosInUrl = location.search.indexOf('page=');
        if (pagePosInUrl === -1)  return 1;

        var pagePortionUri = location.search.substring(pagePosInUrl + 5);
        return pagePortionUri.split('&')[0];
    }

    var currentPage = getInitialPageNumber();
    var nextPage = currentPage + 1;

    function getUrlToFetch() {
        if (location.search.indexOf('?') === -1)
            return location.href + '?page=' + nextPage;
        else {
            return location.href.replace('page=','') + '&page=' + nextPage;
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
            var nextUrl = getUrlToFetch();
            return Rx.Observable.just(nextUrl);
        })
        .distinctUntilChanged()
        .flatMapLatest(function () {
            return nextPageData;
        })
        .flatMapLatest(function (data) {
            return Rx.Observable.just(
                {
                    results: jQuery(jQuery(data).find('#results_block')),
                    pager: jQuery(jQuery(data).find('.pagination')[0])
                }
            );
        });


    var scrollSubscription = scrollObservable.subscribe(function (htmls){
            currentPage = nextPage;
            nextPage++;
            jQuery('#results_block').append(htmls.results.html());
            jQuery('.pagination').html(htmls.pager.html());


            nextPageData = getNextPageData(getUrlToFetch()); //preload next page
            setTimeout(box_resizer, 1000); //get page
        },
        function (e){
            console.log('error', e);
        },
        function (){
            console.log('done, should never be reached');
        });
}

    //init if we are on a scrollable page
    if (jQuery('#results_block').length > 0)
        infiniteScroll()


});