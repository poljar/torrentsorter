#!/usr/bin/perl
use warnings;
use strict;

use File::Copy;
use File::MimeInfo;
use Getopt::Std;
use WWW::Mechanize;
use Net::BitTorrent::File;

use vars qw/ %opt /;
use vars qw($videoDir $audioDir $comicDir $unsortedDir);

# Settings

$videoDir       = "/home/poljar/torrents/video/";
$audioDir       = "/home/poljar/torrents/audio/";
$comicDir       = "/home/poljar/torrents/comics/";
$unsortedDir    = "/home/poljar/torrents/unsorted/";

# Settings end

sub usage
{
    print STDERR << "EOF";
This program sorts torrents based on the content.
Set your watch dir-s inside the script.

usage: $0 [-h] [-f file] [-r url]

 -h        : this (help) message
 -r url    : url to a torrent file.
 -f file   : torrent file to load.

EOF
    exit;
}

sub init
{
    getopts( "hr:f:", \%opt ) or usage();
    usage() if $opt{h};
    usage() unless $opt{r} xor $opt{f};
}

sub checkFile
{
    my $tor_file = $_[0];
    unless(-f "$tor_file") {
        print "$tor_file: No such file\n"; 
        exit;
    }
    unless (mimetype($tor_file) eq "application/x-bittorrent") {
        print "$tor_file: Not a torrent file\n";
        exit;
    }
}

# This function checks the contents of the torrent and
# gives it a id from 0 to 3 (0 -> unknown, 1 -> video, 
# 2 -> audio, 3 -> comics)
sub getFileScore
{
    my $torFile = $_[0];
    my $torrent = new Net::BitTorrent::File("$torFile");
    my $files = $torrent->files();

    my $audio = 0;
    my $video = 0;
    my $comic = 0;

    return 1 if($torrent->name() =~ m/\.(avi|mkv|mp4)$/);
    return 2 if($torrent->name() =~ m/\.(mp3|flac|ogg)$/);
    return 3 if($torrent->name() =~ m/\.(cbz|cbr|cb7)$/);

    foreach my $file (@$files) {
        while(my ($key, $value) = each(%$file)) {
           if($key eq 'path') {
               foreach my $path (@$value) {
                   $audio++ if($path =~ m/\.(mp3|flac|ogg)$/);
                   $video++ if($path =~ m/\.(avi|mkv|mp4||ogm)$/); 
                   $comic++ if($path =~ m/\.(cbz|cbr|cb7)$/);
               }
           }
       }
    }

    my $sum = $video + $audio + $comic;

    return 0 if($sum eq 0);
    return 1 if($video >= $audio and $video >= $comic);
    return 2 if($audio >= $video and $audio >= $comic);
    return 3 if($comic >= $audio and $comic >= $video);
}

sub moveFile
{
    my $torFile = $_[0];
    my $score = $_[1];
    my $torrent = new Net::BitTorrent::File("$torFile");
    my $destDir = $unsortedDir;

    $destDir = $videoDir if ($score eq 1);
    $destDir = $audioDir if ($score eq 2);
    $destDir = $comicDir if ($score eq 3);

    move("$torFile", "$destDir".$torrent->name().".torrent") or
    print "Move of file $torFile failed: $!\n"; 
}

sub remoteFile
{
    my $url = $_[0];
    my $mech = WWW::Mechanize->new();
    my $tempFile = "/tmp/tmp.torrent";
    $mech->get( $url, ':content_file' => $tempFile );

    localFile($tempFile);
}

sub localFile
{
    my $torFile = $_[0];
    checkFile($torFile);
    my $score = getFileScore($torFile);

    moveFile($torFile, $score);
}

# //// main \\\\\ #
init(); 

if($opt{r}) {
    remoteFile($opt{r});
}
elsif($opt{f}) {
    localFile($opt{f});
}
