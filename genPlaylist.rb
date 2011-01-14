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

USAGE = "Usage: genPlaylists.rb opts
where opts is
-a 'ARTIST'
or none (currently playing song will be used)"

def handle_error(error)
   case error
   when :NOSONG
      STDERR.puts "No track specified!"
   when :WRONGARGS
      STDERR.puts "invalid arguments"
   end
   STDERR.puts USAGE
   exit 1
end

def makeTopTracks(artist,mpd)
   track_arr = []
   new_playlist = []
   added=0
   puts "fetching top tracks..."
   own_songs = mpd.find('artist', artist.name)
   artist.top_tracks.each { |t| track_arr << "#{t.name}" }
   puts "checking for existing tracks..."

   for i in track_arr do
      index = own_songs.index {|x| Iconv.iconv('utf-8','iso-8859-15',x.title.downcase) == Iconv.iconv('utf-8','iso-8859-15',i.downcase) }
      if index != nil
         new_playlist << own_songs[index].file
         added += 1
      end
   end

   puts "done..."
   mpd.clear
   for i in new_playlist do
      mpd.add(i)
   end
   if !mpd.playlist().empty?
      mpd.play(0)
   end
   puts "added "+added.to_s+" songs!"
end

def printTopTags(artist)
   for i in artist.top_tags do
      if i.count.to_i>0
         print i.name+" "
      end
   end
end

conf = YAML.load_file('genPlaylist.conf')
Rockstar.lastfm = conf

mpd = MPD.new conf['mpd_host'], conf['mpd_port']
mpd.connect

case $*.length
when 0
   if !mpd.playlist().empty?
      current_artist = mpd.current_song().artist
   else
      handle_error(:NOSONG)
   end
when 1
   if $*[0] =~ /^(-h|--help)$/
      mode = $*[0]
   else
      handle_error(:WRONGARGS)
   end
when 2
   if $*[0] =~ /^(-a|-u)$/
      mode = $*[0]
      current_artist = $*[1]
   else
      handle_error(:WRONGARGS)
   end
else
   handle_error(:WRONGARGS)
end


artist = Rockstar::Artist.new(current_artist)
makeTopTracks(artist,mpd)

exit 0
