#!/usr/bin/perl

package PlanetaLinux;

use Modern::Perl;
use PlanetaLinux::Feeds;
use Data::Dumper;
use Carp;
use File::Basename;
use File::Temp;
use Net::Domain::ES::ccTLD '0.03';
use Capture::Tiny ':all';
use File::Remove 'remove';
use Text::Unaccent::PurePerl qw(unac_string);

our @countries = qw(
    android
    ar
    cl
    co
    cr
    ec
    es
    gt
    mx
    ni
    pa
    pe
    sv
    ve
);

sub new {
    my $self = shift;
    my $ref = shift || {};

    $ref->{_t} = Template->new(
            INCLUDE_PATH => dirname(__FILE__).'/../template',
            ENCODING => 'utf8',
    );

    return bless $ref, $self;
}

sub is_country_supported {
    my($self) = shift;
    
    return 1 if $self->country eq 'rssall';
    
    unless ( $self->{_supported_countries} ) {
        $self->{_supported_countries} = { map { $_ => 1 } @countries };
    }
    
    return $self->{_supported_countries}->{$self->country} ? 1 : 0;
}

sub country {
    my($self) = shift;
    $self->{country} = $_[0] if $_[0];
    $self->{country};
}

sub analytics_id {
    my($self) = shift;
    
    open my $fh, "<", dirname(__FILE__).'/../config/analytics.list';
    my $cont = $self->country;
    while(<$fh>) {
        chomp;
        
        next unless $_ =~ /^$cont:/;
        return (split ':', $_)[1]
    }
    close $fh;
    return '';
}

sub country_name {
    my($self) = shift;
    find_name_by_cctld( $self->country ) || ucfirst( $self->country );
}

sub run {
    my($self) = shift;
    my @countries = @_ || @{ $self->{countries} || ['rssall'] };
    
    for my $c ( @countries ) {
        # generate template
        $self->country($c);

        croak "No instance found for $c"
            unless $self->is_country_supported;
        
        my $template = $self->template;
        
        my $ini;
        if ($self->country() eq 'rssall') {
            $ini = $self->feeds({country => $self->country})->ini({tmp_template => $template});
        } else {
            $ini = $self->feeds({country => $self->country})->by_country->ini({tmp_template => $template});
        }
        my $dir = dirname(__FILE__).'/../';
        
        mkdir "$dir/cache/$c";

        remove( \1, "$dir/*.tmplc" );
        
        my $venus = dirname(__FILE__).'/../venus/planet.py';

        my ($stdout, $stderr, $exit) = capture {
            system( $venus, $ini );
        };

        if ( $exit ) {
            print STDERR "!!! Something obviously went wrong !!!\n";
            print STDERR Dumper ( "STDERR:\n", $stderr );
            print STDERR Dumper ( "STDOUT:\n", $stdout );
            exit 1;
        } else {
            # Let's do this because Venus is stoooooopid
            my $index_output = dirname(__FILE__)."/../www/$c/index.html";
            my $index_output_contents;
            {
                open my $fh, "<", $index_output or die "Couldn't read $index_output: $!";
                undef $/;
                $index_output_contents = <$fh>;
                close $fh;
            }
            $index_output_contents = _unstupidize_the_fucking_dates( $index_output_contents );
            {
                open my $fh, ">", $index_output or die "Couldn't do shit on $index_output: $!";
                print $fh $index_output_contents;
                close $fh;
            }
        }
        
    }
}

sub _unstupidize_the_fucking_dates {
    my $text = shift;

    my %date_trans = (qw(
        Monday        Lunes
        Tuesday        Martes
        Wednesday    Miércoles
        Thursday    Jueves
        Friday        Viernes
        Saturday    Sábado
        Sunday        Domingo
        January        enero
        February    febrero
        March        marzo
        April        abril
        May        mayo
        June        junio
        July        julio
        August        agosto
        September    septiembre
        October        octubre
        November    noviembre
        December    diciembre
    ));

    while( my( $eng, $spa ) = each %date_trans ) {
        $text =~ s#<pl>$eng</pl>#$spa#ig;
    }
    return $text;
}

sub countries { @countries }

sub template {
    my $self = shift;
        
    my $countries = [];
    
    for my $c ( $self->countries ) {
        push @$countries, {
            tld => $c,
            name => find_name_by_cctld($c) || $c,
        };
    }
        
    $self->{_t}->process('index.html.tmpl', {
        analytics_id         => $self->analytics_id,
        instance_name         => $self->country_name,
        instance_tld        => $self->country,
        instance_name_pure     => unac_string($self->country_name),
        instance_code         => $self->country,
        last_update            => scalar localtime,
        countries => $countries,
    }, dirname(__FILE__).'/../tmp/'.$self->country.'/index.html.tmpl',
    {binmode => ":utf8"})
        or die "Couldn't process template!".$self->{_t}->error;
    
    return dirname(__FILE__).'/../tmp/'.$self->country.'/index.html.tmpl';

}

sub template_file {
    my($self) = shift;
    $self->{template_file} = $_[0] if $_[0];
    $self->{template_file};
}


sub feeds {
    my($self) = shift;    
    return PlanetaLinux::Feeds->new(shift);
    
}

1;
