require 'rdiscount'
require 'innate'
require 'find'
require 'nokogiri'
require 'date'
require 'time'
require 'twitter_oauth'

module Into
  extend Innate::Traited

  class Articles
    include Innate::Node
    map '/'

    layout('default'){|name, wish| wish != "atom" }
    provide :html, :engine => :Etanni
    provide :atom, :engine => :Etanni, :type => 'application/xml'

    def index(slug = nil)
      response.headers['Cache-Control'] = 'public, max-age=300'

      client = TwitterOAuth::Client.new

      @mytweets = client.user_timeline(:screen_name => "fabianb", :include_rts => true, :trim_user => false)

      if article = Article[slug]
        render_view(:article, :article => article, :slug => slug)
      else
        render_view(:articles, :articles => Article.first(10))
      end
    end
  private
    def all_tags
      @all_tags ||= Article.inject({}) {|h,a| a[:tags].split(/[^\w]+/).each {|t| h[t] ||= 0; h[t] += 1; } if a[:tags]; h }
    end
  end

  class Article
    extend Enumerable

    def self.each(&block)
      block_given? or return enum_for(__method__)

      Find.find 'articles' do |path|
        yield new(path) if File.file?(path)
      end
    end

    def self.[](slug)
      find{|article| article.slug == slug }
    end

    attr_reader :path

    def initialize(path)
      all = File.read(path)
      head, @body = all.split("\n\n", 2)

      @path = path
      @head = {}

      head.each_line do |line|
        key, value = line.strip.split(/\s*:\s*/, 2)
        self[key] = value
      end
    end

    def content
      @content ||= RDiscount.new(
        @body,
        :autolink, :safelink, :generate_toc, :smart
      )
    end

    def to_html
      content.to_html
    end

    def [](key)
      @head[key.to_s]
    end

    def []=(key, value)
      @head[key.to_s] = value
    end

    def summary
      Nokogiri::HTML(to_html).at(:p).inner_html
    end

    def slug
      File.basename(path, File.extname(path))
    end
    alias href slug

    def url
      Into.trait[:url] + "/" + slug
    end

    def date
      Date.strptime(self[:date], '%Y-%m-%d')
    end

    def datetime
      Date.strptime(self[:date], '%Y-%m-%d')
    end

    def showtime
      Into.trait[:date][date]
    end
  end
end
