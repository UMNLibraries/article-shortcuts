require 'simple_doi'
require 'anystyle'

class SearchController < ApplicationController
  CITE_AUTHORS_MIN_LENGTH = 10
  CITE_TITLE_MIN_LENGTH = 20

  def search
    #render(nothing: true, status: :bad_request) unless params[:q].to_s.length > 0

    # Remove leading,trailing,inner newlines and trailing dots
    q = params[:q].gsub(/\r?\n/, '').squish.strip.sub /\.*\z/, ''
    puts q
    @dois = doi(q)
    # Query by list of extracted DOIs or by normal search
    es_body = if !@dois.empty?
      es_by_dois(@dois)
    elsif cite = parse_cite(q)
      es_by_title_author(cite[:title], cite[:authors])
    else
      es_by_any(q)
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

  # Attempt to parse authors & title out of a citation with AnyStyle
  # Returns Hash {:authors, :title} if they meet length requirements or nil
  def parse_cite(search)
    # Default parser will attempt to separate on newlines
    # which does not work well for
    @parser ||= AnyStyle::Parser.new
    cite = @parser.parse(search).first rescue {}
    # Condense an array of individual first/last hash pairs or a ":literal => all authors..."
    # into one long string
    authors = cite[:author].map(&:values).flatten.join(' ') rescue ""
    # Stuff all titles into an array
    title = cite[:title].flatten.join(' ') rescue ""
    if authors.length >= CITE_AUTHORS_MIN_LENGTH && title.length >= CITE_TITLE_MIN_LENGTH
      {authors: authors, title: title}
    end
  end

  def es
    # reads ENV['ELASTICSEARCH_URL'] or localhost:9200
    @es ||= Elasticsearch::Client.new log: true
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
    # Maybe map min score to search length?
    min_score = case
      when search.length < 20
        10
      when search.length < 30
        30
      when search.length < 40
        40
      else
        30
    end
    Rails.logger.warn "Min score: #{min_score}"
    {
      from: 0,
      size: size,
      min_score: min_score,
      query: {
        simple_query_string: {
          query: search,
          #fields: ['article.title^2', 'article.authors.name.surname']
          fields: ['article.title',]
        }
      }
    }
  end

  def es_by_title_author(title, author, size=5)
    {
      from: 0,
      size: size,
      #min_score: "20",
      query: {
        bool: {
          # Title is required to match
          must: {
            match: {
              'article.title' => {query: title, operator: 'and'}
            }
          },
          # Authors are permitted not to match
          minimum_should_match: 0,
          should: {
            nested: {
              path: 'article.authors',
              query: {
                match: {
                  'article.authors.name.surname' => {query: author}
                }
              }
            }
          }
        }
      }
    }
  end
end
