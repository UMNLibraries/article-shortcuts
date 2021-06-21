require 'test_helper'
require 'webmock/minitest'

class SearchControllerTest < ActionDispatch::IntegrationTest
  def setup
    stub_request(:post, 'http://localhost:9200/article/_search')
      .with(
        body: /introducing generic strings/i
      )
     .to_return(
        status: 200,
        # Rails will treat as a string and not decode json without this
        headers: {
          'content-type': 'application/json'
        },
        body: {
          hits: {
            hits: [
              {
                _index: 'article',
                _type: 'artice',
                _id: '10.9999/journal.generic.string',
                _score: 75,
                _source: {
                  doi: '10.9999/journal.generic.string',
                  url: 'http://example.com/doi/10.9999/journal.generic.string',
                  volume: 99,
                  issue: 2,
                  full_title: 'Journal of Generic Strings',
                  abbrev_title: 'J. Gen Str',
                  article: {
                    title: 'Introducing generic strings: a study of string concatenation',
                    pagination: '85-96',
                    authors: []
                  }
                }

              }
            ]
          }
        }.to_json
      )

    # Multiple DOIs example
    stub_request(:post, 'http://localhost:9200/article/_search')
      .with(
        # ES query will send multiple DOIs as an array of ids
        body: '{"query":{"ids":{"values":["10.9999/JOURNAL.GENERIC.STRING/54321","10.9999/JOURNAL.INTEGER.STUDIES/12345"]}}}'
      )
     .to_return(
        status: 200,
        # Rails will treat as a string and not decode json without this
        headers: {
          'content-type': 'application/json'
        },
        body: {
          hits: {
            hits: [
              {
                _index: 'article',
                _type: 'artice',
                _id: '10.9999/journal.generic.string/54321',
                _score: 75,
                _source: {
                  doi: '10.9999/journal.generic.string/54321',
                  url: 'http://example.com/doi/10.9999/journal.generic.string/54321',
                  volume: 99,
                  issue: 2,
                  full_title: 'Journal of Generic Strings',
                  abbrev_title: 'J. Gen Str',
                  article: {
                    title: 'A study of string array indexing',
                    pagination: '97-100',
                    authors: []
                  }
                }

              },
              {
                _index: 'article',
                _type: 'artice',
                _id: '10.9999/journal.integer.studies/12345',
                _score: 75,
                _source: {
                  doi: '10.9999/journal.intege.studies/12345',
                  url: 'http://example.com/doi/10.9999/journal.intege.studies/12345',
                  volume: 241,
                  issue: 3,
                  full_title: 'Journal of Integer Studies',
                  abbrev_title: 'J. Ints',
                  article: {
                    title: 'Integers: how high can they go??',
                    pagination: '97-100',
                    authors: [
                      'Lovelace, A',
                      'Babbage, C'
                    ]
                  }
                }

              }
            ]
          }
        }.to_json
      )

      # Single citation
      stub_request(:post, 'http://localhost:9200/article/_search')
        .with(
          body: '{"from":0,"size":5,"query":{"bool":{"must":{"match":{"article.title":{"query":"Intraoperative continuous monitoring of evoked facial nerve electromyograms in acoustic neuroma surgery","operator":"and"}}},"minimum_should_match":0,"should":{"nested":{"path":"article.authors","query":{"match":{"article.authors.name.surname":{"query":"Amano M. Kohno M. Nagata O. Taniguchi M. Sora S. Sato H."}}}}}}}}'
        )
        .to_return(
          status: 200,
          headers: {
            'content-type': 'application/json'
          },
          body: {
            hits: {
              hits: [
                {
                  _index: 'article',
                  _type: 'article',
                  _id: '10.1007/s00701-010-0937-6',
                  _score: 60,
                  _source: {
                    doi: '10.1007/s00701-010-0937-6',
                    url: 'https://doi.org/10.1007/s00701-010-0937-6',
                    volume: 153,
                    issue: 5,
                    full_title: 'Acta Neurochirurgica',
                    abbrev_title: '',
                    article: {
                      title: 'Intraoperative continuous monitoring of evoked facial nerve electromyograms in acoustic neuroma surgery.',
                      pagination: '1059-1067',
                      authors: [
                        'Amano, M.',
                        'Kohno, M.',
                        'Nagata, O.',
                        'Taniguchi, M.',
                        'Sora, S.',
                        'Sato, H.'
                      ]
                    }

                  }
                }
              ]
            }
          }.to_json
        )
  end

  def test_single_string_search
    get search_url params: { q: 'Introducing generic strings a study of string concatenation' }
    assert_response 200
    assert_equal 'application/json', @response.media_type

    js = JSON.parse @response.body
    assert_equal 1, js['data'].count, 'One result object should be returned'
    assert_equal '10.9999/JOURNAL.GENERIC.STRING', js['data'][0]['id'], 'DOI should be upcased into the id property'

    # ActiveModel::Serialization JSON::API serialization is what applies the attributes
    assert_equal '85-96', js['data'][0]['attributes']['article']['pagination'], 'Pagination should be among article properties'
  end

  def test_multi_doi_search
    begin
      get search_url params: {q: '10.9999/journal.generic.string/54321 10.9999/journal.integer.studies/12345'}
    rescue WebMock::NetConnectNotAllowedError
      # If WebMock errors that no stub has been defined, maybe there is an error in serializing these to a query for ids.
      # Maybe I'll figure out how to write a test for that in this context.
      # For now if webmock errors this can be assumed to be a fault in the code!
      assert true == false, 'There is an error SearchController#es_by_dois if we got here, multiple DOIs should be serialized into ids: values[]'
    end


    assert_response 200
    assert_equal 'application/json', @response.media_type

    js = JSON.parse @response.body
    assert_equal 2, js['data'].count, 'Two result objects should be returned'
    assert_equal 'A study of string array indexing', js['data'][0]['attributes']['article']['title']
    assert_equal 'Lovelace, A', js['data'][1]['attributes']['article']['authors'].first
  end

  def test_single_citation_search
    begin
      get search_url params: {q: 'Amano, M., Kohno, M., Nagata, O., Taniguchi, M., Sora, S., & Sato, H. (2011). Intraoperative continuous monitoring of evoked facial nerve electromyograms in acoustic neuroma surgery. Acta Neurochirurgica, 153(5), 1059–1067.'}

    rescue WebMock::NetConnectNotAllowedError
      assert true == false, 'There is an error in SearchController#es_by_title_author if we got here, a parsed citation should be serialized into the JSON spec noted in stub_request'
    end

    js = JSON.parse @response.body
    assert_equal 1, js['data'].count, 'One result object should be returned'
    assert_equal '10.1007/S00701-010-0937-6', js['data'][0]['id'], 'DOI should be upcased into the id property'
    assert_equal 'Intraoperative continuous monitoring of evoked facial nerve electromyograms in acoustic neuroma surgery.', js['data'][0]['attributes']['article']['title']
    assert_equal 'Sora, S.', js['data'][0]['attributes']['article']['authors'][4]
  end
end
