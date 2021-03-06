package OpenCloset::Web::Controller::Event;
use Mojo::Base 'Mojolicious::Controller';

use Algorithm::CouponCode qw(cc_generate);
use DateTime;
use Try::Tiny;

has DB => sub { shift->app->DB };

=head1 METHODS

=head2 seoul

    GET /events/seoul?MberSn=:ciphertext

C<MberSn> param is ciphertext. it encrypted AES algorithm with ECB mode

=over

=item C<MberSn> 별로 연 2회 제한을 두어야 함

=item 총 발급횟수가 4000건을 넘지 말아야 함

=back

=cut

sub seoul {
    my $self = shift;
    my $mbersn = lc( $self->param('MberSn') || '' );
    $self->stash( error => '' ); # prevent template error

    unless ($mbersn) {
        return $self->render(
            error => '잘못된 요청입니다 - MberSn 이 없습니다' );
    }

    my $tz = $self->config->{timezone};

    my $endDate = DateTime->new(
        year   => 2016, month     => 12, day => 30, hour => 23, minute => 59,
        second => 59,   time_zone => $tz,
    );

    if ( $endDate->epoch < DateTime->now( time_zone => $tz )->epoch ) {
        return $self->render(
            error => '이벤트가 종료되었습니다 - 이벤트 기간 종료' );
    }

    my $rs = $self->DB->resultset('Coupon');
    my $used_coupon =
        $rs->search( { desc => { -like => 'seoul|%' }, status => 'used' } )->count;
    if ( $used_coupon > 4000 ) {
        return $self->render(
            error => '이벤트가 종료되었습니다 - 발급건수 초과' );
    }

    $mbersn = $self->decrypt_mbersn($mbersn);
    unless ($mbersn) {
        return $self->render(
            error => '잘못된 요청입니다 - MberSn 이 유효하지 않습니다' );
    }

    my %status;
    my $given = $rs->search( { desc => "seoul|$mbersn" } );
    while ( my $coupon = $given->next ) {
        my $status = $coupon->status; # provided | used | discarded | expired
        $status{$status}++;
        $status{total}++;
        $status{invalid}++ if $status =~ /(us|discard|expir)ed/;
    }

    ## 이미 2회이상 사용되었음
    if ( $status{invalid} && $status{invalid} >= 2 ) {
        return $self->render( error =>
                '무료대여 대상자가 아닙니다 - 이미 2회 이상 지급 받았습니다'
        );
    }

    ## 아직 사용되지 않은 쿠폰이 있음
    if ( $status{provided} && $status{provided} == 1 ) {
        my $coupon = $rs->search( { desc => "seoul|$mbersn", status => 'provided' } )->next;
        $self->session( coupon_code => $coupon->code );
        return;
    }

    my $coupon = $self->_issue_coupon($mbersn);
    return $self->error( 500, "Failed to create a new coupon" ) unless $coupon;

    $self->session( coupon_code => $coupon->code );
    $self->render;
}

sub _issue_coupon {
    my ( $self, $mbersn ) = @_;

    my $code = cc_generate( parts => 3 );
    my $coupon = $self->DB->resultset('Coupon')->create(
        {
            code   => $code,
            type   => 'suit',
            desc   => "seoul|$mbersn",
            status => 'provided'
        }
    );

    return $coupon;
}

1;
