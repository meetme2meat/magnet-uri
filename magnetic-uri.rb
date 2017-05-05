require 'base32'
require 'cgi'
class MagentUri
  def self.decode(uri)
    data = uri.split('magnet:?')[1]
    params = (data && data.length >= 0) ? data.split('&') : []
    output = params.inject({}) do |result,param|
      keyval = param.split("=")
      next if (keyval.length != 2)
      key , val = keyval
      key = key.to_sym
      if key == :dn then
        val = CGI.unescape(val).gsub(/\+/, ' ')
      end

      if [:tr,:xs,:as,:ws].include?(key.to_sym) then
        val = CGI.unescape(val)
      end


      val = CGI.unescape(val).split('+'.freeze) if (key == :kt)

      val = val.to_i if (key == :ix)

      if result[key] then
        if result[key].is_a?(Array) then
          result[key].push(val)
        else
          old_val = result[key]
          result[key] = [old_val, val]
        end
      else
        result[key] = val
      end
      result
    end

    if output[:xt] then
      xts = output[:xt].is_a?(Array) ? output[:xt] : [output[:xt]]
      xts.each do |xt|
        if (m = xt.match(/^urn:btih:(.{40})/))
          output[:infoHash] = m[1].downcase
        elsif (m = xt.match(/^urn:btih:(.{32})/))
          output[:infoHash] = Base32.decode(m[1]).pack('H*')
        end
      end
    end

    output[:name] = output[:dn] if output[:dn]

    output[:keywords] = output[:kt] if output[:kt]

    output[:announce] = [output[:tr]].flatten.compact.uniq


    output[:urlList] = []

    output[:urlList] << output[:as]

    output[:urlList] << output[:ws]

    output[:urlList].flatten!
    output[:urlList].compact!
    output[:urlList].uniq!
    return output
  end


  def self.encode(params)
    #params.with_indifferent_access
    params[:xt] = 'urn:btih:'.concat(params[:infoHash]) if  params[:infoHash]
    params[:dn] = params[:name] if params[:name]
    params[:kt] = params[:keywords] if params[:keywords]
    params[:tr] = params[:announce] if params[:announce]
    params[:ws] = params[:urlList] if params[:urlList]
    params.delete(:as) if params[:urlList]


    output = 'magnet:?'

    params.select! do |key,value|
      key.to_s.length == 2
    end
    params.each_with_index do |(key,value),i|
      values = value.is_a?(Array) ? value : [value]
      values.each_with_index do |val,j|
        output << '&'  if ((i > 0 || j > 0) && (key != :kt || j == 0))

        val = CGI.escape(val).gsub(/%20/, '+') if (key == :dn)

        val = CGI.escape(val) if [:tr,:xs,:as,:ws].include?(key)

        val = CGI.escape(val) if key == :kt

        if (key == :kt && j > 0)
          output  << '+' << val
        else
          output << key.to_s << '=' << val
        end
      end
    end
    # params.inject(output) do |url,(key,value)|
    #   [values].flatten
    # end

    #Base32.encode(...)
    return output
  end
end