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
require 'iconv'
require 'optparse'
require 'pp'
require "rexml/document"
require 'net/http'
require 'uri'
require 'yaml'

options = {}

# functions
OptionParser.new do |opts|
   opts.banner = "Usage: #{File.basename($0)}"
   opts.on("-h", "--help", "Displays this help info") do
      puts opts
      exit 0
   end
   opts.on("-a", "--artist", "Get top tracks for specified artist") do
      options[:artist] = true
   end
   opts.on("-m", "--m3u", "Generate m3u file") do
      options[:m3u] = true
   end
   opts.on("-v", "--verbose", "Verbose output") do
      options[:verbose] = true
   end
   begin
      opts.parse!(ARGV)
   rescue OptionParser::ParseError => e
      warn e.message
      puts opts
      exit 1
   end
end

def genM3u(filename,playlist)
   f = File.open("top_#{filename}.m3u","w")
   playlist.each {|i| f.puts(i.file)}
   f.close
end

def makeTopTracks(current_artist,mpd,options, conf)
   track_arr = []
   new_playlist = []
   added = 0
   query = "method=artist.gettoptracks" + "&artist=#{URI.escape(current_artist, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}" + "&api_key=#{conf['api_key']}"
   source = URI.parse("http://ws.audioscrobbler.com/2.0/")
   source.query = query
   response = Net::HTTP.get(source)
   parsed = REXML::Document.new(response)
   parsed.elements.each("lfm/toptracks/track/name") { |element| track_arr.push(Hash['title', element.text]) }
   own_songs = mpd.search('artist', current_artist)

   for i in track_arr do
      index = own_songs.index {|j| Iconv.conv('utf-8','iso-8859-15',j.title.downcase) == Iconv.conv('utf-8','iso-8859-15',i['title'].downcase) }
      if index != nil
         new_playlist.push(own_songs[index].file)
         added += 1
         if options[:verbose]
            puts "+ #{own_songs[index]}"
         end
      end
   end
   mpd.clear
   new_playlist.each {|i| mpd.add(i)}

   return added
end

conf = YAML.load_file(File.dirname(__FILE__)+'/genPlaylist.conf')
mpd = MPD.new(conf['mpd_host'], conf['mpd_port'])
mpd.connect

# main
if options[:artist]
   current_artist = ARGV[0]
elsif !mpd.playlist().empty?
   current_artist = mpd.current_song().artist
else
   STDERR.puts "No track specified!"
   exit 1
end

added = makeTopTracks(current_artist,mpd,options,conf)
if added > 0
   mpd.play(0)
   if options[:m3u]
      genM3u(mpd.current_song().artist,mpd.playlist())
   end
else
   STDERR.puts "No tracks added!"
end

exit 0
