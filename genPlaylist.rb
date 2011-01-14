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
require 'rockstar'
require 'iconv'
require 'optparse'

options = {}
conf = YAML.load_file('genPlaylist.conf')
mpd = MPD.new conf['mpd_host'], conf['mpd_port']
Rockstar.lastfm = conf
mpd.connect

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
   begin
      opts.parse!(ARGV)
   rescue OptionParser::ParseError => e
      warn e.message
      puts opts
      exit 1
   end
end

def makeTopTracks(current_artist,mpd)
   artist = Rockstar::Artist.new(current_artist)
   track_arr = []
   new_playlist = []
   added=0
   puts "fetching top tracks..."
   own_songs = mpd.search('artist', artist.name)
   artist.top_tracks.each { |t| track_arr << "#{t.name}" }
   puts "checking for existing tracks..."

   for i in track_arr do
      index = own_songs.index {|x| Iconv.iconv('utf-8','iso-8859-15',x.title.downcase) == Iconv.iconv('utf-8','iso-8859-15',i.downcase) }
      if index != nil
         new_playlist << own_songs[index].file
         added += 1
      end
   end
   mpd.clear
   for i in new_playlist do
      mpd.add(i)
   end
   if !mpd.playlist().empty?
      mpd.play(0)
   end
   puts "added #{added.to_s} songs!"
end

# main
if options[:artist]
   current_artist = ARGV[0]
elsif !mpd.playlist().empty?
   current_artist = mpd.current_song().artist
else
   STDERR.puts "No track specified!"
   exit 1
end

makeTopTracks(current_artist,mpd)

exit 0
