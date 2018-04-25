class ArticleResultSerializer < ActiveModel::Serializer
  attributes :full_title, :volume, :issue, :article, :doi
end
