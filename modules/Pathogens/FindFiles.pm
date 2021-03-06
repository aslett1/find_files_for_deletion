=head1 NAME

FindFiles.pm   - Find files by a given regex and write them out to a file

=head1 SYNOPSIS

use Pathogens::FindFiles;
Pathogens::FindFiles->new(
  output_file => 'abc.txt',
  directory => '/abc/efg',
  exclude => 'snapshot',
  regex => '(\.out$)|(\.log\.)'
);

# it will save a file to output_file consisting of username, filename, filesize (bytes)

=cut

package Pathogens::FindFiles;

use Moose;
use File::Find;

has 'output_file'         => ( is => 'rw', isa => 'Str', required   => 1 );
has 'directory'           => ( is => 'rw', isa => 'Str', required   => 1 );
has 'exclude'             => ( is => 'rw', isa => 'Maybe[Str]' );
has 'regex'               => ( is => 'rw', isa => 'Str', required   => 1 );
has '_output_file_handle' => ( is => 'rw' );
has '_uid_to_username'    => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

sub BUILD
{
  my $self = shift;
  open(my $ofh, '+>', $self->output_file) or die "Couldnt open output file: ".$self->output_file." $!";
  $self->_output_file_handle($ofh);
  my $exclude_regex = $self->exclude;
  
  find(
    { 
      wanted => sub {
        _wanted({self => $self});
      },
      preprocess => sub {
        grep { $_ !~ /$exclude_regex/ } @_; 
      }
    },
    $self->directory
  );

  close($self->_output_file_handle);
}

sub _wanted {
  my $self = ${$_[0]}{self};
  return unless(defined $File::Find::name);
  
  my $regex = $self->regex;
  if($File::Find::name =~ m/$regex/)
  {
    my @file_details = $self->_find_file_details($_);
    return if(@file_details == 0);
    print { $self->_output_file_handle } $file_details[0]."\t".$File::Find::name."\t".$file_details[1]."\n";
  }
}

sub _find_username_from_uid
{
  my $self = shift;
  my $uid = shift;
  
  my $username = %{$self->_uid_to_username}->{$uid};
  unless(defined $username)
  {
    $username = (getpwuid($uid))[0];
    %{$self->_uid_to_username}->{$uid} = $username;
  }

  return $username
}

sub _find_file_details
{
  my $self = shift;
  my $filename = shift;
    
  # is file a sym link?
  return if( -l $filename);
  
  my ($uid, $size) = (lstat($filename))[4,7];
  return unless(defined $uid);
  my $username = $self->_find_username_from_uid($uid);
  $username = $uid unless defined $username;
  my @user_details = ($username, $size);
  return @user_details;
}

1;
