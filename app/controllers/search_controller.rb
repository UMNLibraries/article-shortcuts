require 'simple_doi'
require 'anystyle'

class SearchController < ApplicationController
  def search
    #render(nothing: true, status: :bad_request) unless params[:q].to_s.length > 0

    # Remove leading,trailing newlines and trailing dots
    q = params[:q].squish.strip.sub /\.*\z/, ''
    @dois = doi(q)
    # Query by list of extracted DOIs or by normal search
    es_body = if !@dois.empty?
      es_by_dois(@dois)
    else
      cite = parse_cite q
      #if cite[:author]
      es_by_any(params[:q])
    end
    result = es.search index: 'article', body: es_body
    article_results = result['hits']['hits'].map { |r| ArticleResult.new r }
    # This is patched through ActiveModel::Serializers for JSON:API serialization
    render json: article_results
  end

  protected
  # Returns a SimpleDOI::DOI if one is found in the input string
  def doi(search)
    SimpleDOI.extract(search).map { |d| d.to_s.upcase }
  end

  def parse_cite(search)
    # Default parser will attempt to separate on newlines
    # which does not work well for
    @parser ||= AnyStyle::Parser.new
    @parser.parse search
  end

  def es
    # reads ENV['ELASTICSEARCH_URL'] or localhost:9200
    @es ||= Elasticsearch::Client.new
  end

  def es_by_dois(dois)
    {
      query: {
        ids: {
          type: 'article', values: dois
        }
      }
    }
  end

  def es_by_any(search, size=5)
    {
      from: 0,
      size: size,
      min_score: "50",
      query: {
        simple_query_string: {
          query: search,
          #fields: ['article.title^2', 'article.authors.name.surname']
          fields: ['article.title^2',]
        }
      }
    }
  end

  def es_by_title_author(title, author, size=5)
    {
      from: 0,
      size: size,
      query: {
        bool: {
          should: [
            {match: {
              'article.title' => {query: title, operator: 'and', boost: 2}
            }},
            {
              nested: {
                path: 'article.authors',
                query: {
                  match: {
                    'article.authors.name.surname' => {query: author}
                  }
                }
              }
            }
          ]
        }
      }
    }
  end
end
