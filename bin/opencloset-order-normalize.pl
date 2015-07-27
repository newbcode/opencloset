#!/usr/bin/env perl

use v5.18;
use utf8;
use strict;
use warnings;

use FindBin qw( $Script );

use DateTime::Duration;
use DateTime::Format::Duration;
use DateTime::Format::Human::Duration;
use Text::CSV;

use OpenCloset::Config;
use OpenCloset::Schema;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

die "Usage: $Script <config file> <normalize|trim>\n"
    unless @ARGV == 2;

my ( $config_file, $cmd ) = @ARGV;
die "cannot find $config_file\n"          unless -f $config_file;
die "allowed commands: normalize, trim\n" unless $cmd =~ m/^(normalize|trim)$/;

my $CONF = OpenCloset::Config::load($config_file);
my $DB   = OpenCloset::Schema->connect({
    dsn      => $CONF->{database}{dsn},
    user     => $CONF->{database}{user},
    password => $CONF->{database}{pass},
    %{ $CONF->{database}{opts} },
});

{
    use experimental qw( smartmatch );

    given ($cmd) {
        normalize($DB) when 'normalize';
        trim($DB)      when 'trim';
    }
}

sub normalize {
    my $db = shift;

    my $csv = Text::CSV->new({
        binary => 1,
        eol    => "\n",
    });

    my $order_rs = $db->resultset('Order');
    while ( my $order = $order_rs->next ) {
        next unless $order->purpose;

        my $normalized = normalize_mapper( $order->purpose );
        if ( $order->purpose ne $normalized ) {
            my $purpose2 = join( ' - ', grep { defined && $_ } $order->purpose, $order->purpose2 );
            $purpose2 = _trim_spaces($purpose2);

            $csv->combine(
                $order->id,
                $order->purpose || q{N/A},
                $normalized,
                $order->purpose2 || q{N/A},
                $purpose2,
            );

            print $csv->string;

            $order->update({
                purpose  => $normalized,
                purpose2 => $purpose2,
            });
        }
    }
}

sub _trim_spaces {
    my $str = shift;

    $str =~ s/^\s+//gms;
    $str =~ s/\s+$//gms;
    $str =~ s/\s/ /gms;
    $str =~ s/\s+/ /gms;

    return $str;
}

sub trim {
    my $db = shift;

    my $order_rs = $db->resultset('Order');
    while ( my $order = $order_rs->next ) {
        next unless $order->purpose2;

        if ( $order->purpose2 =~ /(^\s+|\s+$)/ || $order->purpose2 =~ /\s+/ ) {
            my $trimed_purpose2 = $order->purpose2;
            $trimed_purpose2 =~ s/(^\s+|\s+$)//;
            $trimed_purpose2 =~ s/\s+/ /;
            if ( $order->purpose2 ne $trimed_purpose2 ) {
                printf(
                    "(%7d) : [%s] => [%s]\n",
                    $order->id,
                    $order->purpose2,
                    $trimed_purpose2,
                );

                $order->update( { purpose2 => $trimed_purpose2 } );
            }
        }
    }
}

sub normalize_mapper {
    my $purpose = shift;

    my %map = (
        '입사면접'                 => '입사면접',
        '입사면접 '                => '입사면접',
        '입사면접  '               => '입사면접',
        '입사면접   '              => '입사면접',
        '결혼식 '                   => '결혼식',
        '결혼식  '                  => '결혼식',
        '결혼식'                    => '결혼식',
        '졸업식'                    => '졸업식',
        '인턴면접'                 => '인턴면접',
        '기타'                       => '기타',
        '장례식'                    => '장례식',
        '장례식 '                   => '장례식',
        '장례식  '                  => '장례식',
        '발표'                       => '발표',
        '발표  '                     => '발표',
        '축제(행사)'               => '축제(행사)',
        '사진촬영(웨딩촬영)'   => '사진촬영(웨딩촬영)',
        '모의면접'                 => '모의면접',
        '공연(연주회)'            => '공연(연주회)',
        '세미나'                    => '세미나',
        '대학(원)면접'            => '대학(원)면접',
        '상견례'                    => '상견례',
        '면접'                       => '입사면접',
        '면접 '                      => '입사면접',
        '면접  '                     => '입사면접',
        '면접   '                    => '입사면접',
        '아르바이트'              => '아르바이트',
        '사진촬영'                 => '사진촬영',
        '면접  입사면접'         => '입사면접',
        'OT'                           => 'OT',
        '입학식'                    => '입학식',
        '대학면접'                 => '대학(원)면접',
        ' 입사면접'                => '입사면접',
        '입사면접  입사면접'   => '입사면접',
        '정장대여'                 => '입사면접',
        '입사면접  사진촬영'   => '입사면접',
        '학교면접'                 => '대학(원)면접',
        '대학원면접'              => '대학(원)면접',
        '공연'                       => '공연(연주회)',
        '행사'                       => '축제(행사)',
        '연주회'                    => '공연(연주회)',
        '연주회 '                   => '공연(연주회)',
        '연주회  '                  => '공연(연주회)',
        '대학 면접'                => '대학(원)면접',
        '편입면접'                 => '대학(원)면접',
        '합창'                       => '공연(연주회)',
        '졸업식  졸업식'         => '졸업식',
        '합창공연'                 => '공연(연주회)',
        ' 결혼식'                   => '결혼식',
        '축제'                       => '축제(행사)',
        ' 졸업식'                   => '졸업식',
        '졸업식 '                   => '졸업식',
        '졸업식  '                  => '졸업식',
        '졸업식   '                 => '졸업식',
        '시상식'                    => '축제(행사)',
        '약대면접'                 => '대학(원)면접',
        '음악회'                    => '공연(연주회)',
        '호알바'                    => '아르바이트',
        '발표  입사면접'         => '입사면접',
        '결혼식  결혼식'         => '결혼식',
        '임용식'                    => '축제(행사)',
        '경호'                       => '아르바이트',
        '입사면접  결혼식'      => '입사면접',
        '기업면접'                 => '입사면접',
        '학교 면접'                => '대학(원)면접',
        '취업캠프'                 => '발표',
        '편입 면접'                => '대학(원)면접',
        '  사진촬영'               => '사진촬영',
        '사진촬영 '                => '사진촬영',
        '입사면접준비'           => '입사면접',
        '인사목적'                 => '축제(행사)',
        '돌잔치'                    => '축제(행사)',
        '행사 안내'                => '축제(행사)',
        '모의유엔참여'           => '축제(행사)',
        '면접용'                    => '축제(행사)',
        '방송제'                    => '축제(행사)',
        '입시면접'                 => '입사면접',
        '연주'                       => '공연(연주회)',
        '학교 행사'                => '축제(행사)',
        '대학교 면접'             => '대학(원)면접',
        '영상촬영'                 => '축제(행사)',
        '선서식  졸업식  '       => '졸업식',
        '취업모의면접/발표'    => '모의면접',
        '졸업포스터 발표'       => '발표',
        '교회합창'                 => '공연(연주회)',
        '청원경찰 아르바이트' => '아르바이트',
        '군장교 면접'             => '입사면접',
        '공연  발표'               => '공연(연주회)',
        '회사 행사'                => '축제(행사)',
        '약학대학 면접'          => '대학(원)면접',
        '부사관 면접'             => '입사면접',
        '시상식 발표'             => '축제(행사)',
        '병원면접&졸업식'       => '입사면접',
        '프르젠테이션'           => '발표',
        '졸업식  사진촬영'      => '졸업식',
        '축제 사회'                => '축제(행사)',
        '군면접'                    => '입사면접',
        '입사면접ㅠ 아침11시 반이예요 최대한빨리빌릴수있을까요'
            => '입사면접',
        '진급시험'                                => '입사면접',
        '수상식참가'                             => '축제(행사)',
        '연주회 복장'                            => '공연(연주회)',
        '실습면접'                                => '입사면접',
        '오리엔테이션'                          => 'OT',
        '학교축제'                                => '축제(행사)',
        '입사모의면접'                          => '입사면접',
        '바리스타 시험'                         => '입사면접',
        '대학 편입면접'                         => '입사면접',
        '취업 면접용'                            => '입사면접',
        '면접준비'                                => '입사면접',
        '장학금 면접'                            => '대학(원)면접',
        '수습 복장'                               => '입사면접',
        '학술제'                                   => '축제(행사)',
        '수여식'                                   => '축제(행사)',
        '행사 사회자'                            => '축제(행사)',
        '방송촬영'                                => '축제(행사)',
        '임용고시 수업실연, 면접'           => '입사면접',
        '대외활동'                                => '축제(행사)',
        '장학생 지원 면접'                     => '대학(원)면접',
        '첫 인턴 출근'                           => '입사면접',
        '회사직원교육'                          => '축제(행사)',
        '상견례, 졸업식'                        => '상견례',
        '프래젠테이션 대비 의상'            => '발표',
        '결혼식ㅇ'                                => '결혼식',
        '자격증 시험'                            => '입사면접',
        '여행사 면접 '                           => '입사면접',
        '누나 상견례 '                           => '상견례',
        '회사오티'                                => 'OT',
        '결혼식 사회'                            => '결혼식',
        '대한항공 스튜어드 면접'            => '입사면접',
        '한국수출입은행 면접용'             => '입사면접',
        '입사 면접'                               => '입사면접',
        '웨딩촬영'                                => '사진촬영',
        '이력서 사진 촬영(공공기관)'       => '사진촬영',
        ' 발표'                                     => '발표',
        '연극'                                      => '축제(행사)',
        '대학편입면접'                          => '대학(원)면접',
        '유학면접'                                => '대학(원)면접',
        '교육 프로그램 면접'                  => '대학(원)면접',
        '대학교 취업프로그램 모의면접'   => '대학(원)면접',
        '졸업상영회입니다'                    => '축제(행사)',
        '카메라테스트  사진촬영'            => '축제(행사)',
        '신규간호사OT'                           => '입사면접',
        '입사면접  세미나'                     => '입사면접',
        '상견레'                                   => '상견례',
        '모의유엔  발표'                        => '발표',
        '대외활동 면접'                         => '입사면접',
        '취업교육용'                             => '입사면접',
        '입사면접(공공기관/복지관 면접)' => '입사면접',
        '교육'                                      => '입사면접',
        '대입면접'                                => '대학(원)면접',
        '부모님 환갑잔치'                      => '축제(행사)',
        '입사 OT'                                   => 'OT',
        '부사관면접'                             => '입사면접',
        '발표  입사면접  입사면접'          => '입사면접',
        '대학원 시무식'                         => '축제(행사)',
        '대기업 입사면접'                      => '입사면접',
        '보조출연 의상'                         => '입사면접',
        '입시 면접'                               => '입사면접',
        '약대면접-대여희망기간(1월3일~1월9일)' =>
            '대학(원)면접',
        '접대'                           => '축제(행사)',
        '플랜트교육 발표용 정장' => '축제(행사)',
        '약학대학교입학면접'      => '대학(원)면접',
        '면접   결혼식'               => '입사면접',
        '결혼식에 입을 정장이 필요해요ㅠㅠ' => '결혼식',
        '사진촬영  입학식'                          => '사진촬영',
        '사진촬영  발표'                             => '사진촬영',
        '친형상견례'                                  => '상견례',
        '송년회'                                        => '축제(행사)',
        '개업식'                                        => '축제(행사)',
        '기관 면접  입사면접'                      => '입사면접',
        '전체가족모임'                               => '축제(행사)',
        '신입 인턴 교육'                             => '입사면접',
        '세례식'                                        => '축제(행사)',
        '학회 참석  세미나'                         => '세미나',
        '촬영 '                                          => '사진촬영',
        '기자회견'                                     => '축제(행사)',
        '교우회참석'                                  => '축제(행사)',
        '레스모아  입사면접'                       => '입사면접',
        '취업 이후 - 졸업식 - 은사님 만남'     => '입사면접',
        '대학원 입학 면접'              => '대학(원)면접',
        '가져온 치마에 맞춰주세요~' => '축제(행사)',
        '피티'                               => 'OT',
        '수업실연 및 면접'              => '발표',
        '출근용'                            => '입사면접',
        '교내 취업캠프 모의면접'     => '모의면접',
        '대회'                               => '발표',
        '기타 면접'                        => '입사면접',
        '인턴 오리엔테이션 참석'     => 'OT',
        '대학시험'                         => '대학(원)면접',
        '공연의상'                         => '축제(행사)',
        '  졸업식'                          => '졸업식',
        '무대의상'                         => '축제(행사)',
        '입사오티'                         => 'OT',
        '장교 면접'                        => '입사면접',
        '촬영  사진촬영'                 => '사진촬영',
        '취업준비  입사면접'           => '입사면접',
        '학교행사'                         => '축제(행사)',
        ' 사진촬영'                        => '사진촬영',
        '세미나  발표'                    => '세미나',
        '가족모임'                         => '축제(행사)',
        '인턴교육'                         => '입사면접',
        '사진촬영  입사면접'           => '입사면접',
        '  입사면접'                       => '입사면접',
        '행사 참석'                        => '축제(행사)',
        '추모식'                            => '축제(행사)',
        '칠순잔치'                         => '축제(행사)',
        '일일 아르바이트'               => '아르바이트',
        '발표  세미나'                    => '세미나',
        '피로연 파티'                     => '축제(행사)',
        '백화점 근무'                     => '아르바이트',
        '입사면접  발표'                 => '입사면접',
        '모의 취업 면접'                 => '모의면접',
        '합창무대'                         => '공연(연주회)',
        '결혼식  입사면접'              => '결혼식',
        '대학원 면접'                     => '대학(원)면접',
        '면접  입사면접  사진촬영'   => '입사면접',
        '편입'                               => '대학(원)면접',
        '성당'                               => '축제(행사)',
        '임원교육'                         => '발표',
        '입사면접'                         => '입사면접',
        '결혼식'                            => '결혼식',
        '졸업식'                            => '졸업식',
        '인턴면접'                         => '인턴면접',
        '기타'                               => '기타',
        '장례식'                            => '장례식',
        '발표'                               => '발표',
        '축제(행사)'                       => '축제(행사)',
        '사진촬영(웨딩촬영)'           => '사진촬영(웨딩촬영)',
        '모의면접'                         => '모의면접',
        '공연(연주회)'                    => '공연(연주회)',
        '세미나'                            => '세미나',
        '대학(원)면접'                    => '대학(원)면접',
        '상견례'                            => '상견례',
        '면접'                               => '입사면접',
        '아르바이트'                      => '아르바이트',
        '사진촬영'                         => '사진촬영',
        '면접  입사면접'                 => '입사면접',
        'OT'                                   => 'OT',
        '입학식'                            => '입학식',
        '대학면접'                         => '대학(원)면접',
        ' 입사면접'                        => '입사면접',
        '입사면접  입사면접'           => '입사면접',
        '정장대여'                         => '입사면접',
        '입사면접  사진촬영'           => '입사면접',
        '학교면접'                         => '대학(원)면접',
        '대학원면접'                      => '대학(원)면접',
        '공연'                               => '공연(연주회)',
        '행사'                               => '축제(행사)',
        '연주회'                            => '공연(연주회)',
        '대학 면접'                        => '대학(원)면접',
        '편입면접'                         => '대학(원)면접',
        '합창'                               => '공연(연주회)',
        '졸업식  졸업식'                 => '졸업식',
        '합창공연'                         => '공연(연주회)',
        ' 결혼식'                           => '결혼식',
        '축제'                               => '축제(행사)',
        ' 졸업식'                           => '졸업식',
        '시상식'                            => '축제(행사)',
        '약대면접'                         => '대학(원)면접',
        '음악회'                            => '공연(연주회)',
        '경호알바'                         => '아르바이트',
        '발표  입사면접'                 => '입사면접',
        '결혼식  결혼식'                 => '결혼식',
        '임용식'                            => '축제(행사)',
        '경호'                               => '아르바이트',
        '입사면접  결혼식'              => '입사면접',
        '기업면접'                         => '입사면접',
        '학교 면접'                        => '대학(원)면접',
        '취업캠프'                         => '발표',
        '편입 면접'                        => '대학(원)면접',
        '  사진촬영'                       => '사진촬영',
        '입사면접준비'                   => '입사면접',
        '인사목적'                         => '축제(행사)',
        '돌잔치'                            => '축제(행사)',
        '행사 안내'                        => '축제(행사)',
        '모의유엔참여'                   => '축제(행사)',
        '면접용'                            => '축제(행사)',
        '방송제'                            => '축제(행사)',
        '입시면접'                         => '입사면접',
        ''                                     => '입사면접',
        '연주'                               => '공연(연주회)',
        '학교 행사'                        => '축제(행사)',
        '대학교 면접'                     => '대학(원)면접',
        '영상촬영'                         => '축제(행사)',
        '선서식  졸업식  '               => '졸업식',
        '취업모의면접/발표'            => '모의면접',
        '졸업포스터 발표'               => '발표',
        '교회합창'                         => '공연(연주회)',
        '청원경찰 아르바이트'         => '아르바이트',
        '군장교 면접'                     => '입사면접',
        '공연  발표'                       => '공연(연주회)',
        '회사 행사'                        => '축제(행사)',
        '약학대학 면접'                  => '대학(원)면접',
        '부사관 면접'                     => '입사면접',
        '시상식 발표'                     => '축제(행사)',
        '병원면접&졸업식'               => '입사면접',
        '프르젠테이션'                   => '발표',
        '졸업식  사진촬영'              => '졸업식',
        '축제 사회'                        => '축제(행사)',
        '군면접'                            => '입사면접',
        '입사면접ㅠ 아침11시 반이예요 최대한빨리빌릴수있을까요'
            => '입사면접',
        '진급시험'                                => '입사면접',
        '수상식참가'                             => '축제(행사)',
        '연주회 복장'                            => '공연(연주회)',
        '실습면접'                                => '입사면접',
        '오리엔테이션'                          => 'OT',
        '학교축제'                                => '축제(행사)',
        '입사모의면접'                          => '입사면접',
        '바리스타 시험'                         => '입사면접',
        '대학 편입면접'                         => '입사면접',
        '취업 면접용'                            => '입사면접',
        '면접준비'                                => '입사면접',
        '장학금 면접'                            => '대학(원)면접',
        '수습 복장'                               => '입사면접',
        '학술제'                                   => '축제(행사)',
        '수여식'                                   => '축제(행사)',
        '행사 사회자'                            => '축제(행사)',
        '방송촬영'                                => '축제(행사)',
        '임용고시 수업실연, 면접'           => '입사면접',
        '대외활동'                                => '축제(행사)',
        '장학생 지원 면접'                     => '대학(원)면접',
        '첫 인턴 출근'                           => '입사면접',
        '회사직원교육'                          => '축제(행사)',
        '상견례, 졸업식'                        => '상견례',
        '프래젠테이션 대비 의상'            => '발표',
        '결혼식ㅇ'                                => '결혼식',
        '자격증 시험'                            => '입사면접',
        '여행사 면접 '                           => '입사면접',
        '누나 상견례 '                           => '상견례',
        '회사오티'                                => 'OT',
        '결혼식 사회'                            => '결혼식',
        '대한항공 스튜어드 면접'            => '입사면접',
        '한국수출입은행 면접용'             => '입사면접',
        '입사 면접'                               => '입사면접',
        '웨딩촬영'                                => '사진촬영',
        '이력서 사진 촬영(공공기관)'       => '사진촬영',
        ' 발표'                                     => '발표',
        '연극'                                      => '축제(행사)',
        '대학편입면접'                          => '대학(원)면접',
        '유학면접'                                => '대학(원)면접',
        '교육 프로그램 면접'                  => '대학(원)면접',
        '대학교 취업프로그램 모의면접'   => '대학(원)면접',
        '졸업상영회입니다'                    => '축제(행사)',
        '카메라테스트  사진촬영'            => '축제(행사)',
        '신규간호사OT'                           => '입사면접',
        '입사면접  세미나'                     => '입사면접',
        '상견레'                                   => '상견례',
        '모의유엔  발표'                        => '발표',
        '대외활동 면접'                         => '입사면접',
        '취업교육용'                             => '입사면접',
        '입사면접(공공기관/복지관 면접)' => '입사면접',
        '교육'                                      => '입사면접',
        '대입면접'                                => '대학(원)면접',
        '부모님 환갑잔치'                      => '축제(행사)',
        '입사 OT'                                   => 'OT',
        '부사관면접'                             => '입사면접',
        '발표  입사면접  입사면접'          => '입사면접',
        '대학원 시무식'                         => '축제(행사)',
        '대기업 입사면접'                      => '입사면접',
        '보조출연 의상'                         => '입사면접',
        '입시 면접'                               => '입사면접',
        '약대면접-대여희망기간(1월3일~1월9일)' =>
            '대학(원)면접',
        '접대'                           => '축제(행사)',
        '플랜트교육 발표용 정장' => '축제(행사)',
        '약학대학교입학면접'      => '대학(원)면접',
        '면접   결혼식'               => '입사면접',
        '결혼식에 입을 정장이 필요해요ㅠㅠ' => '결혼식',
        '사진촬영  입학식'                          => '사진촬영',
        '사진촬영  발표'                             => '사진촬영',
        '친형상견례'                                  => '상견례',
        '송년회'                                        => '축제(행사)',
        '개업식'                                        => '축제(행사)',
        '기관 면접  입사면접'                      => '입사면접',
        '전체가족모임'                               => '축제(행사)',
        '신입 인턴 교육'                             => '입사면접',
        '세례식'                                        => '축제(행사)',
        '학회 참석  세미나'                         => '세미나',
        '촬영 '                                          => '사진촬영',
        '기자회견'                                     => '축제(행사)',
        '교우회참석'                                  => '축제(행사)',
        '레스모아  입사면접'                       => '입사면접',
        '취업 이후 - 졸업식 - 은사님 만남'     => '입사면접',
        '대학원 입학 면접'              => '대학(원)면접',
        '가져온 치마에 맞춰주세요~' => '축제(행사)',
        '피티'                               => 'OT',
        '수업실연 및 면접'              => '발표',
        '출근용'                            => '입사면접',
        '교내 취업캠프 모의면접'     => '모의면접',
        '대회'                               => '발표',
        '기타 면접'                        => '입사면접',
        '인턴 오리엔테이션 참석'     => 'OT',
        '대학시험'                         => '대학(원)면접',
        '공연의상'                         => '축제(행사)',
        '  졸업식'                          => '졸업식',
        '무대의상'                         => '축제(행사)',
        '입사오티'                         => 'OT',
        '장교 면접'                        => '입사면접',
        '촬영  사진촬영'                 => '사진촬영',
        '취업준비  입사면접'           => '입사면접',
        '학교행사'                         => '축제(행사)',
        ' 사진촬영'                        => '사진촬영',
        '세미나  발표'                    => '세미나',
        '가족모임'                         => '축제(행사)',
        '인턴교육'                         => '입사면접',
        '사진촬영  입사면접'           => '입사면접',
        '  입사면접'                       => '입사면접',
        '행사 참석'                        => '축제(행사)',
        '추모식'                            => '축제(행사)',
        '칠순잔치'                         => '축제(행사)',
        '일일 아르바이트'               => '아르바이트',
        '발표  세미나'                    => '세미나',
        '피로연 파티'                     => '축제(행사)',
        '백화점 근무'                     => '아르바이트',
        '입사면접  발표'                 => '입사면접',
        '모의 취업 면접'                 => '모의면접',
        '합창무대'                         => '공연(연주회)',
        '결혼식  입사면접'              => '결혼식',
        '대학원 면접'                     => '대학(원)면접',
        '면접  입사면접  사진촬영'   => '입사면접',
        '편입'                               => '대학(원)면접',
        '성당'                               => '축제(행사)',
        '임원교육'                         => '발표',
        '입사면접'                         => '입사면접',
        '결혼식'                            => '결혼식',
        '졸업식'                            => '졸업식',
        '인턴면접'                         => '인턴면접',
        '기타'                               => '기타',
        '장례식'                            => '장례식',
        '발표'                               => '발표',
        '축제(행사)'                       => '축제(행사)',
        '사진촬영(웨딩촬영)'           => '사진촬영(웨딩촬영)',
        '모의면접'                         => '모의면접',
        '공연(연주회)'                    => '공연(연주회)',
        '세미나'                            => '세미나',
        '대학(원)면접'                    => '대학(원)면접',
        '상견례'                            => '상견례',
        '면접'                               => '입사면접',
        '아르바이트'                      => '아르바이트',
        '사진촬영'                         => '사진촬영',
        '면접  입사면접'                 => '입사면접',
        'OT'                                   => 'OT',
        '입학식'                            => '입학식',
        '대학면접'                         => '대학(원)면접',
        ' 입사면접'                        => '입사면접',
        '입사면접  입사면접'           => '입사면접',
        '정장대여'                         => '입사면접',
        '입사면접  사진촬영'           => '입사면접',
        '학교면접'                         => '대학(원)면접',
        '대학원면접'                      => '대학(원)면접',
        '공연'                               => '공연(연주회)',
        '행사'                               => '축제(행사)',
        '연주회'                            => '공연(연주회)',
        '대학 면접'                        => '대학(원)면접',
        '편입면접'                         => '대학(원)면접',
        '합창'                               => '공연(연주회)',
        '졸업식  졸업식'                 => '졸업식',
        '합창공연'                         => '공연(연주회)',
        ' 결혼식'                           => '결혼식',
        '축제'                               => '축제(행사)',
        ' 졸업식'                           => '졸업식',
        '시상식'                            => '축제(행사)',
        '약대면접'                         => '대학(원)면접',
        '음악회'                            => '공연(연주회)',
        '경호알바'                         => '아르바이트',
        '발표  입사면접'                 => '입사면접',
        '결혼식  결혼식'                 => '결혼식',
        '임용식'                            => '축제(행사)',
        '경호'                               => '아르바이트',
        '입사면접  결혼식'              => '입사면접',
        '기업면접'                         => '입사면접',
        '학교 면접'                        => '대학(원)면접',
        '취업캠프'                         => '발표',
        '편입 면접'                        => '대학(원)면접',
        '  사진촬영'                       => '사진촬영',
        '입사면접준비'                   => '입사면접',
        '인사목적'                         => '축제(행사)',
        '돌잔치'                            => '축제(행사)',
        '행사 안내'                        => '축제(행사)',
        '모의유엔참여'                   => '축제(행사)',
        '면접용'                            => '축제(행사)',
        '방송제'                            => '축제(행사)',
        '입시면접'                         => '입사면접',
        ''                                     => '입사면접',
        '연주'                               => '공연(연주회)',
        '학교 행사'                        => '축제(행사)',
        '대학교 면접'                     => '대학(원)면접',
        '영상촬영'                         => '축제(행사)',
        '선서식  졸업식  '               => '졸업식',
        '취업모의면접/발표'            => '모의면접',
        '졸업포스터 발표'               => '발표',
        '교회합창'                         => '공연(연주회)',
        '청원경찰 아르바이트'         => '아르바이트',
        '군장교 면접'                     => '입사면접',
        '공연  발표'                       => '공연(연주회)',
        '회사 행사'                        => '축제(행사)',
        '약학대학 면접'                  => '대학(원)면접',
        '부사관 면접'                     => '입사면접',
        '시상식 발표'                     => '축제(행사)',
        '병원면접&졸업식'               => '입사면접',
        '프르젠테이션'                   => '발표',
        '졸업식  사진촬영'              => '졸업식',
        '축제 사회'                        => '축제(행사)',
        '군면접'                            => '입사면접',
        '입사면접ㅠ 아침11시 반이예요 최대한빨리빌릴수있을까요'
            => '입사면접',
        '진급시험'                                => '입사면접',
        '수상식참가'                             => '축제(행사)',
        '연주회 복장'                            => '공연(연주회)',
        '실습면접'                                => '입사면접',
        '오리엔테이션'                          => 'OT',
        '학교축제'                                => '축제(행사)',
        '입사모의면접'                          => '입사면접',
        '바리스타 시험'                         => '입사면접',
        '대학 편입면접'                         => '입사면접',
        '취업 면접용'                            => '입사면접',
        '면접준비'                                => '입사면접',
        '장학금 면접'                            => '대학(원)면접',
        '수습 복장'                               => '입사면접',
        '학술제'                                   => '축제(행사)',
        '수여식'                                   => '축제(행사)',
        '행사 사회자'                            => '축제(행사)',
        '방송촬영'                                => '축제(행사)',
        '임용고시 수업실연, 면접'           => '입사면접',
        '대외활동'                                => '축제(행사)',
        '장학생 지원 면접'                     => '대학(원)면접',
        '첫 인턴 출근'                           => '입사면접',
        '회사직원교육'                          => '축제(행사)',
        '상견례, 졸업식'                        => '상견례',
        '프래젠테이션 대비 의상'            => '발표',
        '결혼식ㅇ'                                => '결혼식',
        '자격증 시험'                            => '입사면접',
        '여행사 면접 '                           => '입사면접',
        '누나 상견례 '                           => '상견례',
        '회사오티'                                => 'OT',
        '결혼식 사회'                            => '결혼식',
        '대한항공 스튜어드 면접'            => '입사면접',
        '한국수출입은행 면접용'             => '입사면접',
        '입사 면접'                               => '입사면접',
        '웨딩촬영'                                => '사진촬영',
        '이력서 사진 촬영(공공기관)'       => '사진촬영',
        ' 발표'                                     => '발표',
        '연극'                                      => '축제(행사)',
        '대학편입면접'                          => '대학(원)면접',
        '유학면접'                                => '대학(원)면접',
        '교육 프로그램 면접'                  => '대학(원)면접',
        '대학교 취업프로그램 모의면접'   => '대학(원)면접',
        '졸업상영회입니다'                    => '축제(행사)',
        '카메라테스트  사진촬영'            => '축제(행사)',
        '신규간호사OT'                           => '입사면접',
        '입사면접  세미나'                     => '입사면접',
        '상견레'                                   => '상견례',
        '모의유엔  발표'                        => '발표',
        '대외활동 면접'                         => '입사면접',
        '취업교육용'                             => '입사면접',
        '입사면접(공공기관/복지관 면접)' => '입사면접',
        '교육'                                      => '입사면접',
        '대입면접'                                => '대학(원)면접',
        '부모님 환갑잔치'                      => '축제(행사)',
        '입사 OT'                                   => 'OT',
        '부사관면접'                             => '입사면접',
        '발표  입사면접  입사면접'          => '입사면접',
        '대학원 시무식'                         => '축제(행사)',
        '대기업 입사면접'                      => '입사면접',
        '보조출연 의상'                         => '입사면접',
        '입시 면접'                               => '입사면접',
        '약대면접-대여희망기간(1월3일~1월9일)' =>
            '대학(원)면접',
        '접대'                           => '축제(행사)',
        '플랜트교육 발표용 정장' => '축제(행사)',
        '약학대학교입학면접'      => '대학(원)면접',
        '면접   결혼식'               => '입사면접',
        '결혼식에 입을 정장이 필요해요ㅠㅠ' => '결혼식',
        '사진촬영  입학식'                          => '사진촬영',
        '사진촬영  발표'                             => '사진촬영',
        '친형상견례'                                  => '상견례',
        '송년회'                                        => '축제(행사)',
        '개업식'                                        => '축제(행사)',
        '기관 면접  입사면접'                      => '입사면접',
        '전체가족모임'                               => '축제(행사)',
        '신입 인턴 교육'                             => '입사면접',
        '세례식'                                        => '축제(행사)',
        '학회 참석  세미나'                         => '세미나',
        '촬영 '                                          => '사진촬영',
        '기자회견'                                     => '축제(행사)',
        '교우회참석'                                  => '축제(행사)',
        '레스모아  입사면접'                       => '입사면접',
        '취업 이후 - 졸업식 - 은사님 만남'     => '입사면접',
        '대학원 입학 면접'              => '대학(원)면접',
        '가져온 치마에 맞춰주세요~' => '축제(행사)',
        '피티'                               => 'OT',
        '수업실연 및 면접'              => '발표',
        '출근용'                            => '입사면접',
        '교내 취업캠프 모의면접'     => '모의면접',
        '대회'                               => '발표',
        '기타 면접'                        => '입사면접',
        '인턴 오리엔테이션 참석'     => 'OT',
        '대학시험'                         => '대학(원)면접',
        '공연의상'                         => '축제(행사)',
        '  졸업식'                          => '졸업식',
        '무대의상'                         => '축제(행사)',
        '입사오티'                         => 'OT',
        '장교 면접'                        => '입사면접',
        '촬영  사진촬영'                 => '사진촬영',
        '취업준비  입사면접'           => '입사면접',
        '학교행사'                         => '축제(행사)',
        ' 사진촬영'                        => '사진촬영',
        '세미나  발표'                    => '세미나',
        '가족모임'                         => '축제(행사)',
        '인턴교육'                         => '입사면접',
        '사진촬영  입사면접'           => '입사면접',
        '  입사면접'                       => '입사면접',
        '행사 참석'                        => '축제(행사)',
        '추모식'                            => '축제(행사)',
        '칠순잔치'                         => '축제(행사)',
        '일일 아르바이트'               => '아르바이트',
        '발표  세미나'                    => '세미나',
        '피로연 파티'                     => '축제(행사)',
        '백화점 근무'                     => '아르바이트',
        '입사면접  발표'                 => '입사면접',
        '모의 취업 면접'                 => '모의면접',
        '합창무대'                         => '공연(연주회)',
        '결혼식  입사면접'              => '결혼식',
        '대학원 면접'                     => '대학(원)면접',
        '면접  입사면접  사진촬영'   => '입사면접',
        '편입'                               => '대학(원)면접',
        '성당'                               => '축제(행사)',
        '임원교육'                         => '발표'
    );

    die "[$purpose]" unless exists $map{$purpose};
    return $map{$purpose};
}
