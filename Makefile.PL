use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'IO::Epoll::Sugar',
    VERSION_FROM      => 'lib/IO/Epoll/Sugar.pm',
    PREREQ_PM         => {
    	# perl-box
    	POSIX => 0,
    	Socket => 0,
    	Errno => 0,
    	Carp => 0,
    	
    	IO::Epoll => 0
    },
    AUTHOR         => 'mr.Rico <catamoose@yandex.ru>',
);
