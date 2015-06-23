package Alma::Analytics;

$VERSION = "2015.06.23";
sub Version { $VERSION; }

use utf8;
use open ':encoding(utf8)';
binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

use constant TRUE => 1;
use constant FALSE => 0;

use constant DEBUG => 0;

use Carp;
use LWP::UserAgent;
use URI::Escape;
use XML::Simple;
$XML::Simple::PREFERRED_PARSER = 'XML::Parser';
use Data::Dumper;
$Data::Dumper::Indent = 1;

my $errstr = '';
my $savecnt = 0;

my $ua = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );

my $apikey = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
my $host = 'api-ap.hosted.exlibrisgroup.com';

sub new {
	my $class = shift;
	my %params = @_;
	my $self = \%params;

	bless $self, $class;

	## We can hard-wire host and key, since they'll always be the same.
	## But just in case you need to change them, they can be included
	## as parameters.
	unless ( $self->{apikey} ) { $self->{apikey} = $apikey; }
	unless ( $self->{host}   ) { $self->{host} = $host; }

	## path is the only critical variable
	unless ( $self->{path}   ) { croak "No path given" }

	## how many rows per file? Somewhere between 25 and 1000,
	## in multiples of 25. Defaults to 1000.
	unless ( $self->{limit}  ) { $self->{limit} = 1000; }

	## internals
	$self->{token} = '';
	$self->{isFinished} = 0;
	return $self;
}

sub error {
	my $class = shift;
	return $errstr;
}

sub fetch {
	my $self = shift;
	my $url = $self->url;
	print STDERR $url, "\n" if $self->{saveto};

	my $response = $ua->get( $url );

	unless ( $response->is_success ) { print STDERR $response->status_line; }

	my $xml = $response->decoded_content;

	## if debugging, use the saveto parameter to save the XML file(s)
	if ( $self->{saveto} ) {
	    open X, ">", "$self->{saveto}-$savecnt.xml"; print X $xml; close X; $savecnt++;
	}

	my $data = XMLin( $xml );

	my $rows = $data->{QueryResult}->{ResultXml}->{'rowset'}->{Row};

	if ( $data->{QueryResult}->{IsFinished} eq 'true' )
	{
	    $self->{isFinished} = 1;
	}
	else
	{
	    ## we're not finished: get the next batch
	    ## only the first file has a resumption token!
	    unless ($self->{token}) { $self->{token} = $data->{QueryResult}->{ResumptionToken}; }
	}
	return $rows;
}

sub isFinished {
	my $self = shift;
	return $self->{isFinished};
}

sub url {
	my $self = shift;
	my $url = sprintf "https://%s/almaws/v1/analytics/reports?path=%s&limit=%s&apikey=%s",
		$self->{host}, uri_escape($self->{path}), $self->{limit}, $self->{apikey};
	if ( $self->{token} )
	{
		$url .= "&token=$self->{token}";
	}
	elsif ( $self->{filter} )
	{
		$url .= "&filter=" . uri_escape($self->{filter});
	}
	return $url;
}

1;

__END__

=head1 NAME

Alma::Analytics.pm

=head1 SYNOPSIS

    use Alma::Analytics;

    my $api = Alma::Analytics->new(
	path  =>  '/shared/path/to/your/report',
	limit  =>  1000,
	apikey  =>  'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
	host  =>  'api-ap.hosted.exlibrisgroup.com',
	saveto => 'filename-prefix',
	filter => '<xml filter code from OBI>',
    );

    until ($api->isFinished) {

	my $rows = $api->get;
	foreach my $row ( @{ $rows } ) {
		print $row->{Column3}, "\t", $row->{Column1}, "\n";
	}

    }

=head1 DESCRIPTION

Uses the Analytics API to extract data. Data is returned as an array,
where each item in the array is a data row from Analytics.

You need to run the report once with the saveto parameter to see which
columns contain which data fields. It's not obvious.

=head1 OPTIONS

=over

=item path [required]

The path to your Report in OBI

=item limit [optional]

how many rows per file? Somewhere between 25 and 1000,
in multiples of 25. Defaults to 1000.

=item apikey [optional]

Your API key. This is hard coded in the script, but can be used
to override the default.

=item host [optional]

The Analytics host. Hard coded, but use this to override.

=item saveto [optional]

A file name prefix for saving the incoming XML file(s).

=item filter [optional]

An XML-format filter for the report, created by copying from
OBI, under the Advanced tab.

=back

=head1 AUTHOR

Steve Thomas <stephen.thomas@adelaide.edu.au>

=head1 VERSION

This is version 2015.06.23

=head1 LICENCE

Copyright 2015 Steve Thomas

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
