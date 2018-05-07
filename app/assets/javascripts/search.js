var umnLibArticleSearch = {
  citation: {
    makeCite: function(data) {
      var e = umnLibArticleSearch.escape,
          elem = $('<a>').attr('href', this.url(data.doi));
      elem.append($('<span class="cite-component cite-authors">').append(this.authorsList(data.article.authors)))
        .append($('<span class="cite-component cite-title"/>').text(data.article.title))
        .append($('<span class="cite-component cite-container"/>').text(data['full-title']))
        .append(this.pubInfo(data))
        .append($('<span class="cite-component cite-doi"/>').text(data.doi));

      // Output as a plain HTML <div>
      return elem.wrap('<div></div>').parent()[0].outerHTML;
    },
    url: function(doi) {
      return 'https://ezproxy.lib.umn.edu/login?qurl=' + encodeURIComponent('https://dx.doi.org/' + doi);
    },
    authors: function(authors) {
      var authorsArr = authors.map(function(a) {
        return a.name.surname;
      });
      if (authorsArr.length > 5) {
        authorsArr = authorsArr.slice(0, 4);
        authorsArr.push('et al.');
      }
      return authorsArr;
    },
    authorsList: function(authors) {
      var l = $('<ul/>');
      this.authors(authors).forEach(function(a) {
        l.append($('<li/>').text(a));
      });
      return l;
    },
    pubInfo: function(data) {
      var pubcontainer = $('<span class="cite-component"/>'),
          pub = $('<span class="cite-pubinfo"/>');
      if (data.volume != "") pub.append($('<span class="cite-volume"/>').text(data.volume));
      if (data.issue != "") pub.append($('<span class="cite-issue"/>').text(data.issue));
      if (data['publication-date']) pub.append($('<span class="cite-date"/>').text((new Date(data['publication-date'])).getFullYear()));
      pubcontainer.append(pub);
      if (data.article.pagination != "") pubcontainer.append($('<span class="cite-pagination"/>').text(data.article.pagination));
      return pubcontainer;
    }
  },
  escape: function(str) {
    return $('<span/>').text(str).html();
  }
};
var Bhound = Bloodhound.noConflict();
var bh = new Bhound({
  initialize: true,
  queryTokenizer: Bhound.tokenizers.whitespace,
  datumTokenizer: Bhound.tokenizers.whitespace,
  sufficient: 1,
  remote: {
    url: '/search?q=%QUERY',
    wildcard: '%QUERY',
    transform: function(response) {
      return Array.isArray(response.data) ? response.data : [response.data];
    },
    identify: function(datum) {
      return datum.id;
    }
  },
  rateLimitBy: 'throttle',
  rateLimitWait: 100
});


$(document).ready(function() {
  $('#citesearch').typeahead({
    hint: false,
    highlight: true,
    minLength: 15
  },
  {
    source: bh,
    limit: Infinity,
    display: function(value) {
      //return 'DOI: ' + value.doi + ' ' + value.article.title;
      return '';
    },
    templates: {
      suggestion: function(suggestion) {
        return umnLibArticleSearch.citation.makeCite(suggestion.attributes);
      },
    }
  });
  $('#citesearch').bind('typeahead:select', function(evt, suggestion) {
    evt.preventDefault();
    window.location = umnLibArticleSearch.citation.url(suggestion.attributes.doi);
  });
});
