#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
binmode(STDOUT, ':encoding(UTF-8)');
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use Getopt::Long;
use File::Basename;
use File::Copy;
use File::Path;

# Requires the build-dmg package from Homebrow or
# https://github.com/andreyvit/yoursway-create-dmg.git


my $usage = <<END;
USAGE: $0 path_to_IPA_Manager

Creates IPA Palette DMG file.

    -a, --art           Include album art in PDF and HTML
    -b, --book          Use LaTeX book class instead of report
    -d, --delete        Delete LaTeX files after rendering PDF
    -f, --frontmatter   Suppress the frontmatter
    -g, --git           Commit and push to repo
    -h, --help          Print this summary and exit
    -H, --HTML          Create HTML
    -i, --input         Read from argument instead of NASummaries.txt
    -l, --latex         Create LaTeX
    -n, --number        Use this number as the Show number in the git commit
    -N, --noop          Do not execute rsync or git that would touch a remote site
    -r, --reedit        Indicate reedits in the LaTeX
    -t, --title         Suppress the title page
    -u, --upload        rsync to callclooney.org
    -v, --verbose       Print upload and git commands before executing them
END

my ($opt_art, $opt_book, $opt_delete, $opt_frontmatter, $opt_git, $opt_help,
    $opt_HTML, $opt_input, $opt_latex, $opt_number, $opt_noop, $opt_reedit,
    $opt_title, $opt_upload, $opt_verbose);

Getopt::Long::Configure ('bundling');
die 'Terminating' unless GetOptions('a|art' => \$opt_art,
           'b|book' => \$opt_book,
           'd|delete' => \$opt_delete,
           'f|frontmatter' => \$opt_frontmatter,
           'g|git' => \$opt_git,
           'h|?' => \$opt_help,
           'H|HTML' => \$opt_HTML,
           'i|input:s' => \$opt_input,
           'l|latex' => \$opt_latex,
           'n|number:i' => \$opt_number,
           'N|noop' => \$opt_noop,
           'r|reedit' => \$opt_reedit,
           't|title' => \$opt_title,
           'u|upload' => \$opt_upload,
           'v|verbose+' => \$opt_verbose);

print "Verbosity $opt_verbose\n" if $opt_verbose;

unless (scalar @ARGV == 1)
{
  die "Script requires path to IPA Manager app\n";
}
my $app = $ARGV[0];
#print "App at $app\n";
unless (-d $app)
{
  die "No app found at '$app'\n";
}
unless (-d 'IPAPalette.xcodeproj')
{
  die "Current directory does not seem to be the IPA Palette project\n";
}
File::Path::rmtree 'Distribution' if -d 'Distribution';
unlink 'Distribution/rw.IPAPalette.dmg' if -f 'Distribution/rw.IPAPalette.dmg';
unlink 'IPAPalette.dmg' if -f 'IPAPalette.dmg';
#my $appname = File::Basename::basename($app);
my $cmd = "ditto \"$app\" \"Distribution/IPA Manager.app\"";
print `$cmd`;
my $output = `$cmd`;
if ($?)
{
  print BOLD RED "$output\n";
  exit($?);
}

$cmd =  'create-dmg'.
        ' --volname "IPA Palette"'.
        ' --volicon Installer/DMG.icns'.
        ' --background Installer/VowLight.png'.
        ' --window-size 500 360'.
        ' --icon-size 96'.
        ' --icon "IPA\ Manager.app" 60 210'.
        ' --hide-extension "IPA\ Manager.app"'.
        ' --no-internet-enable'.
        ' --app-drop-link 300 210'.
        ' Distribution/IPAPalette.dmg Distribution';
print BLUE "$cmd\n" if $opt_verbose;
$output = `$cmd`;
if ($?)
{
  print BOLD RED "$output\n";
  exit($?);
}

unlink 'rw.IPAPalette.dmg' if -f 'rw.IPAPalette.dmg';
$cmd = 'Sparkle-1.22.0/bin/sign_update Distribution/IPAPalette.dmg';
print BLUE "$cmd\n" if $opt_verbose;
$output = `$cmd`;
if ($?)
{
  print BOLD RED "$output\n";
  exit($?);
}
else
{
  print GREEN "$output\n";
}


#  Copyright © 2005-2020 Brian S. Hall, BLUGS.COM LLC
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
