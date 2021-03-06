package RSP::Extension::UUID;

use Moose;
use namespace::autoclean;
with qw(RSP::Role::Extension RSP::Role::Extension::JSInstanceManipulation);

use Data::UUID::Base64URLSafe;

sub bind {
    my ($self) = @_;

    $self->bind_extension({
        uuid => $self->generate_js_closure('uuid'),
    });
}

my $ug = Data::UUID::Base64URLSafe->new;
sub uuid {
    return $ug->create_b64_urlsafe;
}

__PACKAGE__->meta->make_immutable;
1;
