module Questionable
  class Comic
    include Celluloid

    def initialize(title, url)
      @title = title
      @url = url
      @condition = Condition.new

      async.fetch
    end
    attr_reader :title, :url

    def fetch
      uri = URI.parse(@url)
      resp = Net::HTTP.get_response(uri)
      if resp.class.name == "Net::HTTPFound" && resp.inspect =~ /302/
        resp = Net::HTTP.get_response(URI.parse("#{@url.gsub('/comics/', resp['location'])}"))
      end
      html = Hpricot(resp.body)
      images = html.search("//img[@src*=comics/]")
      images << html.search("//img[@src*=#{Time.now.year}/#{@url.split('//')[1].split('.').first}]")
      images << html.search("//img[@src*=db/files/Comics/]")

      images = images.sort_by { |i, j| i.to_s <=> j.to_s } if images.size > 1
      @images = images.flatten.map do |i|
        if (image = i.to_s) !~ /http:\/\//
          image = image.gsub(/src=[\"|\']/){|m| "#{m}#{@url}/"}.
                        gsub("#{@url}#{@url}", @url).
                        gsub("#{@url}//", "#{@url}/")
        end

        image
      end
      @condition.broadcast @images
    rescue
      puts "can't get #{@url}: #{$!.inspect}"
    end

    def images
      return @images if @images
      @condition.wait
    end

    def haml_object_ref
      "comic"
    end

    def id
      @title
    end
  end
end
