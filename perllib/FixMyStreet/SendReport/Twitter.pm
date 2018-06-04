package FixMyStreet::SendReport::Twitter;

use Moose;
use Data::Dumper;

BEGIN { extends 'FixMyStreet::SendReport'; }

sub build_recipient_list {
    my ( $self, $row, $h ) = @_;
    my %recips;

    my $all_confirmed = 1;
    my $body = $row->bodies_str;
    $body = FixMyStreet::App->model("DB::Body")->find($body);
    my $contact = FixMyStreet::App->model("DB::Contact")->find( {
        deleted => 0,
        body_id => $body->id,
        category => $row->category
    } );
    print "\nTWITTER CoNTACT\n";
    my ($body_twitter, $confirmed, $note) = ( $contact->twitter, $contact->confirmed, $contact->note );
    unless ($confirmed && $body_twitter) {
        $all_confirmed = 0;
        $note = 'Body ' . $row->bodies_str . ' deleted'
            unless $note;
        $body_twitter = 'N/A' unless $body_twitter;
        $self->unconfirmed_counts->{$body_twitter}{$row->category}++;
        $self->unconfirmed_notes->{$body_twitter}{$row->category} = $note;
    }
    print $body_twitter;
    $recips{'contact'} = $body_twitter;
    $recips{'others'} = $contact->twitter_others;
    print "\nTWITTER RECIPS\n";
    print Dumper(\%recips);
    return () unless $all_confirmed;
    return \%recips;
}

sub get_template {
    my ( $self, $row ) = @_;

    my $template = 'submit.txt';
    my $template_path = FixMyStreet->path_to( "templates", "twitter", $row->cobrand, $row->lang, $template )->stringify;
    $template_path = FixMyStreet->path_to( "templates", "twitter", $row->cobrand, $template )->stringify
        unless -e $template_path;
    $template_path = FixMyStreet->path_to( "templates", "twitter", "default", $template )->stringify
        unless -e $template_path;
    $template = Utils::read_file( $template_path );
    return $template;
}

sub send {
    my $self = shift;
    my ( $row, $h ) = @_;

    print "ARRANCA Module Test tweet\n";

    my $recips = $self->build_recipient_list( $row, $h );

    my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
      ssl => 1,
      consumer_key    => 'PDILTaWLsTO4zzDm9L4hofljw',
      consumer_secret => '32NNksUER5EbIyLHG8fkJqZE3iDSJkxsiy8Ow8WkqTVB0ddkBM',
      access_token    => '992782501667115008-IkAe8BL0AhHhDQZIL6Kfj4o5mgTolmr',
      access_token_secret => 'ukJ3HvNKmKidUCFd6oG5YwdRAYsR9b231CGQPJUwBZKFb'
    );
    my $result = $nt->update_with_media({
      status => "$recips->{contact} hay un nuevo reporte en PMB en la categoria $h->{category}: ".$row->title.". Sigue este repote: $h->{problem_url}. $recips->{others}",
      #attachment_url => 'http://pmbec.development.datauy.org/',
      lat => $h->{latitude},
      long => $h->{longitude},
      display_coordinates => 1,
      media => ['web/photo/c/' . $row->id . '.full.jpeg'],
    });
    print Dumper($result);

    if ( $result->{id} ) {
        $self->success(1);
    } else {
        $self->error( 'Failed to send tweet' );
    }

    return 1;
}

1;
