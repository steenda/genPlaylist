#!/usr/bin/env ruby
#       genPlaylist.rb
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#       MA 02110-1301, USA.

require 'librmpd'
require 'optparse'
require "rexml/document"
require 'net/http'
require 'uri'
require 'yaml'

API_KEY = "b25b959554ed76058ac220b7b2e0a026"
BASE_URL = "http://ws.audioscrobbler.com/2.0/"

# classes
class Song
  attr_accessor :title
  attr_accessor :artist

  def initialize(*args)
    if args.size < 1  || args.size > 2
      puts 'Song.initialize: wrong parameter count!'
    else
      if args.size == 1
    @title = REXML::XPath.first(args[0], "name").text
    @artist = REXML::XPath.first(args[0], "artist/name").text
      else
    @title = args[0]
    @artist = args[1]
      end
    end
  end

end

# functions
def genM3u(filename,playlist)
  f = File.open("top_#{filename}.m3u","w")
  playlist.each {|i| f.puts(i.file)}
  f.close
end

def queryLastFM(query)
  track_arr = []
  source = URI.parse(BASE_URL)
  source.query = query  + "&api_key=#{API_KEY}"
  parsed = REXML::Document.new(Net::HTTP.get(source))
  parsed.elements.each("//track") { |element| track_arr.push(Song.new(element)) }

  return track_arr
end

def addExistingTracks(track_arr, mpd)
  artist_arr = []
  new_playlist = []
  own_songs = []
  tmp = []
  added = 0

  track_arr.each{|x| artist_arr.push(x.artist)}
  for i in artist_arr.uniq do
    tmp = mpd.search('artist', i)
    if tmp.empty?
      track_arr.delete_if {|x| x.artist == i }
    else
      own_songs += tmp
    end
  end


  for found in track_arr do

    index = own_songs.index {|own| own.title.casecmp(found.title) == 0 }
    if index != nil
      new_playlist.push(own_songs[index].file)
      added += 1
    end
  end
  mpd.clear
  new_playlist.each {|j| mpd.add(j)}

  return added
end

def makeTopTracks(current_artist,mpd)
  query = "method=artist.gettoptracks" + "&artist=#{URI.encode(current_artist)}"
  track_arr = queryLastFM(query)

  return addExistingTracks(track_arr, mpd)
end

def makeSimilarTracks(mpd)
  query = "method=track.getsimilar" + "&artist=#{URI.encode(mpd.current_song().artist)}" + "&track=#{URI.encode(mpd.current_song().title)}"
  track_arr = queryLastFM(query)

  return addExistingTracks(track_arr, mpd)
end

def makeTopTags(tag,mpd)
  query = "method=tag.gettoptracks" + "&tag=#{URI.encode(tag)}"
  track_arr = queryLastFM(query)

  return addExistingTracks(track_arr, mpd)
end

# main
added = 0
options = {}
if File.exist?(File.dirname(__FILE__)+'/genPlaylist.conf')
  conf = YAML.load_file(File.dirname(__FILE__)+'/genPlaylist.conf')
  mpd = MPD.new(conf['mpd_host'], conf['mpd_port'])
else
  mpd = MPD.new("localhost", 6600)
end
mpd.connect

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)}"
  opts.on("-h", "--help", "Displays this help info") do
    puts opts
    exit 0
  end
  opts.on("-a", "--artist", "Get top tracks for specified artist") do
    options[:artist] = true
    if ARGV[0] != nil
      added = makeTopTracks(ARGV[0],mpd)
    elsif !mpd.playlist().empty?
      added = makeTopTracks(mpd.current_song().artist,mpd)
    else
      STDERR.puts "No track specified!"
      exit 1
    end
  end
  opts.on("-s", "--similar", "Get similar tracks for currently playing song") do
    options[:similar] = true
    if !mpd.playlist().empty?
      added = makeSimilarTracks(mpd)
    else
      STDERR.puts "No track playing!"
      exit 1
    end
  end
  opts.on("-t", "--tag", "Get top tracks for specified tag") do
    options[:tag] = true
    param = ARGV[0]
    added = makeTopTags(param,mpd)
  end
  opts.on("-m", "--m3u", "Generate m3u file") do
    options[:m3u] = true
  end
  begin
    opts.parse!(ARGV)
  rescue OptionParser::ParseError => e
    warn e.message
    puts opts
    exit 1
  end
end

if added > 0
  mpd.play(0)
  if options[:m3u]
    genM3u(mpd.current_song().artist,mpd.playlist())
  end
else
  STDERR.puts "Could not generate playlist!"
end

exit 0

