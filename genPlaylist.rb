#!/usr/bin/env ruby
require 'librmpd'
require 'rockstar'

def handle_error(error)
   case error
   when :NOSONG
      STDERR.puts "No track specified!"
   when :WRONGARGS
      STDERR.puts "Wrong argument count!"
   end
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
      index = own_songs.index {|x| x.title == i }
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

Rockstar.lastfm = YAML.load_file('genPlaylist.conf')

mpd = MPD.new 'localhost', 6600
mpd.connect

case $*.length
when 0
   if !mpd.playlist().empty?
      current_artist = mpd.current_song().artist
   else
      handle_error(:NOSONG)
   end
when 1
   current_artist = $*[0]
else
   handle_error(:WRONGARGS)
end

artist = Rockstar::Artist.new(current_artist)
makeTopTracks(artist,mpd)

exit 0
