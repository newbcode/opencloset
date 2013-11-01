#!/usr/bin/env perl

use v5.14;
use utf8;
use strict;
use warnings;

use Getopt::Long;
use HTTP::Request::Common;
use HTTP::Request;
use JSON;
use LWP::UserAgent;
use Pod::Usage;
use Text::CSV;

my %options;
GetOptions(\%options, "--help");

run(\%options, @ARGV);

sub trim { shift =~ s/(^ +| +$)//gr }

sub run {
    my($opts, @args) = @_;

    pod2usage(0) if $opts->{help} || @args < 1;

    binmode STDOUT, ":utf8";
    binmode STDERR, ":utf8";

    my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1 });
    open my $fh, "<:encoding(utf8)", "$args[0]" or die "$args[0]: $!";
    my $headers = $csv->getline($fh);
    map { $_ = trim($_) } @$headers;
    $csv->column_names(@$headers);

    # , 코드번호, , 성별, 복종, 번호, 가슴둘레, 팔길이, 허리둘레, 바지기장, 밑단 (인치), 색상, 패턴, 계절, 상의허리, 어깨, 소매통, 상의총길이, 엉덩이둘레, 허벅지둘레, 밑위, , , 기증자, 기증일시, 기증벌수, 연락처, 이메일, 주소, SNS, 기증벌수, 기증내역, 기증메세지, 경험공유여부,

    my $ua = LWP::UserAgent->new;

    if ( $ENV{DEBUG} ) {
        $ua->add_handler(
            'request_prepare' => sub {
                my ($req, $ua, $h) = @_;
                say $req->as_string;
            }
        );

        $ua->add_handler(
            'response_done' => sub {
                my ($res, $ua, $h) = @_;
                say $res->as_string;
            }
        );
    }

    my $loop = 1;
    my ($success, $fail) = (0, 0);
    while (my $row = $csv->getline_hr($fh)) {
        $loop++;
        my $category_id;
        if ($row->{'가슴둘레'} && $row->{'허리둘레'}) {
            $category_id = -1;
        }
        elsif ($row->{'가슴둘레'}) {
            $category_id = 1;
        }
        elsif ($row->{'허리둘레'}) {
            $category_id = 2;
        }
        else {
            say STDERR "[$loop] NOT FOUND category";
            next;
        }

        my $res = $ua->request(
            POST 'http://localhost:5000/clothes.json',
            [
                chest       => $row->{'가슴둘레'},
                waist       => $row->{'허리둘레'},
                arm         => $row->{'팔길이'},
                pants_len   => $row->{'바지기장'},
                category_id => $category_id,
            ]
        );

        my $data = decode_json($res->content);
        if ($res->is_success) {
            $success++;
        }
        else {
            $fail++;
            say STDERR $data->{error};
        }
    }

    say "SUCCESS: $success";
    say "FAIL   : $fail";
}

__END__

=pod

=encoding utf-8

=head1 NAME

import.pl - import clothes data from csv to database

=head1 SYNOPSIS

    $ import.pl [OPTIONS] /path/to/clothe-data.csv

    OPTIONS
      -h, --help          show this messages

=head1 DESCRIPTION

=head1 LICENSE

same as Perl.

=head1 AUTHOR

Hyungsuk Hong

=cut
