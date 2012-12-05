package IO::Epoll::Sugar;
use strict;
use warnings;

our $VERSION = '0.01';

use IO::Epoll;
use POSIX qw();
use Socket qw(SOMAXCONN);
use Errno qw(EINTR);
use Carp;

sub EPFD () {0} # epoll
sub LFD  () {1} # list of file descriptors
sub CFD  () {2} # cnt of file descriptors

sub new {
    my $class = shift;
    my $ex_conn = shift || SOMAXCONN;
    bless [epoll_create($ex_conn), [], 0], $class; 
}

sub add_in       { __act(EPOLL_CTL_ADD, EPOLLIN, @_)  }
sub add_out      { __act(EPOLL_CTL_ADD, EPOLLOUT, @_) }
sub add_inout    { __act(EPOLL_CTL_ADD, EPOLLIN|EPOLLOUT, @_) }
sub del          { __act(EPOLL_CTL_DEL, EPOLLIN, @_)  }
sub mod_to_in    { __act(EPOLL_CTL_MOD, EPOLLIN, @_)  }
sub mod_to_out   { __act(EPOLL_CTL_MOD, EPOLLOUT, @_) }
sub mod_to_inout { __act(EPOLL_CTL_MOD, EPOLLIN|EPOLLOUT, @_) }

sub _fno ($) { ref $_[0] ? fileno $_[0] : $_[0] }

sub exists {
    my ($self, $fd) = @_;
    return $self->[LFD]->[_fno $fd];
}

sub __act {
    my ($op, $eventmask, $self, $fd) = @_;
    my $fno = _fno $fd;
    my $ret = undef;
    my $status = epoll_ctl($self->[EPFD], $op, $fno, $eventmask);    
    if ($status >= 0) {
        if ($op == EPOLL_CTL_MOD) {
            # nothing to do
            1;
        } elsif ($op & EPOLL_CTL_ADD) {
            $self->[CFD]++ unless defined $self->[LFD]->[$fno]; 
            $self->[LFD]->[$fno] = $fd;
            $ret = 1;
        } elsif ($op & EPOLL_CTL_DEL) {
            $self->[CFD]-- if defined $self->[LFD]->[$fno];
            $ret = $self->[LFD]->[$fno]; 
            $self->[LFD]->[$fno] = undef;
        }
    } else {
        carp("epoll_ctl: $!");
    }
    return $ret;
}

sub events {
    my $self = shift;
    my ($ex_cnt, $timeout) = @_ > 1 ? @_ : ($self->[CFD], shift);
    
    my $res = epoll_wait($self->[EPFD], $ex_cnt, $timeout);    
    if ($res) {
        my (@read, @write, @delfno);
        for (@$res) {
            my $fno = fileno $self->[LFD]->[$_->[0]];
            if (defined $fno) {
                push @read,  $self->[LFD]->[$_->[0]] if $_->[1] & EPOLLIN;
                push @write, $self->[LFD]->[$_->[0]] if $_->[1] & EPOLLOUT;
                carp("some - trouble with fno ".$_->[0]." eventmask ".$_->[1]) if $_->[1] &~ (EPOLLIN|EPOLLOUT);
            } else {
                carp("some trouble with fno ".$_->[0]." eventmask ".$_->[1]);
                push @delfno, $self->del($_->[0]);
            }
        }
        return wantarray ? (\@read, \@write, \@delfno) : [\@read, \@write, \@delfno];
    } elsif ($! == EINTR) {
        # Interrupted system call is a normal case
        return wantarray ? ([], [], []) : [[], [], []];
    }
    return $res;
}

sub DESTROY {
    my $self = shift;
    POSIX::close($self->[EPFD]);
}

1;
__END__
