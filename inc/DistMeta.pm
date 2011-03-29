package inc::DistMeta;
use Moose;

has metadata => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

with 'Dist::Zilla::Role::MetaProvider';

around BUILDARGS => sub {
    my $orig = shift;
    my $self = shift;

    my $params = $self->$orig(@_);

    my $zilla       = delete $params->{zilla};
    my $plugin_name = delete $params->{plugin_name};

    return {
        zilla       => $zilla,
        plugin_name => $plugin_name,
        metadata    => $params,
    };
};

__PACKAGE__->meta->make_immutable;
no Moose;

1;
