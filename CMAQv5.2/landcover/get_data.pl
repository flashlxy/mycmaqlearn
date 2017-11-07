#!/usr/bin/perl

    use strict;
    use warnings;

    use Cwd;
    use File::Basename;
    use File::Path qw(make_path);
    use Getopt::Long;
    use HTTP::Cookies;
    use LWP::UserAgent;
    use MIME::Base64;
    use Pod::Usage;


    # Set up basic configuration and retrieve command line options

    my $uid = "";    # Can hard code, not secret
    my $passwd = ""; # Can hard code ONLY if script secured

    my @urls    = ();
    my $urs     = 'urs.earthdata.nasa.gov';

    my @input = ();
    my $quiet = 0;
    my $verbose = 0;
    my $help;
    my $netrc = 0;
    my $dir = getcwd;
    my $cookie_file = "$ENV{HOME}/.cookies.txt";
    my $netrc_file = "$ENV{HOME}/.netrc";

    GetOptions(
        'h|help'    => \$help,
        'n|netrc'   => \$netrc,
        'q|quiet'   => \$quiet,
        'v|verbose' => \$verbose,
        'd|dir=s'   => \$dir,
        'u|uid=s'   => \$uid,
        'c=s'       => \$cookie_file,
        'i=s'       => \@input);

    pod2usage(-verbose => 2) if $help;


    # If a netrc option was provided, pull credentials from it

    if ($netrc) {
        open my $handle, '<', $netrc_file or die "Could not find .netrc file";
        chomp(my @lines = <$handle>);
        close $handle;
        foreach (@lines) {
            if ( /^\s*machine\s+$urs\s+login\s+([^\s]+)\s+password\s+([^\s]+)/ ) {
                $uid = $1;
                $passwd = $2;
                print "Retrieved username and password from .netrc file '$netrc_file'\n" if $verbose;
                last;
            }
        }
        die "No suitable credentials found in $netrc_file" unless ($uid && $passwd);
    }

    # Any remaining arguments are treated as URLs to retrieve

    push(@urls, @ARGV);


    # Pull urls from any input files provided on the command line

    foreach (@input) {
        die "Cannot read input file '$_'" unless (-e $_);
        open my $handle, '<', $_ or die "Could not open $_ for input";
        my @lines = <$handle>;
        close $handle;

        s{^\s+|\s+$}{}g foreach @lines;
        foreach (@lines) {
            push @urls, $_ if ($_ && substr($_, 0, 1) ne '#');
        }
    }

    die "No URLs provided" unless (@urls);
    print scalar @urls, " urls to download\n" if $verbose;


    # Request any missing credntial values

    if( ! $uid )
    {
        print "Please enter your Earthdata Login username: ";
        chomp($uid = <STDIN>);
    }
    if( ! $passwd )
    {
        print "Please enter your Earthdata Login password: ";
        system('/bin/stty', '-echo');
        chomp($passwd = <STDIN>);
        system('/bin/stty', 'echo');
        print "\n";
    }
    my $credentials = encode_base64("$uid:$passwd", "");


    # Create a user agent to handle the request. We configure a cookie jar
    # for saving the session cookies. Note that 'ignore_discard' is required,
    # otherwise LWP immediately throws away the cookie returned by the Apache
    # URS auth module (it does not even persist it through the redirects).
    # The module gives does not specify a cookie expiration, which means that
    # it *should* last for the duration of the session - i.e. up to the point
    # that the agent object is destroyed. The advantage of this option is that
    # it allows the session to persist across multiple executions - up to the
    # point at which the application decides that the session should end, so
    # it is very efficent.
    # The cookie file is currently named '.cookies.txt', saved in the users
    # home directory. This should be given an application specific name.

    print "Using cookie file '$cookie_file'\n" if $verbose;
    my $agent = LWP::UserAgent->new(
        cookie_jar  => HTTP::Cookies->new(
            file => $cookie_file,
            ignore_discard => 1,
            autosave => 1)
    );


    # SSL certificate verification is disabled. This is usually not necessary in
    # properly configured production systems, but many user environments do not
    # have the necessary certificates configured.

    $agent->ssl_opts(verify_hostname => 0);


    # Set up a redirection handle for URS. Unlike curl and wget which can be
    # configured to send credentials based entirely on a hostname (no 401
    # required), LWP cannot. Thus we use a handle to detect the redirect
    # to URS and automatically add in the credentials.

    $agent->add_handler(
        request_prepare => sub {
            my($request, $ua, $h) = @_;
            print "Providing Earthdata Login credentials\n" if $verbose;
            $request->header(Authorization => "Basic $credentials");
        },
        m_host => $urs,
        m_path_prefix => '/oauth/authorize');


    # Add a handler to detect the 'unauthorized' response coming back from URS,
    # and modify the response. This would normally redirect back to the
    # application, which would then return an error back to us (usually a 403).
    # However, unless the application returns very good error message that we
    # can parse, we can't really tell if a 403 response from the server is due
    # to the fact that the user has not authorized the application, or the
    # application has not authorized the user!
    # The handler can be modified as necessary to allow error handling code to
    # pick it up and act appropriately. We also repopulate the 'Location'
    # header with a web URL that can be used to approve the application (a
    # user would need to log in to urs before using this URL).

    $agent->add_handler(
        response_done => sub {
            my($response, $ua, $h) = @_;
            if ($response->code == 302 && $response->header('location') =~ /error=access_denied/) {
                $response->code(403);
                $response->message('Forbidden');
                $response->content('You have not authorized the application providing this data.');

                # Pull out the client ID needed for the application approval URL

                if ($response->request->uri =~ /client_id=([^&]+)/ ) {
                    $response->header('location' => "https://${urs}/approve_app?client_id=${1}");
                }
            }
        },
        m_host => $urs,
        m_path_prefix => '/oauth/authorize');


    # Check the save location exists and is a directory

    make_path($dir) if (! -e $dir);
    die "Unable to create output directory '$dir'" if (! -d $dir);
    print "Saving files to $dir\n" if $verbose;


    # Build and execute the request.

    foreach (@urls) {
        get_file($agent, $_);
    }

    exit(0);




# Retrieves a named resource and saves it to the configured location
#
# Arguments:
# 1     User agent
# 2     URL of file to retrieve

sub get_file {

    my $agent = shift;
    my $url = shift;


    # Construct the request and execute

    my $req = HTTP::Request->new(GET => $url);
    my $response = $agent->request($req);


    # Output the response

    if ($response->is_success) {
        # Check to see if there is a content disposition we can use for the
        # output filename. If not, we must use the URL

        my $regex = '"([^"]+)"';
        my $filename = basename($url);
        my $cd = $response->header('Content-Disposition');
        if ($cd && $cd =~ /filename\s*=\s*$regex/ ) {
            $filename = $1;
        }

        #print $response->header('Content-Type'), "\n";

        # Save the file

        my $outfile = "$dir/$filename";
        open my $handle, '>', $outfile or die "Unable to create output file '$outfile': $!\n";
        binmode $handle;
        print $handle $response->content;
        close $handle;
        print "Downloaded $url as $filename\n" if $verbose;
    }
    else {
        if (!$quiet) {
            print STDERR "ERROR: Failed to retrieve resource '$url': ", $response->status_line, "\n";
            print STDERR $response->content, "\n";
        }


        # If we detect an 'unauthorized' event, we log an error and abort

        if ($response->code == 403 && $response->header('location')) {
            print "Please log in to Earthdata Login and then use the following URL to ";
            print "approve the application.\n";
            print $response->header('location'), "\n";
            exit(0);
        }
    }

}


    __END__

=head1 SYNOPSIS


B<get_data.pl> [options] [<url>]

Download data files from an Earthdata Login enabled server.

=cut


=head1 OPTIONS

=over 8

=item B<-i file>

The name of a file that contains a list of URLs to download. This option may
be given multiple times.

=item B<--uid=uid> or B<-u uid>

The Earthdata Login username under which the files will be downloaded. Note
that there is no option to provide a password on the command line. However,
credentials may be pulled from a .netrc file.

=item B<--netrc> or B<-n>

Pull the required Earthdata Login credentials from your .netrc file. This is
expected to reside in your home directory.

=item B<--verbose> or B<-v>

Produce verbose (debugging) information during operation.

=item B<--quiet> or B<-q>

Supresses error messages for URLs that could not be downloaded.

=item B<--help> or B<-h>

This help information.

=back
=cut


=head1 EXAMPLES

B<get_data.pl -u peter.l.smith -i urllist -v>

Download the files whos URLs are given in the file 'urllist' to the current
directory using the user profile 'peter.l.smith'. Prompt for the user password.
Verbose (debugging) output will be generated.

B<get_data.pl -u peter.l.smith d data http://e4ftl01.cr.usgs.gov/ASTT/AST_L1T.003/2016.09.11/AST_L1T_00309112016020239_20160912100405_5264_QA.txt>

Download the file given by the URL on the command line using the user profile
'peter.l.smith' and save it into the directory 'data'. Prompt for the user
password.

B<get_data.pl -n d data -i urllist>

Download the files whos URLs are given in the file 'urllist' and save into the
directory 'data'. Earthdata Login credentials will be retrieved from the .netrc
file.

=cut


=head1 DESCRIPTION

Downloads data files from Earthdata Login enabled servers. Data files are
identified using URLs, and may be provided on the command line or in a file.
User credentials are required for authentication, and the applications from
which the files are being downloaded must have been pre-authorized.

If a file is returned from the server with a 'Content-Disposition' header,
the filename given in that header will be used as the name of the downloaded
file, otherwise the filename in the URL will be used.


=cut


=head1 AUTHOR


B<Peter Smith>  (peter.l.smith@nasa.gov)

=cut
