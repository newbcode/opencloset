package OpenCloset::Web::Controller::Statistic;
use Mojo::Base 'Mojolicious::Controller';

use DateTime::TimeZone;
use DateTime;
use Try::Tiny;
use List::Util qw/sum/;
use DateTime::Format::MySQL;

has DB    => sub { shift->app->DB };
has CACHE => sub { shift->app->CACHE };

=head1 METHODS

=head2 bestfit

    GET /stat/bestfit

=cut

sub bestfit {
    my $self = shift;

    my $rs = $self->DB->resultset('Order')->search(
        { bestfit => 1 },
        {
            order_by => [ { -asc => 'order_details.clothes_code' }, ],
            prefetch => { 'order_details' => { 'clothes' => { 'donation' => 'user', }, }, },
        },
    );

    $self->stash( order_rs => $rs, );
}

=head2 clothes_amount

    GET /stat/clothes/amount

=cut

sub clothes_amount {
    my $self = shift;

    my $rs = $self->DB->resultset('Clothes')
        ->search( undef, { columns => [qw/ category /], group_by => 'category' } );

    my @available_status_ids = (
        1, # 대여가능
        2, # 대여중
        3, # 대여불가
        5, # 세탁
        6, # 수선
        9, # 반납
    );

    my @amount;
    while ( my $clothes = $rs->next ) {
        my $category = $clothes->category;

        my $m_quantity =
            $self->DB->resultset('Clothes')
            ->search(
            { category => $category, gender => 'male', status_id => \@available_status_ids, }, );
        my $f_quantity = $self->DB->resultset('Clothes')->search(
            { category => $category, gender => 'female', status_id => \@available_status_ids, },
        );

        my $m_rental = $self->DB->resultset('Clothes')->search(
            {
                category  => $category,
                gender    => 'male',
                status_id => 2,        # 대여중
            }
        );
        my $f_rental = $self->DB->resultset('Clothes')->search(
            {
                category  => $category,
                gender    => 'female',
                status_id => 2,        # 대여중
            }
        );

        push(
            @amount,
            {
                category => $category,
                quantity => $m_quantity + $f_quantity,
                rental   => $m_rental + $f_rental,
                male     => { quantity => $m_quantity, rental => $m_rental, },
                female   => { quantity => $f_quantity, rental => $f_rental, },
            }
        );
    }

    $self->stash( amount => \@amount );
}

=head2 clothes_amount_category_gender

    GET /stat/clothes/amount/category/:category/gender/:gender

=cut

sub clothes_amount_category_gender {
    my $self = shift;

    my %criterion_of = (
        belt      => 'length',
        blouse    => 'bust',
        coat      => 'topbelly',
        jacket    => 'topbelly',
        onepiece  => 'topbelly',
        pants     => 'waist',
        shirt     => 'bust',
        shoes     => 'length',
        skirt     => 'hip',
        tie       => 'color',
        waistcoat => 'bust',
    );

    my @available_status_ids = (
        1, # 대여가능
        2, # 대여중
        3, # 대여불가
        5, # 세탁
        6, # 수선
        9, # 반납
    );

    my $category = $self->param('category');
    my $gender   = $self->param('gender');
    my $quantity = $self->DB->resultset('Clothes')
        ->search( { category => $category, gender => $gender, } );
    my $available_quantity =
        $self->DB->resultset('Clothes')
        ->search(
        { category => $category, gender => $gender, status_id => \@available_status_ids, } );

    my @items;
    my $criterion = $criterion_of{$category};
    if ($criterion) {
        my $rs = $self->DB->resultset('Clothes')
            ->search( undef, { columns => [$criterion], group_by => $criterion }, );

        while ( my $clothes = $rs->next ) {
            my $size = $clothes->$criterion;

            my $qty = $self->DB->resultset('Clothes')
                ->search( { category => $category, gender => $gender, $criterion => $size } );
            my $available_qty = $self->DB->resultset('Clothes')->search(
                {
                    category  => $category, gender => $gender, $criterion => $size,
                    status_id => \@available_status_ids
                }
            );
            my $rental =
                $self->DB->resultset('Clothes')
                ->search(
                { category => $category, gender => $gender, $criterion => $size, status_id => 2 } );
            my $cant_rental =
                $self->DB->resultset('Clothes')
                ->search(
                { category => $category, gender => $gender, $criterion => $size, status_id => 3 } );
            my $repair =
                $self->DB->resultset('Clothes')
                ->search(
                { category => $category, gender => $gender, $criterion => $size, status_id => 6 } );
            my $cleaning =
                $self->DB->resultset('Clothes')
                ->search(
                { category => $category, gender => $gender, $criterion => $size, status_id => 5 } );
            my $lost =
                $self->DB->resultset('Clothes')
                ->search(
                { category => $category, gender => $gender, $criterion => $size, status_id => 7 } );
            my $disused =
                $self->DB->resultset('Clothes')
                ->search(
                { category => $category, gender => $gender, $criterion => $size, status_id => 8 } );

            push(
                @items,
                {
                    size          => $size,
                    qty           => $qty,
                    available_qty => $available_qty,
                    rental        => $rental,
                    cant_rental   => $cant_rental,
                    repair        => $repair,
                    cleaning      => $cleaning,
                    lost          => $lost,
                    disused       => $disused,
                },
            );
        }
    }
    else {
        my $qty = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender } );
        my $available_qty =
            $self->DB->resultset('Clothes')
            ->search(
            { category => $category, gender => $gender, status_id => \@available_status_ids } );
        my $rental = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender, status_id => 2 } );
        my $cant_rental = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender, status_id => 3 } );
        my $repair = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender, status_id => 6 } );
        my $cleaning = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender, status_id => 5 } );
        my $lost = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender, status_id => 7 } );
        my $disused = $self->DB->resultset('Clothes')
            ->search( { category => $category, gender => $gender, status_id => 8 } );

        push(
            @items,
            {
                qty           => $qty,
                available_qty => $available_qty,
                rental        => $rental,
                cant_rental   => $cant_rental,
                repair        => $repair,
                cleaning      => $cleaning,
                lost          => $lost,
                disused       => $disused,
            },
        );
    }

    $self->stash(
        items              => \@items,
        quantity           => $quantity,
        available_quantity => $available_quantity,
        criterion          => $criterion,
        gender             => $gender,
    );
}

=head2 clothes_hit

    GET /stat/clothes/hit

=cut

sub clothes_hit {
    my $self = shift;

    my $default_category = 'jacket';
    my $default_gender   = 'male';
    my $default_limit    = 10;

    my $dt_today = DateTime->now( time_zone => $self->config->{timezone} );
    my $dt_month_before = $dt_today->clone->subtract( months => 1 );
    unless ($dt_month_before) {
        $self->app->log->warn("cannot create end datetime object");
        $self->redirect_to( $self->url_for('/') );
        return;
    }

    $self->redirect_to(
        $self->url_for( '/stat/clothes/hit/' . $default_category )->query(
            start_date => $dt_month_before->ymd,
            end_date   => $dt_today->ymd,
            gender     => $default_gender,
            limit      => $default_limit,
        )
    );
}

=head2 clothes_hit_category

    GET /stat/clothes/hit/:category

=cut

sub clothes_hit_category {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ start_date end_date category gender limit /);

    #
    # validate params
    #

    my $v = $self->create_validator;
    $v->field('category')->in( keys %{ $self->config->{category} } );
    $v->field('gender')->in(qw/ male female /);
    $v->field('limit')->regexp(qr/^\d+$/);

    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    unless ( $params{start_date} ) {
        $self->app->log->warn("start_date is required");
        $self->redirect_to( $self->url_for('/stat/clothes/hit') );
        return;
    }

    unless ( $params{start_date} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $self->app->log->warn("invalid ymd format: $params{start_date}");
        $self->redirect_to( $self->url_for('/start_date') );
        return;
    }

    my $start_date = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };

    unless ($start_date) {
        $self->app->log->warn("cannot create start datetime object");
        $self->redirect_to( $self->url_for('/stat/clothes/hit') );
        return;
    }

    unless ( $params{end_date} ) {
        $self->app->log->warn("end_date is required");
        $self->redirect_to( $self->url_for('/stat/clothes/hit') );
        return;
    }

    unless ( $params{end_date} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $self->app->log->warn("invalid ymd format: $params{end_date}");
        $self->redirect_to( $self->url_for('/stat/clothes/hit') );
        return;
    }

    my $end_date = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };
    unless ($end_date) {
        $self->app->log->warn("cannot create end datetime object");
        $self->redirect_to( $self->url_for('/stat/clothes/hit') );
        return;
    }

    #
    # fetch clothes
    #

    my $dtf        = $self->DB->storage->datetime_parser;
    my $clothes_rs = $self->DB->resultset('Clothes')->search(
        {
            'category'          => $params{category},
            'gender'            => $params{gender},
            'order.rental_date' => {
                -between =>
                    [ $dtf->format_datetime($start_date), $dtf->format_datetime($end_date), ],
            },
        },
        {
            join     => [ { order_details => 'order' }, { donation => 'user' }, ],
            prefetch => [ { donation      => 'user' } ],
            columns  => [
                qw/
                    arm
                    belly
                    bust
                    category
                    code
                    color
                    hip
                    length
                    neck
                    thigh
                    topbelly
                    waist
                    /
            ],
            '+columns' => [ { count => { count => 'me.id', -as => 'rent_count' } } ],
            group_by => [qw/ category code /],
            order_by => { -desc => 'rent_count' },
            rows     => $params{limit},
        }
    );

    $self->render(
        clothes_rs => $clothes_rs,
        start_date => $start_date,
        end_date   => $end_date,
        category   => $params{category},
        gender     => $params{gender},
        limit      => $params{limit},
    );
}

=head2 clothes_rent

    GET /stat/clothes/rent

=cut

sub clothes_rent {
    my $self = shift;

    my $default_category   = 'jacket';
    my $default_gender     = 'male';
    my $default_limit      = 10;
    my $default_sort       = 'asc';
    my @default_status_ids = (        # 가용 가능 의류 상태
        1,                            # 대여가능
        2,                            # 대여중
        3,                            # 대여불가
        4,                            # 예약
        5,                            # 세탁
        6,                            # 수선
        9,                            # 반납
        10,                           # 부분반납
        11,                           # 반납배송중
        16,                           # 치수측정
        17,                           # 의류준비
        18,                           # 포장
        19,                           # 결제대기
    );

    $self->redirect_to(
        $self->url_for( '/stat/clothes/rent/' . $default_category )->query(
            gender         => $default_gender,
            limit          => $default_limit,
            sort           => $default_sort,
            "status_ids[]" => \@default_status_ids,
        )
    );
}

=head2 clothes_rent_category

    GET /stat/clothes/rent/:category

=cut

sub clothes_rent_category {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ category gender limit status_ids[] p sort /);

    #
    # validate params
    #

    my $v = $self->create_validator;
    $v->field('category')->in( keys %{ $self->config->{category} } );
    $v->field('gender')->in(qw/ male female /);
    $v->field('limit')->regexp(qr/^\d+$/);
    $v->field('status_ids[]')->regexp(qr/^\d+$/);
    $v->field('p')->regexp(qr/^\d+$/);
    $v->field('sort')->in(qw/ asc desc /);

    unless ( $self->validate( $v, \%params ) ) {
        my @error_str;
        while ( my ( $k, $v ) = each %{ $v->errors } ) {
            push @error_str, "$k:$v";
        }
        return $self->error( 400, { str => join( ',', @error_str ), data => $v->errors, } );
    }

    #
    # fetch clothes
    #

    my $today = try {
        DateTime->now(
            time_zone => $self->config->{timezone},
        );
    };
    unless ($today) {
        $self->app->log->warn("cannot create datetime object");
        $self->redirect_to( $self->url_for('/stat/clothes/rent') );
        return;
    }
    $today->truncate( to => 'day' );

    my $name = sprintf(
        "stat-clothes-rent-%s-%s-%s-%s",
        $params{gender},
        $params{category},
        $today->ymd,
        DateTime::TimeZone->offset_as_string(
            $today->time_zone->offset_for_datetime($today)
        ),
    );

    my $page  = $params{p}     || 1;
    my $limit = $params{limit} || 10;
    my $sort  = $params{sort}  || "asc";
    my $start_idx = ( $page - 1 ) * $limit;
    my $end_idx   = $start_idx + $limit - 1;

    my $status_ids;
    if ( $params{"status_ids[]"} ) {
        if ( ref $params{"status_ids[]"} eq "ARRAY" ) {
            $status_ids = $params{"status_ids[]"};
        }
        else {
            $status_ids = [ $params{"status_ids[]"} ];
        }
    }
    else {
        $status_ids = [];
    }

    my $cached = $self->CACHE->get($name) || [];
    my @status_filtered_cached;
    for my $item (@$cached) {
        use experimental qw( smartmatch );
        next unless $item->{status_id} ~~ @$status_ids;
        push @status_filtered_cached, $item;
    }

    my @cached_page;
    if ( $sort eq "asc" ) {
        @cached_page = grep { defined } @status_filtered_cached[ $start_idx .. $end_idx ];
    }
    else {
        @cached_page =
            grep { defined } ( reverse @status_filtered_cached )[ $start_idx .. $end_idx ];
    }

    my $clothes_rs = $self->DB->resultset('Clothes')->search(
        {
            'category' => $params{category},
            'gender'   => $params{gender},
        },
        {
            join     => [ { order_details => 'order' }, { donation => 'user' }, ],
            prefetch => [ { donation      => 'user' },  "status" ],
            columns  => [
                qw/
                    arm
                    belly
                    bust
                    category
                    code
                    color
                    hip
                    length
                    neck
                    thigh
                    topbelly
                    waist
                    /
            ],
        },
    );

    my $pageset = Data::Pageset->new(
        {
            total_entries    => scalar(@status_filtered_cached),
            entries_per_page => $limit,
            pages_per_set    => 5,
            current_page     => $page,
        }
    );

    $self->render(
        clothes_rs  => $clothes_rs,
        cached_page => \@cached_page,
        category    => $params{category},
        gender      => $params{gender},
        limit       => $params{limit},
        status_ids  => $params{"status_ids[]"},
        sort        => $params{sort},
        start_idx   => $start_idx,
        end_idx     => $end_idx,
        pageset     => $pageset,
    );
}

=head2 status

    GET /stat/status

=cut

sub status {
    my $self = shift;

    my $dt_today = DateTime->now( time_zone => $self->config->{timezone} );
    $self->redirect_to( $self->url_for( '/stat/status/' . $dt_today->ymd ) );
}

=head2 status_ymd

    GET /stat/status/:ymd

=cut

sub status_ymd {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        $self->app->log->warn("ymd is required");
        $self->redirect_to( $self->url_for('/stat/status') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $self->app->log->warn("invalid ymd format: $params{ymd}");
        $self->redirect_to( $self->url_for('/stat/status') );
        return;
    }

    my $dt = try {
        DateTime->new(
            time_zone => $self->config->{timezone},
            year      => $1,
            month     => $2,
            day       => $3,
        );
    };
    unless ($dt) {
        $self->app->log->warn("cannot create datetime object");
        $self->redirect_to( $self->url_for('/stat/status') );
        return;
    }

    my $today = try {
        DateTime->now( time_zone => $self->config->{timezone} );
    };
    unless ($today) {
        $self->app->log->warn("cannot create datetime object: today");
        $self->redirect_to( $self->url_for('/stat/visitor') );
        return;
    }
    $today->truncate( to => 'day' );

    my $basis_dt = try {
        DateTime->new(
            time_zone => $self->config->{timezone},
            year      => 2015,
            month     => 5,
            day       => 29
        );
    };
    my $online_order_hour = $dt >= $basis_dt ? 22 : 19;

    # -$day_range ~ +$day_range days from now
    my $day_range = 3;
    my %count;
    my $today_data;
    my $from = $dt->clone->truncate( to => 'day' )->add( days => -$day_range );
    my $to   = $dt->clone->truncate( to => 'day' )->add( days => $day_range );
    for ( ; $from <= $to; $from->add( days => 1 ) ) {
        my $f = $from->clone->truncate( to => 'day' );
        my $t = $from->clone->truncate( to => 'day' )->add( days => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "stat-status-day-$f_str-$t_str";

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
        }
        elsif ( $f->clone->truncate( to => 'day' ) == $today ) {
            $self->app->log->info("do not cache and by-pass cache: $name");
            $data = $self->mean_status( $f, $t, $online_order_hour );
            $today_data = $data;
        }
        my $dow = do {
            use experimental qw( smartmatch );
            given ( $f->day_of_week ) {
                "월" when 1;
                "화" when 2;
                "수" when 3;
                "목" when 4;
                "금" when 5;
                "토" when 6;
                "일" when 7;
                default { q{} }
            }
        };
        $data->{label} = $f->ymd . " ($dow)";

        push @{ $count{day} }, $data;
    }

    # from first to current week of this year
    my $current_week_start_dt;
    my $current_week_end_dt;
    for ( my $i = $dt->clone->subtract( years => 1 ); $i <= $dt; $i->add( weeks => 1 ) )
    {
        my $f = $i->clone->truncate( to => 'week' );
        my $t = $i->clone->truncate( to => 'week' )->add( weeks => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "stat-status-week-$f_str-$t_str";

        $current_week_start_dt = $f->clone;
        $current_week_end_dt   = $t->clone;

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
            $data->{label} = sprintf(
                "%04d %02d : %s ~ %s",
                ( $f->week ), # week_year, week_number
                $f->strftime('%m/%d'),
                $t->strftime('%m/%d'),
            );
        }

        push @{ $count{week} }, $data;
    }


    # from january to current months of this year
    my $current_month_start_dt;
    my $current_month_end_dt;
    for (
        my $i = $dt->clone->subtract( years => 1 );
        $i <= $dt;
        $i->add( months => 1 )
        )
    {
        my $f = $i->clone->truncate( to => 'month' );
        my $t = $i->clone->truncate( to => 'month' )->add( months => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "stat-status-month-$f_str-$t_str";

        $current_month_start_dt = $f->clone;
        $current_month_end_dt   = $t->clone;

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
            $data->{label} = $f->strftime('%Y-%m');
        }

        push @{ $count{month} }, $data;
    }

    my $no_cache_week;
    my $no_cache_month;
    ++$no_cache_week  if $today->clone->truncate( to => 'week' ) <= $dt;
    ++$no_cache_month if $today->clone->truncate( to => 'month' ) <= $dt;

    # current data with and without cache
    my %current_week = (
        label => sprintf(
            "%04d %02d : %s ~ %s",
            ( $dt->week ), # week_year, week_number
            $dt->clone->truncate( to => 'week' )->strftime('%m/%d'),
            $dt->clone->truncate( to => 'week' )->add( weeks => 1, seconds => -1 )
                ->strftime('%m/%d'),
        ),
        '대기'     => 0,
        '치수측정' => 0,
        '의류준비' => 0,
        '탈의'     => 0,
        '수선'     => 0,
        '포장'     => 0,
        '결제'     => 0,
    );
    my %current_month = (
        label      => $dt->strftime('%Y-%m'),
        '대기'     => 0,
        '치수측정' => 0,
        '의류준비' => 0,
        '탈의'     => 0,
        '수선'     => 0,
        '포장'     => 0,
        '결제'     => 0,
    );
    for (
        my $i = $today->clone->add( months => -1 )->truncate( to => 'month' );
        $i <= $today;
        $i->add( days => 1 )
        )
    {
        my $f = $i->clone->truncate( to => 'day' );
        my $t = $i->clone->truncate( to => 'day' )->add( days => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "stat-status-day-$f_str-$t_str";

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
        }
        elsif ( $f->clone->truncate( to => 'day' ) == $today ) {
            $self->app->log->info("do not cache and by-pass cache: $name");
            $data = $today_data;
        }

        if ( $current_week_start_dt <= $i && $i <= $current_week_end_dt ) {
            $self->app->log->info("calculationg for this week: $name");
            $current_week{'대기'}       += $data->{'대기'};
            $current_week{'치수측정'}   += $data->{'치수측정'};
            $current_week{'의류준비'}   += $data->{'의류준비'};
            $current_week{'탈의'}       += $data->{'탈의'};
            $current_week{'수선'}       += $data->{'수선'};
            $current_week{'포장'}       += $data->{'포장'};
            $current_week{'결제'}       += $data->{'결제'};
        }
        if ( $current_month_start_dt <= $i && $i <= $current_month_end_dt ) {
            $self->app->log->info("calculationg for this month $name");
            $current_month{'대기'}       += $data->{'대기'};
            $current_month{'치수측정'}   += $data->{'치수측정'};
            $current_month{'의류준비'}   += $data->{'의류준비'};
            $current_month{'탈의'}       += $data->{'탈의'};
            $current_month{'수선'}       += $data->{'수선'};
            $current_month{'포장'}       += $data->{'포장'};
            $current_month{'결제'}       += $data->{'결제'};
        }
    }
    $current_week{total}  = sum( @current_week{qw/대기 치수측정 의류준비 탈의 수선 포장 결제/} );
    $current_month{total} = sum( @current_month{qw/대기 치수측정 의류준비 탈의 수선 포장 결제/} );
    $count{week}[-1]  = \%current_week  if $no_cache_week;
    $count{month}[-1] = \%current_month if $no_cache_month;

    # for daily status detail
    my $dt_start =
        try { $dt->clone->truncate( to => 'day' )->add( hours => 24 * 2 * -1 ); };
    unless ($dt_start) {
        $self->app->log->warn("cannot create start datetime object");
        $self->redirect_to( $self->url_for('/stat/status') );
        return;
    }

    my $dt_end = try {
        $dt->clone->truncate( to => 'day' )->add( hours => 24 * 3, seconds => -1 );
    };
    unless ($dt_end) {
        $self->app->log->warn("cannot create end datetime object");
        $self->redirect_to( $self->url_for('/stat/status') );
        return;
    }

    my $dtf      = $self->DB->storage->datetime_parser;
    my $order_rs = $self->DB->resultset('Order')->search(
        #
        # do not query all data for specific month due to speed
        #
        #\[ 'DATE_FORMAT(`booking`.`date`,"%Y-%m") = ?', $dt->strftime("%Y-%m") ],
        {
            -and => [
                'booking.date' => {
                    -between => [ $dtf->format_datetime($dt_start), $dtf->format_datetime($dt_end), ],
                },
                \[ 'HOUR(`booking`.`date`) != ?', $online_order_hour ],
            ],
        },
        {
            join     => [qw/ booking /],
            order_by => { -asc => 'date' },
            prefetch => 'booking',
        },
    );

    $self->render(
        count    => \%count,
        dt       => $dt,
        order_rs => $order_rs,
    );
}

=head2 visitor

    GET /stat/visitor

=cut

sub visitor {
    my $self = shift;

    my $dt_today = DateTime->now( time_zone => $self->config->{timezone} );
    $self->redirect_to( $self->url_for( '/stat/visitor/' . $dt_today->ymd ) );
}

=head2 visitor_ymd

    GET /stat/visitor/:ymd

=cut

sub visitor_ymd {
    my $self = shift;

    #
    # fetch params
    #
    my %params = $self->get_params(qw/ ymd /);

    unless ( $params{ymd} ) {
        $self->app->log->warn("ymd is required");
        $self->redirect_to( $self->url_for('/stat/visitor') );
        return;
    }

    unless ( $params{ymd} =~ m/^(\d{4})-(\d{2})-(\d{2})$/ ) {
        $self->app->log->warn("invalid ymd format: $params{ymd}");
        $self->redirect_to( $self->url_for('/stat/visitor') );
        return;
    }

    my $dt = try {
        DateTime->new(
            time_zone => $self->config->{timezone}, year => $1, month => $2,
            day       => $3,
        );
    };
    unless ($dt) {
        $self->app->log->warn("cannot create datetime object");
        $self->redirect_to( $self->url_for('/stat/visitor') );
        return;
    }

    my $today = try {
        DateTime->now( time_zone => $self->config->{timezone}, );
    };
    unless ($today) {
        $self->app->log->warn("cannot create datetime object: today");
        $self->redirect_to( $self->url_for('/stat/visitor') );
        return;
    }
    $today->truncate( to => 'day' );

    # -$day_range ~ +$day_range days from now
    my $day_range = 7;
    my %count;
    my $today_data;
    my $from = $dt->clone->truncate( to => 'day' )->add( days => -$day_range );
    my $to   = $dt->clone->truncate( to => 'day' )->add( days => $day_range );
    for ( ; $from <= $to; $from->add( days => 1 ) ) {
        my $f = $from->clone->truncate( to => 'day' );
        my $t = $from->clone->truncate( to => 'day' )->add( days => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "day-$f_str-$t_str";

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
        }
        elsif ( $f->clone->truncate( to => 'day' ) == $today ) {
            $self->app->log->info("do not cache and by-pass cache: $name");
            $data = $self->count_visitor( $f, $t );
            $today_data = $data;
        }
        my $dow = do {
            use experimental qw( smartmatch );
            given ( $f->day_of_week ) {
                "월" when 1;
                "화" when 2;
                "수" when 3;
                "목" when 4;
                "금" when 5;
                "토" when 6;
                "일" when 7;
                default { q{} }
            }
        };
        $data->{label} = $f->ymd . " ($dow)";

        push @{ $count{day} }, $data;
    }

    # from first to current week of this year
    my $current_week_start_dt;
    my $current_week_end_dt;
    for ( my $i = $dt->clone->subtract( years => 1 ); $i <= $dt; $i->add( weeks => 1 ) )
    {
        my $f = $i->clone->truncate( to => 'week' );
        my $t = $i->clone->truncate( to => 'week' )->add( weeks => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "week-$f_str-$t_str";

        $current_week_start_dt = $f->clone;
        $current_week_end_dt   = $t->clone;

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
            $data->{label} = sprintf(
                "%04d %02d : %s ~ %s",
                ( $f->week ), # week_year, week_number
                $f->strftime('%m/%d'),
                $t->strftime('%m/%d'),
            );
        }

        push @{ $count{week} }, $data;
    }

    # from january to current months of this year
    my $current_month_start_dt;
    my $current_month_end_dt;
    for (
        my $i = $dt->clone->subtract( years => 1 );
        $i <= $dt;
        $i->add( months => 1 )
        )
    {
        my $f = $i->clone->truncate( to => 'month' );
        my $t = $i->clone->truncate( to => 'month' )->add( months => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "month-$f_str-$t_str";

        $current_month_start_dt = $f->clone;
        $current_month_end_dt   = $t->clone;

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
            $data->{label} = $f->strftime('%Y-%m');
        }

        push @{ $count{month} }, $data;
    }

    my $no_cache_week;
    my $no_cache_month;
    ++$no_cache_week  if $today->clone->truncate( to => 'week' ) <= $dt;
    ++$no_cache_month if $today->clone->truncate( to => 'month' ) <= $dt;

    # current data with and without cache
    my %current_week = (
        label => sprintf(
            "%04d %02d : %s ~ %s",
            ( $dt->week ), # week_year, week_number
            $dt->clone->truncate( to => 'week' )->strftime('%m/%d'),
            $dt->clone->truncate( to => 'week' )->add( weeks => 1, seconds => -1 )
                ->strftime('%m/%d'),
        ),
        all        => { total => 0, male => 0, female => 0 },
        visited    => { total => 0, male => 0, female => 0 },
        notvisited => { total => 0, male => 0, female => 0 },
        bestfit    => { total => 0, male => 0, female => 0 },
        loanee     => { total => 0, male => 0, female => 0 },
    );
    my %current_month = (
        label      => $dt->strftime('%Y-%m'),
        all        => { total => 0, male => 0, female => 0 },
        visited    => { total => 0, male => 0, female => 0 },
        notvisited => { total => 0, male => 0, female => 0 },
        bestfit => { total => 0, male => 0, female => 0 },
        loanee  => { total => 0, male => 0, female => 0 },
    );
    for (
        my $i = $today->clone->add( months => -1 )->truncate( to => 'month' );
        $i <= $today;
        $i->add( days => 1 )
        )
    {
        my $f = $i->clone->truncate( to => 'day' );
        my $t = $i->clone->truncate( to => 'day' )->add( days => 1, seconds => -1 );

        my $f_str = $f->strftime('%Y%m%d%H%M%S');
        my $t_str = $t->strftime('%Y%m%d%H%M%S');
        my $name  = "day-$f_str-$t_str";

        my $data;
        if ( $f < $today && $t < $today ) {
            $data = $self->CACHE->get($name);
        }
        elsif ( $f->clone->truncate( to => 'day' ) == $today ) {
            $self->app->log->info("do not cache and by-pass cache: $name");
            $data = $today_data;
        }

        if ( $current_week_start_dt <= $i && $i <= $current_week_end_dt ) {
            $self->app->log->info("calculationg for this week: $name");
            $current_week{all}{total}         += $data->{all}{total};
            $current_week{all}{male}          += $data->{all}{male};
            $current_week{all}{female}        += $data->{all}{female};
            $current_week{visited}{total}     += $data->{visited}{total};
            $current_week{visited}{male}      += $data->{visited}{male};
            $current_week{visited}{female}    += $data->{visited}{female};
            $current_week{notvisited}{total}  += $data->{notvisited}{total};
            $current_week{notvisited}{male}   += $data->{notvisited}{male};
            $current_week{notvisited}{female} += $data->{notvisited}{female};
            $current_week{bestfit}{total}     += $data->{bestfit}{total};
            $current_week{bestfit}{male}      += $data->{bestfit}{male};
            $current_week{bestfit}{female}    += $data->{bestfit}{female};
            $current_week{loanee}{total}      += $data->{loanee}{total};
            $current_week{loanee}{male}       += $data->{loanee}{male};
            $current_week{loanee}{female}     += $data->{loanee}{female};
        }
        if ( $current_month_start_dt <= $i && $i <= $current_month_end_dt ) {
            $self->app->log->info("calculationg for this month $name");
            $current_month{all}{total}         += $data->{all}{total};
            $current_month{all}{male}          += $data->{all}{male};
            $current_month{all}{female}        += $data->{all}{female};
            $current_month{visited}{total}     += $data->{visited}{total};
            $current_month{visited}{male}      += $data->{visited}{male};
            $current_month{visited}{female}    += $data->{visited}{female};
            $current_month{notvisited}{total}  += $data->{notvisited}{total};
            $current_month{notvisited}{male}   += $data->{notvisited}{male};
            $current_month{notvisited}{female} += $data->{notvisited}{female};
            $current_month{bestfit}{total}     += $data->{bestfit}{total};
            $current_month{bestfit}{male}      += $data->{bestfit}{male};
            $current_month{bestfit}{female}    += $data->{bestfit}{female};
            $current_month{loanee}{total}      += $data->{loanee}{total};
            $current_month{loanee}{male}       += $data->{loanee}{male};
            $current_month{loanee}{female}     += $data->{loanee}{female};
        }
    }
    $count{week}[-1]  = \%current_week  if $no_cache_week;
    $count{month}[-1] = \%current_month if $no_cache_month;

    $self->render( count => \%count, dt => $dt, );
}

=head2 events_seoul

    GET /stat/events/seoul

=cut

sub events_seoul {
    my $self = shift;
    my $ymd  = $self->param('ymd');

    my $to;
    if ($ymd) {
        my ( $year, $month, $day ) = split /-/, $ymd;
        $to = DateTime->new( year => $year, month => $month, day => $day );
    }
    else {
        $to = DateTime->now;
    }

    my $timezone = $self->config->{timezone} or die "Config timezone is not set";
    $to->set_time_zone($timezone);

    my $storage = $self->DB->storage;

    my $query = $storage->dbh_do(
        sub {
            my ( $storage, $dbh, @args ) = @_;
            $dbh->selectall_hashref(<<END_SQL
                SELECT
                    *
                FROM
                    (
                        SELECT
                            a.`date`                                        AS 'booking_date'
                            ,b.`id`                                         AS 'order_id'
                            ,YEAR(a.`date`)                                 AS 'booking_year'
                            ,MONTH(a.`date`)                                AS 'booking_month'
                            ,DAY(a.`date`)                                  AS 'booking_day'
                            ,IF(b.status_id = 12 OR b.status_id = 14, 0, 1) AS 'is_visit'
                            ,d.gender                                       AS 'gender'
                            ,d.birth                                        AS 'birth'
                            ,YEAR(NOW()) - d.birth                          AS 'age'
                            ,TRUNCATE(YEAR(NOW()) - d.birth, -1)            AS 'age_group'
                            ,IF(b.`coupon_id` IS NOT NULL, 1, 0)            AS 'is_coupon_use'
                            ,e.`id`                                         AS 'coupon_id'
                            ,e.`update_date`                                AS 'coupon_date'
                            ,e.`status`                                     AS 'coupon_status'
                            ,SUBSTRING_INDEX(e.desc, '|', 1)                AS 'coupon_type'
                            ,IFNULL(a.`date` - e.`update_date`,0)           AS 'booking_coupon_issue_diff'
                        FROM
                            `booking` AS a
                            INNER JOIN `order`      AS b ON ( a.id = b.booking_id )
                            INNER JOIN `user`       AS c ON ( b.user_id = c.id )
                            INNER JOIN `user_info`  AS d ON ( c.id = d.user_id )
                            LEFT  JOIN `coupon`     AS e ON ( b.coupon_id = e.id )
                    ) AS x
                WHERE
                    `booking_coupon_issue_diff` >= 0
                    AND `booking_date` > '2016-04-25'
END_SQL
            , 'order_id');
        });

    my %cnt;
    foreach my $key ( keys %$query ) {
        my $r = $query->{$key};
        my $month = sprintf("%d-%02d", $r->{booking_year}, $r->{booking_month});
        my $dt = DateTime::Format::MySQL->parse_datetime($r->{booking_date});

        ## 월별 열린옷장 방문/미방문
        $cnt{'month-visit'}{$month}{$r->{is_visit}}{$r->{is_coupon_use}}++;
        ## 월별 취업날개 예약/방문
        $cnt{'month-coupon'}{$month}{$r->{is_visit}}{$r->{is_coupon_use}}++;
        ## 월별 취업날개 예약/방문 - 성별
        $cnt{'month-coupon-gender'}{$month}{$r->{is_visit}}{$r->{is_coupon_use}}{$r->{gender}}++;
        ## 월별 취업날개 예약/방문 - 나이
        $cnt{'month-coupon-agegroup'}{$month}{$r->{is_visit}}{$r->{is_coupon_use}}{$r->{age_group}}++;

        # 전체 성별
        $cnt{'gender'}{$r->{is_coupon_use}}{$r->{is_visit}}{$r->{gender}}++;
        # 전체 연령
        $cnt{'age_group'}{$r->{is_coupon_use}}{$r->{is_visit}}{$r->{age_group}}++;

        if( $dt <= $to ) {
            my $ymd = $dt->ymd;
            ## 일별 열린옷장 방문/미방문
            $cnt{'daily-visit'}{$ymd}{$r->{is_visit}}++;
            ## 일별 취업날개 방문/미방문
            $cnt{'daily-visit-coupon'}{$ymd}{$r->{is_visit}}{$r->{is_coupon_use}}++;
            $cnt{'daily-visit-coupon-gender'}{$ymd}{$r->{is_visit}}{$r->{is_coupon_use}}{$r->{gender}}++;
            $cnt{'daily-visit-coupon-agegroup'}{$ymd}{$r->{is_visit}}{$r->{is_coupon_use}}{$r->{age_group}}++;
        }
    }
    $self->render( counts => \%cnt );
}

1;
