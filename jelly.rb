require 'webrick/httpproxy'
include WEBrick
require 'stringio' 
require 'zlib'
require 'uri'
require 'optparse'

$default = {}
$default['url'] = 'http://www.google.com'
$default['ide'] = true

opts = OptionParser.new do |opts|

  #wrapper option where value is required:
  opts.on("-u=URL") do |val|
    default['url'] = "#{val}"
  end

  #wrapper option where value is optional:
  opts.on("-x [=ide]") do |val|
    if ("#{val}" == false)
        default['ide'] = false
    end
  end
end
opts.parse(ARGV)

class WEBrick::HTTPRequest
  def  update_uri(uri)
    @unparsed_uri = uri
    @request_uri = parse_uri(uri)
  end
end

class WEBrick::HTTPResponse
  def rpc(urly)
	  @body = "200 OK"
	  self['Content-Length'] = @body.length
    @status = 200
    @reason_phrase = "OK"
  end

  def serve(urly)
    r = urly.path.split("/")

    content_types = {}
    content_types["jpg"] = "image/jpeg"
    content_types["gif"] = "image/gif"
    content_types["png"] = "image/png"
    content_types["html"] = "text/html"
    content_types["js"] = "text/javascript"
    content_types["css"] = "text/css"

    #remove empties and jelly-fishserv
    r.delete_if {|x| x == ''}
    r.delete_if {|x| x == 'jellyfish-serv'}

    #if its a directory, use index.html
    if !(r[r.length-1] =~ /\./)
      r << "index.html"
    end

    #set the content-type
    self["Content-Type"] = content_types[r[r.length-1].split(".")[1]]
    @status = 200
    @reason_phrase = "OK"

    #get a string path to the serv
    r.unshift("serv")
    fp = r * "/"
    begin
      displayfile = File.open(Dir.pwd+"/"+fp, 'r')
      content = displayfile.read()
      self["Content-Length"] = content.length
      @body = content
    rescue Errno::ENOENT
      puts "FILE NOT FOUND"
    end
  end

  def  inject_payload(string)
    if !(self['Content-Encoding'] =~ /gzip/)
      if self['Content-Type'] =~ /html/
        begin
          @body.gsub!( /<\/head>/ ,  "#{string}</head>")
        rescue
          puts 'Got a nil body'
        end
      end
    else
      #uncompress gzip
      gz = Zlib::GzipReader.new( StringIO.new( @body ) ) 
      content = gz.read
      content.gsub!( /<\/head>/ ,  "#{string}</head>")

      self['Content-Length'] = content.length
      self['Content-Encoding'] = ''
      @body = content
    end
  end
end

req_call = Proc.new do |req,res| 
  req.update_uri()
end

#do dispatching
res_call = Proc.new do |req,res|
  urly = URI.parse(req.unparsed_uri) 
  if urly.path  =~ /jellyfish-serv/
	  res.serve(urly)
  elsif urly.path =~ /jellyfish-rpc/
	  res.rpc(urly)
  else
  	res.inject_payload('<script src="/jellyfish-serv/js/LAB.js"></script><script src="/jellyfish-serv/js/injected.js"></script>')
  end
end


s = WEBrick::HTTPProxyServer.new(
  :Port => 8000,
  :RequestCallBack => req_call,
  :ProxyContentHandler => res_call
  #:ServerType => Daemon
  #:RequestCallback => Proc.new{|req,res|
  #  puts "-"*70
  #  puts req.request_line, req.raw_header
  #  puts "-"*70
  #}
)
trap("INT"){ s.shutdown }
s.start
#s.mount("/shit", HTTPServlet::FileHandler, Dir.pwd+'/serv', {:FancyIndexing=>true})

