package RSP::JSObject::Image;

use strict;
use warnings;
use Imager;
use Image::Math::Constrain;
use MIME::Types;

use base 'RSP::JSObject';
__PACKAGE__->mk_accessors(qw( imager file ));

sub jsclass {
  return 'RSPImage';
}

sub constructor {
  return sub {
    my $class = shift;
    my $file  = shift;
    RSP::JSObject::Image->new( $file );
  }
}

sub new {
  my $class = shift;
  use Data::Dumper; print Dumper( \@_ );
  my $file  = shift;
  if (!$file) {
    die { message => 'no file object' };
  }
  my $img   = Imager->new;
  $img->read( file => $file->fullpath ) or die $img->errstr;
  my $self  = { file => $file, imager => $img };
  bless $self, $class;
}

sub properties {
  return {
	  'width' => {
		      'getter' => sub {
			my $self = shift;
			return $self->imager->getwidth;
		      }
		     },
	  'height' => {
		       'getter' => sub {
			 my $self = shift;
			 return $self->imager->getheight;
		       }
		      }
	 }
}

sub methods {
  return {
	  'flip_horizontal' => sub {
	    my $self = shift;
	    $self->imager( $self->imager->flip( dir => 'h' ) );
	  },
	  'flip_vertical'   => sub {
	    my $self = shift;
	    $self->imager( $self->imager->flip( dir => 'v' ) );
	  },
	  'rotate' => sub {
	    my $self    = shift;
	    my $degrees = shift;
	    if (!defined $degrees) { die "no amount of degrees to rotate" }
	    $self->imager( $self->imager->rotate( degrees => $degrees ) );
	  },
	  'scale'  => sub {
	    my $self = shift;
	    my $opts = shift;
	    my $x    = $opts->{xpixels} // 0;
	    my $y    = $opts->{ypixels} // 0;
	    $self->imager( $self->imager->scale( constrain => Image::Math::Constrain->new( $x, $y ) ) );
	  },
	  'crop'  => sub {
	    my $self = shift;
	    my $opts = shift;
	    $self->imager( $self->imager->crop( %$opts ) || die $self->imager->errstr );
	  }
	 }
}

sub as_string {
  my $self = shift;
  my $args = { @_ };
  my $cnt;

  my $mimetype = MIME::Type->new( type => $args->{type} );
  $self->imager->write(type => $mimetype->subType, data=> \$cnt ) or die $self->imager->errstr;
  return $cnt;
}

1;